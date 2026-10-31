//go:build ignore

// Copy without its build tag beside upstream converter/pdf/meta.go, set
// BDF_REFERENCE_OUTPUT, then run TestCodexPDFMetadataDate.
package pdf

import (
	"fmt"
	"math/rand"
	"os"
	"testing"
)

func TestCodexPDFMetadataDate(t *testing.T) {
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dest == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, e := os.Create(dest)
	if e != nil {
		t.Fatal(e)
	}
	defer out.Close()
	cases := []string{"", "D:2024", "20240229", "D:2024022912", "20240229123456Zjunk", "20240101235959+09'30'", "2024junk", "2024010100+99", "D:20241301", "D:20240000", "D:202401012460", "  D:2024111113-05'00'  "}
	r := rand.New(rand.NewSource(4133))
	zones := []string{"", "Z", "Zjunk", "+09'30'", "-04", "+ab", "garbage", "+9999", "+01'30'"}
	for len(cases) < 1036 {
		v := fmt.Sprintf("%04d%02d%02d%02d%02d%02d", r.Intn(10000), r.Intn(16), r.Intn(35), r.Intn(27), r.Intn(63), r.Intn(63))
		n := 4 + r.Intn(11)
		v = v[:n] + zones[r.Intn(len(zones))]
		if r.Intn(2) == 0 {
			v = "D:" + v
		}
		cases = append(cases, v)
	}
	for i, v := range cases {
		if i%64 == 0 {
			fmt.Fprintf(out, "///|\ntest \"PDF metadata dates match upstream Go %d\" {\n", i/64)
		}
		fmt.Fprintf(out, "check_pdf_metadata_date(%q,%q)\n", v, pdfDate(v))
		if i%64 == 63 || i == len(cases)-1 {
			fmt.Fprintln(out, "}")
		}
	}
}
