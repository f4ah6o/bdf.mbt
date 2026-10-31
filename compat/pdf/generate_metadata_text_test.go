//go:build ignore

// Copy without its build tag beside upstream converter/pdf/meta.go and
// structure.go, set BDF_REFERENCE_OUTPUT and run TestCodexPDFMetadataText.
package pdf

import (
	"fmt"
	"math/rand"
	"os"
	"strings"
	"testing"
)

func metadataBytes(b []byte) string {
	var s strings.Builder
	s.WriteString(`b"`)
	for _, v := range b {
		fmt.Fprintf(&s, `\x%02x`, v)
	}
	s.WriteString(`"`)
	return s.String()
}
func TestCodexPDFMetadataText(t *testing.T) {
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dest == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, e := os.Create(dest)
	if e != nil {
		t.Fatal(e)
	}
	defer out.Close()
	cases := [][]byte{{}, {0xfe, 0xff, 0xd8, 0x3d, 0xde, 0x00}, {0xfe, 0xff, 0xd8, 0x00, 0x00, 0x00}, {0xfe, 0xff, 0xdc, 0x00}, {0xef, 0xbb, 0xbf, 0xff}, {0xc3, 0xa9}}
	for i := 0; i < 256; i++ {
		cases = append(cases, []byte{byte(i)})
	}
	r := rand.New(rand.NewSource(5401))
	for i := 0; i < 762; i++ {
		data := make([]byte, r.Intn(20))
		r.Read(data)
		switch i % 4 {
		case 0:
			data = append([]byte{0xfe, 0xff}, data...)
		case 1:
			data = append([]byte{0xef, 0xbb, 0xbf}, data...)
		}
		cases = append(cases, data)
	}
	for i, data := range cases {
		if i%64 == 0 {
			fmt.Fprintf(out, "///|\ntest \"PDF text encoding matches upstream Go %d\" {\n", i/64)
		}
		want := []byte(string([]rune(decodeText(data))))
		fmt.Fprintf(out, "check_pdf_metadata_text(%s,%s)\n", metadataBytes(data), metadataBytes(want))
		if i%64 == 63 || i == len(cases)-1 {
			fmt.Fprintln(out, "}")
		}
	}
}
