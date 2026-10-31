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
	for i := 0; i < 26; i++ {
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
		font := ""
		if i >= 17 {
			resources = "/Resources << /Font << /F1 5 0 R >> >>"
			font = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>"
			switch i {
			case 17:
				content = []byte("BT /F1 12 Tf 1 0 0 1 100 200 Tm (Hello World) Tj ET")
			case 18:
				content = []byte("BT /F1 14 Tf 20 30 Td (A) Tj (B) Tj ET")
			case 19:
				content = []byte("0.2 0.4 0.8 rg BT /F1 10 Tf <4380e9> Tj ET")
			case 20:
				content = []byte("BT /F1 18 Tf 0 1 -1 0 200 300 Tm (Rotate) Tj ET")
			case 21:
				content = []byte("BT /F1 12 Tf (First) Tj ET BT /F1 12 Tf 10 20 Td (Second) Tj ET")
			case 22:
				content = []byte("q 2 Tc Q BT /F1 12 Tf (Restored) Tj ET")
			case 23:
				content = []byte("BT /missing 12 Tf (Fallback) Tj ET")
			case 24:
				content = []byte("BT /F1 12 Tf (First) Tj ET q BT /F1 12 Tf (Second) Tj ET Q")
			case 25:
				content = []byte("BT /F1 12 Tf <0100ff01> Tj ET")
			}
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
		if profile != "" || i == 16 || font != "" {
			count = 6
		}
		offsets := make([]int, count)
		catalog := "<< /Type /Catalog /Pages 2 0 R >>"
		if i == 16 {
			catalog = "<< /Type /Catalog /Pages 2 0 R /Lang (ja-JP) >>"
		}
		objects := []string{catalog, fmt.Sprintf("<< /Type /Pages /Kids [3 0 R] /Count 1 /MediaBox [0 0 600 800] /CropBox [10 20 500 700] /Rotate %d %s >>", (i/2)*90, resources), "<< /Type /Page /Parent 2 0 R /Contents 4 0 R >>"}
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
		if font != "" {
			offsets[5] = b.Len()
			fmt.Fprintf(&b, "5 0 obj\n%s\nendobj\n", font)
		}
		if i == 16 {
			offsets[5] = b.Len()
			b.WriteString("5 0 obj\n<< /Title (Sample) /Author (Alice) /Subject (Description) /Keywords (first, second) /CreationDate (D:20241015123000+09'00') /ModDate (D:20241016) >>\nendobj\n")
		}
		xref := b.Len()
		fmt.Fprintf(&b, "xref\n0 %d\n0000000000 65535 f \n", count)
		for _, offset := range offsets[1:] {
			fmt.Fprintf(&b, "%010d 00000 n \n", offset)
		}
		info := ""
		if i == 16 {
			info = "/Info 5 0 R"
		}
		fmt.Fprintf(&b, "trailer\n<< /Size %d /Root 1 0 R %s >>\nstartxref\n%d\n%%%%EOF\n", count, info, xref)
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
		c := &converter{pdf: p, opts: &Options{}, warned: map[string]bool{}, fonts: map[string]*pdfFont{}}
		obj := newPending(bdf.Rect{X: 0, Y: 0, W: float32(page.w), H: float32(page.h)})
		in := c.newInterp(obj, leaves[0].attrs.Resources, page.base, 0)
		in.transform(page.base)
		in.run(decoded)
		fmt.Fprintf(out, "///|\ntest \"PDF graphics page matches upstream Go %d\" {\n check_pdf_graphics_page(%s,%#.17g,%#.17g,%s)\n}\n", i, pageGraphicsBytes(data), page.w, page.h, pageGraphicsBytes(obj.obj.Encode()))

		result, err := Convert(bytes.NewReader(data), &Options{NoTextIndex: true, NoSharePrefix: true})
		if err != nil {
			t.Fatal(err)
		}
		var document bytes.Buffer
		if err = result.Doc.WriteSingle(&document); err != nil {
			t.Fatal(err)
		}
		fmt.Fprintf(out, "///|\ntest \"PDF graphics document matches upstream Go %d\" {\n check_pdf_graphics_document(%s,%s)\n}\n", i, pageGraphicsBytes(data), pageGraphicsBytes(document.Bytes()))
		if i == 16 {
			optionResult, err := Convert(bytes.NewReader(data), &Options{NoTextIndex: true, NoSharePrefix: true, Box: "media", Title: "Overridden"})
			if err != nil {
				t.Fatal(err)
			}
			var optionDocument bytes.Buffer
			if err = optionResult.Doc.WriteSingle(&optionDocument); err != nil {
				t.Fatal(err)
			}
			fmt.Fprintf(out, "///|\ntest \"PDF graphics document options match upstream Go\" {\n check_pdf_graphics_document_options(%s,%s)\n}\n", pageGraphicsBytes(data), pageGraphicsBytes(optionDocument.Bytes()))
		}
	}
	var empty bytes.Buffer
	empty.WriteString("%PDF-1.7\n%empty\n")
	offsets := make([]int, 3)
	for i, obj := range []string{"<< /Type /Catalog /Pages 2 0 R >>", "<< /Type /Pages /Count 0 /Kids [] >>"} {
		offsets[i+1] = empty.Len()
		fmt.Fprintf(&empty, "%d 0 obj\n%s\nendobj\n", i+1, obj)
	}
	xref := empty.Len()
	empty.WriteString("xref\n0 3\n0000000000 65535 f \n")
	for _, offset := range offsets[1:] {
		fmt.Fprintf(&empty, "%010d 00000 n \n", offset)
	}
	fmt.Fprintf(&empty, "trailer\n<< /Size 3 /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n", xref)
	result, err := Convert(bytes.NewReader(empty.Bytes()), &Options{NoTextIndex: true, NoSharePrefix: true})
	if err != nil {
		t.Fatal(err)
	}
	var document bytes.Buffer
	if err = result.Doc.WriteSingle(&document); err != nil {
		t.Fatal(err)
	}
	fmt.Fprintf(out, "///|\ntest \"empty PDF graphics document matches upstream Go\" {\n check_pdf_graphics_document(%s,%s)\n}\n", pageGraphicsBytes(empty.Bytes()), pageGraphicsBytes(document.Bytes()))

}
