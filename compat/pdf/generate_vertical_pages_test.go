//go:build ignore

// Copy without the build tag into upstream converter/pdf and set BDF_REFERENCE_OUTPUT.
package pdf

import (
	"bytes"
	"fmt"
	"os"
	"strings"
	"testing"
)

func verticalBytes(b []byte) string {
	var s strings.Builder
	s.WriteString(`b"`)
	for _, v := range b {
		fmt.Fprintf(&s, `\x%02x`, v)
	}
	s.WriteString(`"`)
	return s.String()
}

func TestCodexVerticalPages(t *testing.T) {
	f, err := os.Create(os.Getenv("BDF_REFERENCE_OUTPUT"))
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	cases := []string{
		"BT /F1 16 Tf 1 0 0 1 100 700 Tm <30423044> Tj ET",
		"BT /F1 12 Tf <3042> Tj <30443046> Tj ET",
		"BT /F1 16 Tf .25 Tc [<3042> -200 <3044> 75 <3046>] TJ ET",
		"BT /F1 16 Tf 75 Tz 3 Ts <30423044> Tj ET",
		"BT /F1 12 Tf 3 Tr <30423044> Tj ET",
		"1 0 0 RG 2 w BT /F1 12 Tf 1 Tr <30423044> Tj ET",
		".25 .5 .75 rg 0 0 1 RG 1.5 w BT /F1 12 Tf .5 0 0 .5 100 200 Tm 2 Tr <30423044> Tj ET",
		"BT /F1 12 Tf <3001300230fc> Tj ET",
		"BT /F1 0 Tf 1 Tr <30423044> Tj ET",
		"BT /F1 12 Tf <3042> Tj 2 Tc <3044> Tj ET",
		"BT /F1 12 Tf <3042> Tj /F1 18 Tf <3044> Tj ET",
		"BT /F1 12 Tf <3042> Tj 3 Tr <3044> Tj 0 Tr <3046> Tj ET",
		"BT /F1 12 Tf 4 Tr <30423044> Tj ET",
		"BT /F1 12 Tf 5 Tr <30423044> Tj ET",
		"BT /F1 12 Tf 6 Tr <30423044> Tj ET",
		"BT /F1 12 Tf 7 Tr <30423044> Tj ET",
		"BT /F1 12 Tf -2 Tc [<3001> 300 <3042> -500 <30fc>] TJ ET",
		"BT /F1 14 Tf 0 1 -1 0 200 300 Tm <304230443046> Tj ET",
		"BT /F1 12 Tf <3042> Tj ET BT /F1 12 Tf 20 30 Td <3044> Tj ET",
		"BT /F1 12 Tf <3042> Tj 1 0 0 rg <3044> Tj ET",
		"BT /F1 12 Tf <00010002000a> Tj ET",
		"BT /F1 13 Tf .125 Tc [<00010002> 75 <000a>] TJ ET",
		"BT /F1 13 Tf .125 Tc 3.7 Tw (A B) Tj ET",
	}
	for i, content := range cases {
		objects := []string{
			"<< /Type /Catalog /Pages 2 0 R >>",
			"<< /Type /Pages /Kids [3 0 R] /Count 1 /MediaBox [0 0 600 800] /Resources << /Font << /F1 5 0 R >> >> >>",
			"<< /Type /Page /Parent 2 0 R /Contents 4 0 R >>",
			fmt.Sprintf("<< /Length %d >>\nstream\n%s\nendstream", len(content), content),
			"<< /Type /Font /Subtype /Type0 /BaseFont /MS-Mincho /Encoding /UniJIS-UTF16-V /DescendantFonts [6 0 R] >>",
			"<< /Type /Font /Subtype /CIDFontType2 /BaseFont /MS-Mincho /CIDSystemInfo << /Registry (Adobe) /Ordering (Japan1) /Supplement 0 >> /DW 900 /W [1 [500 700] 10 12 600] /DW2 [880 -1000] /W2 [1 [-900 250 850] 10 12 -950 300 880] /FontDescriptor << /Flags 2 /ItalicAngle -12 >> >>",
		}
		if i >= 20 {
			objects[4] = "<< /Type /Font /Subtype /Type0 /BaseFont /MS-Mincho /Encoding /Identity-V /DescendantFonts [6 0 R] /ToUnicode 7 0 R >>"
			cmap := "1 begincodespacerange <0000> <ffff> endcodespacerange 3 beginbfchar <0001> <3042> <0002> <3044> <000a> <3001> endbfchar"
			if i == 22 {
				objects[4] = "<< /Type /Font /Subtype /Type0 /BaseFont /MS-Mincho /Encoding 8 0 R /DescendantFonts [6 0 R] /ToUnicode 7 0 R >>"
				cmap = "1 begincodespacerange <00> <ff> endcodespacerange 3 beginbfchar <41> <3042> <20> <0020> <42> <3044> endbfchar"
				source := "/WMode 1 def 1 begincodespacerange <00> <ff> endcodespacerange 3 begincidchar <41> 1 <20> 10 <42> 2 endcidchar"
				objects = append(objects, fmt.Sprintf("<< /Length %d >>\nstream\n%s\nendstream", len(cmap), cmap), fmt.Sprintf("<< /Length %d >>\nstream\n%s\nendstream", len(source), source))
			} else {
				objects = append(objects, fmt.Sprintf("<< /Length %d >>\nstream\n%s\nendstream", len(cmap), cmap))
			}
		}
		var b bytes.Buffer
		b.WriteString("%PDF-1.7\n%vertical\n")
		offsets := make([]int, len(objects)+1)
		for j, o := range objects {
			offsets[j+1] = b.Len()
			fmt.Fprintf(&b, "%d 0 obj\n%s\nendobj\n", j+1, o)
		}
		xref := b.Len()
		fmt.Fprintf(&b, "xref\n0 %d\n0000000000 65535 f \n", len(offsets))
		for _, v := range offsets[1:] {
			fmt.Fprintf(&b, "%010d 00000 n \n", v)
		}
		fmt.Fprintf(&b, "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n", len(offsets), xref)
		result, e := Convert(bytes.NewReader(b.Bytes()), &Options{NoTextIndex: true, NoSharePrefix: true})
		if e != nil {
			t.Fatalf("case %d: %v", i, e)
		}
		var doc bytes.Buffer
		if e = result.Doc.WriteSingle(&doc); e != nil {
			t.Fatal(e)
		}
		fmt.Fprintf(f, "///|\ntest \"PDF vertical document matches upstream Go %d\" {\n check_pdf_graphics_document(%s,%s)\n}\n", i, verticalBytes(b.Bytes()), verticalBytes(doc.Bytes()))
	}
}
