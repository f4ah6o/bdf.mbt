//go:build ignore

// Copy without its build tag beside upstream converter/pdf sources, set
// BDF_REFERENCE_OUTPUT, then run TestCodexPDFGraphicsPages.
package pdf

import (
	"bytes"
	"compress/zlib"
	"context"
	"fmt"
	"github.com/pdfcpu/pdfcpu/pkg/api"
	"github.com/pdfcpu/pdfcpu/pkg/pdfcpu/model"
	"github.com/shibukawa/bdf"
	"os"
	"strings"
	"testing"
)

func pageGraphicsBytes(b []byte) string {
	var s strings.Builder
	s.WriteString(`b"`)
	for _, v := range b {
		fmt.Fprintf(&s, `\x%02x`, v)
	}
	s.WriteString(`"`)
	return s.String()
}
func TestCodexPDFGraphicsPages(t *testing.T) {
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dest == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, e := os.Create(dest)
	if e != nil {
		t.Fatal(e)
	}
	defer out.Close()
	for i := 0; i < 16; i++ {
		content := []byte("q 0.2 0.4 0.8 rg 10 20 100 60 re f Q 2 w 0 0 m 20 40 l S\n")
		resources := ""
		if i == 8 {
			content = []byte("/CS1 cs 0.1 0.4 0.8 sc 10 20 100 60 re f\n")
			resources = "/Resources << /ColorSpace << /CS1 [/DeviceRGB] >> >>"
		}
		if i == 9 {
			content = []byte("/CS1 cs 0.1 0.2 0.3 0.4 sc 10 20 100 60 re f\n")
			resources = "/Resources << /ColorSpace << /CS1 /DeviceCMYK >> >>"
		}
		profile := ""
		if i >= 10 && i <= 12 {
			resources = "/Resources << /ColorSpace << /CS1 [/ICCBased 5 0 R] >> >>"
			switch i {
			case 10:
				profile = "/N 1"
				content = []byte("/CS1 cs .5 sc 10 20 100 60 re f\n")
			case 11:
				profile = "/N 4"
				content = []byte("/CS1 cs .1 .2 .3 .4 sc 10 20 100 60 re f\n")
			case 12:
				profile = "/N 0 /Alternate /DeviceGray"
				content = []byte("/CS1 cs .5 sc 10 20 100 60 re f\n")
			}
		}
		if i == 13 {
			resources = "/Resources << /ExtGState << /GS1 << /ca 0.3 /CA 0.7 /BM /Multiply /LW 3 /LC 1 /LJ 2 /ML 8 /D [[2 1] 0.5] >> >> >>"
			content = []byte("q /GS1 gs 0 0 40 50 re B Q 2 3 m 10 15 l S\n")
		}
		if i == 14 {
			resources = "/Resources << /ExtGState << /GS1 << /ca 0 /CA 1 /BM [/Screen /Multiply] /SMask /None >> >> >>"
			content = []byte("/GS1 gs 0 0 40 50 re B\n")
		}
		if i == 15 {
			content = []byte("/missing gs 0 0 40 50 re f\n")
		}
		filter := ""
		if i&1 != 0 {
			var b bytes.Buffer
			w := zlib.NewWriter(&b)
			w.Write(content)
			w.Close()
			content = b.Bytes()
			filter = "/Filter /FlateDecode"
		}
		var b bytes.Buffer
		b.WriteString("%PDF-1.7\n%graphics\n")
		count := 5
		if profile != "" {
			count = 6
		}
		offsets := make([]int, count)
		objects := []string{"<< /Type /Catalog /Pages 2 0 R >>", fmt.Sprintf("<< /Type /Pages /Kids [3 0 R] /Count 1 /MediaBox [0 0 600 800] /CropBox [10 20 500 700] /Rotate %d %s >>", (i/2)*90, resources), "<< /Type /Page /Parent 2 0 R /Contents 4 0 R >>"}
		for j, object := range objects {
			offsets[j+1] = b.Len()
			fmt.Fprintf(&b, "%d 0 obj\n%s\nendobj\n", j+1, object)
		}
		offsets[4] = b.Len()
		fmt.Fprintf(&b, "4 0 obj\n<< /Length %d %s >>\nstream\n", len(content), filter)
		b.Write(content)
		b.WriteString("\nendstream\nendobj\n")
		if profile != "" {
			offsets[5] = b.Len()
			fmt.Fprintf(&b, "5 0 obj\n<< /Length 0 %s >>\nstream\n\nendstream\nendobj\n", profile)
		}
		xref := b.Len()
		fmt.Fprintf(&b, "xref\n0 %d\n0000000000 65535 f \n", count)
		for _, offset := range offsets[1:] {
			fmt.Fprintf(&b, "%010d 00000 n \n", offset)
		}
		fmt.Fprintf(&b, "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n", count, xref)
		data := b.Bytes()
		ctx, e := api.ReadContext(context.Background(), bytes.NewReader(data), model.NewDefaultConfiguration())
		if e != nil {
			t.Fatal(e)
		}
		p := &pdf{ctx: ctx}
		leaves, _, e := p.pageLeaves()
		if e != nil || len(leaves) != 1 {
			t.Fatalf("pages: %v", e)
		}
		page := &pageRef{attrs: leaves[0].attrs, dict: leaves[0].dict}
		page.geometry(p, "crop")
		decoded, e := p.pageContent(page.dict)
		if e != nil {
			t.Fatal(e)
		}
		c := &converter{pdf: p, warned: map[string]bool{}}
		obj := newPending(bdf.Rect{X: 0, Y: 0, W: float32(page.w), H: float32(page.h)})
		in := c.newInterp(obj, leaves[0].attrs.Resources, page.base, 0)
		in.transform(page.base)
		in.run(decoded)
		fmt.Fprintf(out, "///|\ntest \"PDF graphics page matches upstream Go %d\" {\n check_pdf_graphics_page(%s,%#.17g,%#.17g,%s)\n}\n", i, pageGraphicsBytes(data), page.w, page.h, pageGraphicsBytes(obj.obj.Encode()))
	}
}
