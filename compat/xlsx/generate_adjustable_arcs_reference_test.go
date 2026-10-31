//go:build ignore

// Copy into upstream converter/internal/ooxml/drawingml and run
// TestCodexAdjustableArcsReference with BDF_REFERENCE_OUTPUT set.
package drawingml

import (
	"fmt"
	"github.com/shibukawa/bdf/converter/internal/ooxml"
	"math"
	"os"
	"strings"
	"testing"
)

func TestCodexAdjustableArcsReference(t *testing.T) {
	names := []string{"plaque", "round1Rect", "round2DiagRect", "round2SameRect", "snipRoundRect", "bentArrow"}
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dest == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(dest)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	fmt.Fprintln(out, "///|\n// Generated from upstream DrawingML with adjustable arc preset paths.\ntest \"adjustable arc preset paths match Go\" {")
	defs := loadPresets()
	for index, name := range names {
		max := 1
		for _, g := range defs[name].av {
			if g.name == "adj2" {
				max = 2
			}
			if g.name == "adj3" {
				max = 3
			}
			if g.name == "adj4" {
				max = 4
			}
		}
		for i := 0; i < 128; i++ {
			w := float64((index*12347+i*7919879)%254000000) / 12700
			h := float64((index*7919+i*916177)%254000000) / 12700
			if i == 0 {
				w = 0
			}
			if i == 1 {
				h = 0
			}
			initial := "None"
			guides := ""
			mapitems := []string{}
			for j := max; j >= 1; j-- {
				if (i+j)%5 == 0 {
					continue
				}
				value := (i*(7919+j*2539) + index*4139) % 100001
				if i < 5 {
					value = []int{0, 1, 25000, 99999, 100000}[i]
				}
				guide := fmt.Sprintf("adj%d", j)
				if j == 1 && (name == "plaque" || name == "round1Rect") {
					guide = "adj"
				}
				guides += fmt.Sprintf(`<gd name="%s" fmla="val %d"/>`, guide, value)
				if j == 1 {
					initial = fmt.Sprintf("Some(%dL)", value)
				} else {
					mapitems = append(mapitems, fmt.Sprintf("(\"adj%d\", %dL)", j, value))
				}
			}
			override, err := ooxml.Parse([]byte("<avLst>" + guides + "</avLst>"))
			if err != nil {
				t.Fatal(err)
			}
			path := evalGeometry(defs[name], override, w, h).paths[0].path
			fmt.Fprintf(out, "  check_adjustable_arc_preset_path(%q, %.17g, %.17g, %s, Map([%s]), b%q, [", name, w, h, initial, strings.Join(mapitems, ","), string(path.Verbs))
			for _, v := range path.Args {
				fmt.Fprintf(out, "0x%08xU,", math.Float32bits(v))
			}
			fmt.Fprintln(out, "])")
		}
	}
	fmt.Fprintln(out, `}

///|
fn check_adjustable_arc_preset_path(name : String, width : Double, height : Double, adjustment : Int64?, extra : Map[String, Int64], verbs : Bytes, expected : Array[UInt32]) -> Unit raise {
  let path = sheet_adjustable_arc_preset_path(name, width, height, adjustment, extra~)
  assert_eq(path.verbs, verbs)
  assert_eq(path.coordinates.length(), expected.length())
  for i in 0..<expected.length() {
    assert_eq(Float::from_double(path.coordinates[i]).reinterpret_as_uint(), expected[i])
  }
}`)
}
