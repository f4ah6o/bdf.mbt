//go:build ignore

// Overlay beside the upstream DrawingML package and set BDF_REFERENCE_OUTPUT.
package drawingml

import (
	"fmt"
	"github.com/shibukawa/bdf/converter/internal/ooxml"
	"math/rand"
	"os"
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
	rotations := []string{"0", "5400000", "-2700000", "1234.5", "bad", " 42000 "}
	bools := []string{"1", "0", "true", "false", "on", "off", "bad"}
	fmt.Fprintln(out, "///|\ntest \"PPTX transforms match upstream Go\" {\n let cases : Array[(String, (Double, Double, Double, Double, Double, Bool, Bool)?)] = [")
	for i := 0; i < 256; i++ {
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
		fmt.Fprintf(out, "(%q,%s),\n", xml, expected)
	}
	fmt.Fprintln(out, "]\n for (xml, expected) in cases {\n  let actual = match pptx_transform(xml) { Some(xf) => Some((xf.x, xf.y, xf.width, xf.height, xf.rotation, xf.flip_h, xf.flip_v)); None => None }\n  assert_eq(actual, expected, msg=xml)\n }\n}")
}
