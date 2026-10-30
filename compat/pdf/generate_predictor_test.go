//go:build ignore

// Copy without the build tag beside upstream converter/pdf/flate.go and run
// TestCodexPredictorReference with BDF_REFERENCE_OUTPUT set.
package pdf

import (
	"fmt"
	"math/rand"
	"os"
	"strings"
	"testing"
)

func predictorBytes(b []byte) string {
	var s strings.Builder
	s.WriteString(`b"`)
	for _, c := range b {
		fmt.Fprintf(&s, `\x%02x`, c)
	}
	s.WriteString(`"`)
	return s.String()
}
func TestCodexPredictorReference(t *testing.T) {
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dest == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(dest)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	rng := rand.New(rand.NewSource(41811))
	fmt.Fprintln(out, "///|\n// Generated from upstream PDF TIFF and PNG predictor decoding.\ntest \"PDF predictors match upstream Go\" {")
	predictors := []int{-1, 0, 1, 2, 5, 9, 10, 11, 12, 13, 14, 15, 16}
	bits := []int{1, 2, 4, 8, 16, 3}
	for i := 0; i < 1024; i++ {
		p := predictors[rng.Intn(len(predictors))]
		b := bits[rng.Intn(len(bits))]
		colors := 1 + rng.Intn(6)
		columns := 1 + rng.Intn(30)
		if i%41 == 0 {
			colors = 0
		}
		if i%53 == 0 {
			columns = 0
		}
		rowsize := (b*colors*columns + 7) / 8
		rowlen := rowsize
		if p >= 10 && p <= 15 {
			rowlen++
		}
		raw := make([]byte, rowlen*(1+rng.Intn(5))+rng.Intn(8))
		rng.Read(raw)
		if p >= 10 && p <= 15 && rowlen > 0 {
			for j := 0; j+rowlen <= len(raw); j += rowlen {
				raw[j] = byte(rng.Intn(7))
			}
		}
		parms := map[string]int{"Predictor": p, "Colors": colors, "BitsPerComponent": b, "Columns": columns}
		err := checkPredictor(parms, len(raw))
		var want []byte
		if err == nil {
			var pred *predictor
			pred, err = newPredictor(parms)
			if err == nil {
				if pred.kind == predictNone {
					want = raw
				} else {
					want, err = pred.undo(append([]byte(nil), raw...))
				}
			}
		}
		expected := "None"
		if err == nil {
			expected = "Some(" + predictorBytes(want) + ")"
		}
		fmt.Fprintf(out, "  check_pdf_predictor(%s,%d,%d,%d,%d,%s)\n", predictorBytes(raw), p, colors, b, columns, expected)
	}
	fmt.Fprintln(out, `}

///|
fn check_pdf_predictor(raw : Bytes, kind : Int, colors : Int, bits : Int, columns : Int, expected : Bytes?) -> Unit raise {
  let actual : Bytes? = try {
    let predictor = pdf_predictor(kind, colors, bits, columns, raw.length())
    Some(predictor.undo(raw))
  } catch { _ => None }
  assert_eq(actual, expected)
}`)
}
