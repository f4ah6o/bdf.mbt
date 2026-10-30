//go:build ignore

// Copy into upstream converter/internal/ooxml/drawingml and run
// TestCodexHslLumReference with BDF_REFERENCE_OUTPUT set.
package drawingml

import (
	"fmt"
	"github.com/shibukawa/bdf/converter/internal/ooxml"
	"os"
	"testing"
)

func TestCodexHslLumReference(t *testing.T) {
	path := os.Getenv("BDF_REFERENCE_OUTPUT")
	if path == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	fmt.Fprintln(out, "///|\n// Generated using the upstream DrawingML color modifiers.\ntest \"HSL luminance and inversion match Go\" {")
	for i := 0; i < 512; i++ {
		hue := (i * 71993) % 21600001
		sat := (i * 12347) % 100001
		lum := (i * 32719) % 100001
		mod := (i * 7919) % 1000001
		off := (i*12347)%2000001 - 1000000
		n, err := ooxml.Parse([]byte(fmt.Sprintf(`<hslClr hue="%d" sat="%d" lum="%d"><inv/><lumMod val="%d"/><inv/><lumOff val="%d"/></hslClr>`, hue, sat, lum, mod, off)))
		if err != nil {
			t.Fatal(err)
		}
		got, ok := (&colorCtx{}).resolve(n)
		if !ok {
			t.Fatal("color resolution failed")
		}
		fmt.Fprintf(out, "  check_hsl_lum(%.17g, %.17g, %.17g, %.17g, %.17g, 0x%08xU)\n", float64(hue)/60000/360, float64(sat)/100000, float64(lum)/100000, float64(mod)/100000, float64(off)/100000, uint32(got.bdf()))
	}
	fmt.Fprintln(out, `}

///|
fn check_hsl_lum(hue : Double, sat : Double, lum : Double, mod : Double, off : Double, expected : UInt32) -> Unit raise {
  let color = xlsx_shape_hsl_rgb(hue, sat, lum)
  let color = { red: 1.0 - color.red, green: 1.0 - color.green, blue: 1.0 - color.blue }
  let color = xlsx_shape_apply_hsl_modifier(color, "lumMod", mod)
  let color = { red: 1.0 - color.red, green: 1.0 - color.green, blue: 1.0 - color.blue }
  let color = xlsx_shape_apply_hsl_modifier(color, "lumOff", off)
  assert_eq(xlsx_shape_pack_rgb(color, 255U), expected)
}`)
}
