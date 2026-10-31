//go:build ignore

// Overlay beside the upstream pdf package and set BDF_REFERENCE_OUTPUT.
package pdf

import (
	"bytes"
	"context"
	"fmt"
	"github.com/pdfcpu/pdfcpu/pkg/api"
	"github.com/pdfcpu/pdfcpu/pkg/pdfcpu/model"
	"os"
	"strings"
	"testing"
)

func codexVerticalBytes(b []byte) string {
	var s strings.Builder
	s.WriteString(`b"`)
	for _, v := range b {
		fmt.Fprintf(&s, `\x%02x`, v)
	}
	s.WriteString(`"`)
	return s.String()
}
func TestCodexPDFVerticalMetrics(t *testing.T) {
	out, err := os.Create(os.Getenv("BDF_REFERENCE_OUTPUT"))
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	cases := []struct {
		encoding, spec string
		encoded        []byte
	}{
		{"Identity-V", "", []byte{0, 1, 0, 2, 0, 10, 0, 11, 0, 12}},
		{"Identity-V", "/DW 900 /W [1 [500 700] 10 12 600] /W2 [1 [-900 300 800 -1100 400 900] 10 12 -1200 500 840]", []byte{0, 1, 0, 2, 0, 10, 0, 11, 0, 12, 0, 13}},
		{"Identity-V", "/DW2 [1000 -1400] /W2 [1 [-800 450 900]]", []byte{0, 1, 0, 2, 0, 3}},
		{"Identity-V", "/DW2 [0 0] /W2 [1 [/bad 200 300 400 /bad 600]]", []byte{0, 1, 0, 2, 0, 3}},
		{"UniJIS-UTF16-V", "/DW 750 /W2 [1 5 -1250 375 870]", []byte{0, 65, 0x30, 0x42}},
		{"Identity-V", "/W2 [10 9 -500 200 300]", []byte{0, 9, 0, 10, 0, 11}},
	}
	for i, tc := range cases {
		objects := []string{
			"<< /Type /Catalog /Pages 2 0 R >>",
			"<< /Type /Pages /Kids [3 0 R] /Count 1 /MediaBox [0 0 600 800] /Resources << /Font << /F1 4 0 R >> >> >>",
			"<< /Type /Page /Parent 2 0 R >>",
			fmt.Sprintf("<< /Type /Font /Subtype /Type0 /BaseFont /MS-Mincho /Encoding /%s /DescendantFonts [5 0 R] >>", tc.encoding),
			fmt.Sprintf("<< /Type /Font /Subtype /CIDFontType2 /BaseFont /MS-Mincho /CIDSystemInfo << /Registry (Adobe) /Ordering (Japan1) /Supplement 0 >> %s >>", tc.spec),
		}
		var data bytes.Buffer
		data.WriteString("%PDF-1.7\n%vertical\n")
		offsets := make([]int, len(objects)+1)
		for j, object := range objects {
			offsets[j+1] = data.Len()
			fmt.Fprintf(&data, "%d 0 obj\n%s\nendobj\n", j+1, object)
		}
		xref := data.Len()
		fmt.Fprintf(&data, "xref\n0 %d\n0000000000 65535 f \n", len(offsets))
		for _, offset := range offsets[1:] {
			fmt.Fprintf(&data, "%010d 00000 n \n", offset)
		}
		fmt.Fprintf(&data, "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n", len(offsets), xref)
		ctx, err := api.ReadContext(context.Background(), bytes.NewReader(data.Bytes()), model.NewDefaultConfiguration())
		if err != nil {
			t.Fatal(err)
		}
		p := &pdf{ctx: ctx}
		leaves, _, err := p.pageLeaves()
		if err != nil || len(leaves) != 1 {
			t.Fatal(err)
		}
		fonts := p.dict(leaves[0].attrs.Resources["Font"])
		c := &converter{pdf: p, opts: &Options{}, fonts: map[string]*pdfFont{}, warned: map[string]bool{}}
		f := c.loadFont(fonts["F1"], leaves[0].attrs.Resources)
		if f == nil || !f.vertical() {
			t.Fatal("vertical font missing")
		}
		fmt.Fprintf(out, "///|\ntest \"PDF vertical font metrics match upstream Go %d\" {\n check_pdf_vertical_font(%s,%s,[\n", i, codexVerticalBytes(data.Bytes()), codexVerticalBytes(tc.encoded))
		for _, g := range f.decode(tc.encoded) {
			w := f.width(g)
			w1, x, y := f.vmetrics(g, w)
			fmt.Fprintf(out, "(%dL,%d,%dL,%#.17g,%#.17g,%#.17g,%#.17g),\n", g.code, g.nbytes, g.cid, w, w1, x, y)
		}
		fmt.Fprintln(out, "])\n}")
	}
}
