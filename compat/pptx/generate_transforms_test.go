//go:build ignore

// Overlay beside the upstream DrawingML package and set BDF_REFERENCE_OUTPUT.
package drawingml

import (
	"fmt"
	"github.com/shibukawa/bdf/converter/internal/ooxml"
	"math"
	"math/rand"
	"os"
	"strings"
	"testing"
)

func TestCodexPPTXTransforms(t *testing.T) {
	out, err := os.Create(os.Getenv("BDF_REFERENCE_OUTPUT"))
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	rng := rand.New(rand.NewSource(730417))
	measures := []string{"0", "12700", "-25400", "9144000", "1in", "2.54cm", "7.2pt", "bad", " 3600 "}
	rotations := []string{"0", "5400000", "-2700000", "1234.5", "bad", " 42000 ", "1987654", "-9876543", "12345678", "1800000"}
	bools := []string{"1", "0", "true", "false", "on", "off", "bad"}
	fmt.Fprintln(out, "///|\ntest \"PPTX transforms match upstream Go\" {\n let cases : Array[(String, (Double, Double, Double, Double, Double, Bool, Bool)?, Array[UInt32], Array[UInt32])] = [")
	for i := 0; i < 512; i++ {
		pick := func(a []string) string { return a[rng.Intn(len(a))] }
		xml := fmt.Sprintf("<xfrm rot=%q flipH=%q flipV=%q>", pick(rotations), pick(bools), pick(bools))
		if rng.Intn(4) != 0 {
			xml += fmt.Sprintf("<off x=%q y=%q/>", pick(measures), pick(measures))
		}
		if rng.Intn(4) != 0 {
			xml += fmt.Sprintf("<ext cx=%q cy=%q/>", pick(measures), pick(measures))
		}
		if rng.Intn(4) == 0 {
			xml += "<off x=\"999\" y=\"999\"/>"
		}
		xml += "</xfrm>"
		n, err := ooxml.Parse([]byte(xml))
		if err != nil {
			t.Fatal(err)
		}
		xf, ok := parseXfrm(n)
		expected := "None"
		if ok {
			expected = fmt.Sprintf("Some((%#.17g,%#.17g,%#.17g,%#.17g,%#.17g,%t,%t))", xf.X, xf.Y, xf.W, xf.H, xf.Rot, xf.FlipH, xf.FlipV)
		}
		matrixBits := func(text bool) string {
			if !ok {
				return "[]"
			}
			matrix := xf.matrix()
			if text {
				matrix = xf.textMatrix()
			}
			var result strings.Builder
			result.WriteString("[")
			for _, value := range matrix {
				fmt.Fprintf(&result, "0x%08xU,", math.Float32bits(float32(value)))
			}
			result.WriteString("]")
			return result.String()
		}
		fmt.Fprintf(out, "(%q,%s,%s,%s),\n", xml, expected, matrixBits(false), matrixBits(true))
	}
	fmt.Fprintln(out, "]\n for (xml, expected, graphics, text) in cases {\n  let xf = pptx_transform(xml)\n  let actual = match xf { Some(value) => Some((value.x, value.y, value.width, value.height, value.rotation, value.flip_h, value.flip_v)); None => None }\n  assert_eq(actual, expected, msg=xml)\n  match xf { Some(value) => { assert_eq(pptx_matrix_bits(value.matrix(false)), graphics, msg=xml); assert_eq(pptx_matrix_bits(value.matrix(true)), text, msg=xml) }; None => () }\n }\n}")
}
