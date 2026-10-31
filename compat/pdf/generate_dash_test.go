//go:build ignore

// Copy without its build tag beside upstream converter/pdf/interp.go, set
// BDF_REFERENCE_OUTPUT, then run TestCodexPDFDashKeys.
package pdf

import (
	"fmt"
	"math"
	"math/rand"
	"os"
	"testing"
)

func TestCodexPDFDashKeys(t *testing.T) {
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dest == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, e := os.Create(dest)
	if e != nil {
		t.Fatal(e)
	}
	defer out.Close()
	r := rand.New(rand.NewSource(341))
	pairs := [][2]float64{{0, math.Copysign(0, -1)}, {0.00005, 0.00004999999}, {1.00004, 1.00003}, {-0.00005, 0}, {1e300, 1e300}}
	for i := 0; i < 507; i++ {
		n := r.Intn(2000001) - 1000000
		a := float64(n) / 10000
		b := a + float64(r.Intn(21)-10)*0.00001
		pairs = append(pairs, [2]float64{a, b})
	}
	for i, pair := range pairs {
		if i%64 == 0 {
			fmt.Fprintf(out, "///|\ntest \"PDF dash keys match upstream Go %d\" {\n", i/64)
		}
		equal := dashKey([]float64{pair[0]}, 0) == dashKey([]float64{pair[1]}, 0)
		fmt.Fprintf(out, "check_pdf_dash_keys(%#.17g,%#.17g,%t)\n", pair[0], pair[1], equal)
		if i%64 == 63 || i == len(pairs)-1 {
			fmt.Fprintln(out, "}")
		}
	}
}
