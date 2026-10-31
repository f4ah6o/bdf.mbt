//go:build ignore

// Copy into upstream converter/internal/ooxml/drawingml and run
// TestCodexFormulaPathReference with BDF_REFERENCE_OUTPUT set.
package drawingml

import (
	"fmt"
	"math"
	"os"
	"testing"

	"github.com/shibukawa/bdf/converter/internal/ooxml"
)

func TestCodexFormulaPathReference(t *testing.T) {
	names := []string{"bentUpArrow", "corner", "diagStripe", "dodecagon", "downArrow", "downArrowCallout", "halfFrame", "heptagon", "leftArrow", "leftArrowCallout", "leftRightArrow", "leftRightArrowCallout", "leftRightUpArrow", "leftUpArrow", "mathMinus", "mathPlus", "nonIsoscelesTrapezoid", "notchedRightArrow", "quadArrow", "quadArrowCallout", "rightArrow", "rightArrowCallout", "snip1Rect", "snip2DiagRect", "snip2SameRect", "star10", "star7", "upArrowCallout", "upDownArrow", "upArrow", "upDownArrowCallout", "wedgeRectCallout"}
	path := os.Getenv("BDF_REFERENCE_OUTPUT")
	if path == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	fmt.Fprintln(out, "///|\n// Generated from upstream DrawingML preset geometry.\ntest \"formula preset paths match Go\" {")
	defs := loadPresets()
	for index, name := range names {
		for i := 0; i < 16; i++ {
			w := float64((index*12347+i*313)%254000000) / 12700
			h := float64((index*7919+i*719)%254000000) / 12700
			path := evalGeometry(defs[name], nil, w, h).paths[0].path
			fmt.Fprintf(out, "  check_formula_preset_path(%q, %.17g, %.17g, None, [", name, w, h)
			for _, v := range path.Args {
				fmt.Fprintf(out, "0x%08xU,", math.Float32bits(v))
			}
			fmt.Fprintln(out, "])")
		}
	}
	for index, name := range names {
		guide := "adj1"
		if name == "diagStripe" || name == "snip1Rect" || name == "star10" || name == "star7" {
			guide = "adj"
		}
		if name == "dodecagon" || name == "heptagon" {
			continue
		}
		for i := 0; i < 8; i++ {
			w := float64((index*12347+i*313)%254000000) / 12700
			h := float64((index*7919+i*719)%254000000) / 12700
			adj := []int{0, 1, 16667, 25000, 50000, 75000, 99999, 100000}[i]
			override, err := ooxml.Parse([]byte(fmt.Sprintf(`<avLst><gd name="%s" fmla="val %d"/></avLst>`, guide, adj)))
			if err != nil {
				t.Fatal(err)
			}
			path := evalGeometry(defs[name], override, w, h).paths[0].path
			fmt.Fprintf(out, "  check_formula_preset_path(%q, %.17g, %.17g, Some(%dL), [", name, w, h, adj)
			for _, v := range path.Args {
				fmt.Fprintf(out, "0x%08xU,", math.Float32bits(v))
			}
			fmt.Fprintln(out, "])")
		}
	}
	fmt.Fprintln(out, `}

///|
fn check_formula_preset_path(name : String, width : Double, height : Double, adjustment : Int64?, expected : Array[UInt32]) -> Unit raise {
  let path = sheet_formula_preset_path(name, width, height, adjustment)
  assert_eq(path.coordinates.length(), expected.length())
  for i in 0..<expected.length() {
    assert_eq(Float::from_double(path.coordinates[i]).reinterpret_as_uint(), expected[i])
  }
}`)
}
