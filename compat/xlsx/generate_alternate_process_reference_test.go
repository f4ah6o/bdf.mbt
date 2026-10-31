//go:build ignore

// Copy into upstream converter/internal/ooxml/drawingml and run
// TestCodexAlternateProcessReference with BDF_REFERENCE_OUTPUT set.
package drawingml

import (
	"fmt"
	"math"
	"os"
	"testing"
)

func TestCodexAlternateProcessReference(t *testing.T) {
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dest == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(dest)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	fmt.Fprintln(out, "///|\n// Generated from upstream DrawingML alternate-process geometry.\ntest \"alternate process paths match Go\" {")
	def := loadPresets()["flowChartAlternateProcess"]
	for i := 0; i < 512; i++ {
		w := float64((i*7919879)%254000000) / 12700
		h := float64((i*916177)%254000000) / 12700
		if i == 0 {
			w = 0
		}
		if i == 1 {
			h = 0
		}
		path := evalGeometry(def, nil, w, h).paths[0].path
		fmt.Fprintf(out, "  check_alternate_process_path(%.17g, %.17g, b%q, [", w, h, string(path.Verbs))
		for _, v := range path.Args {
			fmt.Fprintf(out, "0x%08xU,", math.Float32bits(v))
		}
		fmt.Fprintln(out, "])")
	}
	fmt.Fprintln(out, `}

///|
fn check_alternate_process_path(width : Double, height : Double, verbs : Bytes, expected : Array[UInt32]) -> Unit raise {
  let path = sheet_rounded_preset_path(width, height, Double::min(width, height) / 6.0)
  assert_eq(path.verbs, verbs)
  assert_eq(path.coordinates.length(), expected.length())
  for i in 0..<expected.length() {
    assert_eq(Float::from_double(path.coordinates[i]).reinterpret_as_uint(), expected[i])
  }
}`)
}
