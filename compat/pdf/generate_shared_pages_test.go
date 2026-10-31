//go:build ignore

// Overlay this file in upstream converter/pdf and set BDF_REFERENCE_OUTPUT.
package pdf

import (
	"bytes"
	"fmt"
	"os"
	"strings"
	"testing"
)

func sharedBytes(b []byte) string {
	var s strings.Builder
	s.WriteString(`b"`)
	for _, v := range b {
		fmt.Fprintf(&s, `\x%02x`, v)
	}
	s.WriteString(`"`)
	return s.String()
}
func TestCodexPDFSharedPages(t *testing.T) {
	out, e := os.Create(os.Getenv("BDF_REFERENCE_OUTPUT"))
	if e != nil {
		t.Fatal(e)
	}
	defer out.Close()
	for scenario := 0; scenario < 8; scenario++ {
		count := 2
		if scenario == 7 {
			count = 4
		}
		objects := make([]string, 6+count*2)
		objects[0] = "<< /Type /Catalog /Pages 2 0 R >>"
		kids := make([]string, count)
		for i := 0; i < count; i++ {
			kids[i] = fmt.Sprintf("%d 0 R", 3+i)
		}
		objects[1] = fmt.Sprintf("<< /Type /Pages /Kids [%s] /Count %d /MediaBox [0 0 600 800] >>", strings.Join(kids, " "), count)
		font0 := 3 + 2*count
		font1 := font0 + 1
		objects[font0-1] = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>"
		objects[font1-1] = objects[font0-1]
		if scenario == 4 {
			objects[font0-1] = "<< /Type /Font /Subtype /Type0 /BaseFont /MS-Mincho /Encoding /UniJIS-UTF16-V /DescendantFonts [" + fmt.Sprint(font1) + " 0 R] >>"
			objects[font1-1] = "<< /Type /Font /Subtype /CIDFontType2 /BaseFont /MS-Mincho /CIDSystemInfo << /Registry (Adobe) /Ordering (Japan1) /Supplement 0 >> >>"
		}
		for i := 0; i < count; i++ {
			streamID := 3 + count + i
			fontResource := fmt.Sprintf("%d 0 R", font0)
			if scenario == 2 && i%2 == 1 {
				fontResource = fmt.Sprintf("%d 0 R", font1)
			}
			if scenario == 3 {
				fontResource = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>"
			}
			objects[2+i] = fmt.Sprintf("<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 %s >> >> /Contents %d 0 R >>", fontResource, streamID)
			var c strings.Builder
			if scenario > 0 {
				if scenario == 4 {
					c.WriteString("BT /F1 12 Tf <30423044> Tj ET\n")
				} else {
					text := "A"
					if scenario == 5 && i%2 == 1 {
						text = "B"
					}
					fmt.Fprintf(&c, "BT /F1 12 Tf (%s) Tj ET\n", text)
				}
			}
			loops := 260
			if scenario == 6 {
				loops = 10
			}
			for j := 0; j < loops; j++ {
				fmt.Fprintf(&c, "%d %d 2 3 re f\n", j%20, j/20)
			}
			if scenario == 7 && i >= 3 {
				c.WriteString("1 0 0 rg 0 0 3 3 re f\n")
			}
			fmt.Fprintf(&c, "%d 200 4 5 re f\n", i)
			content := c.String()
			objects[streamID-1] = fmt.Sprintf("<< /Length %d >>\nstream\n%s\nendstream", len(content), content)
		}
		// The last four slots are deliberately unused by no object; omit them.
		objects = objects[:font1]
		var b bytes.Buffer
		b.WriteString("%PDF-1.7\n%sharing\n")
		offsets := make([]int, len(objects)+1)
		for i, o := range objects {
			offsets[i+1] = b.Len()
			fmt.Fprintf(&b, "%d 0 obj\n%s\nendobj\n", i+1, o)
		}
		xref := b.Len()
		fmt.Fprintf(&b, "xref\n0 %d\n0000000000 65535 f \n", len(offsets))
		for _, v := range offsets[1:] {
			fmt.Fprintf(&b, "%010d 00000 n \n", v)
		}
		fmt.Fprintf(&b, "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n", len(offsets), xref)
		for mask := 0; mask < 4; mask++ {
			opt := &Options{NoSharePrefix: mask&1 != 0, NoTextIndex: mask&2 != 0}
			result, err := Convert(bytes.NewReader(b.Bytes()), opt)
			if err != nil {
				t.Fatalf("case %d mask %d: %v", scenario, mask, err)
			}
			var doc bytes.Buffer
			if err = result.Doc.WriteSingle(&doc); err != nil {
				t.Fatal(err)
			}
			fmt.Fprintf(out, "///|\ntest \"PDF shared document matches Go %d %d\" {\n check_pdf_shared_document(%s,%t,%t,%s,%d,%d,[", scenario, mask, sharedBytes(b.Bytes()), opt.NoSharePrefix, opt.NoTextIndex, sharedBytes(doc.Bytes()), result.SharedPrefixes, result.SharedBytes)
			for _, w := range result.Warnings {
				fmt.Fprintf(out, "%q,", w)
			}
			fmt.Fprint(out, "])\n}\n")
		}
	}
}
