//go:build ignore

// Copy into upstream converter/internal/ooxml/drawingml and run
// TestCodexSatReference with BDF_REFERENCE_OUTPUT set.
package drawingml

import (
	"fmt"
	"github.com/shibukawa/bdf/converter/internal/ooxml"
	"os"
	"testing"
)

func TestCodexSatReference(t *testing.T) {
	path := os.Getenv("BDF_REFERENCE_OUTPUT")
	if path == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	fmt.Fprintln(out, "///|\n// Generated using the upstream DrawingML color modifiers.\ntest \"saturation modifiers match Go\" {")
	for i := 0; i < 512; i++ {
		rgb := uint32((i*791917 + 12345) % (1 << 24))
		mod := (i * 7919) % 1000001
		off := (i*12347)%2000001 - 1000000
		n, err := ooxml.Parse([]byte(fmt.Sprintf(`<srgbClr val="%06X"><satMod val="%d"/><satOff val="%d"/></srgbClr>`, rgb, mod, off)))
		if err != nil {
			t.Fatal(err)
		}
		got, ok := (&colorCtx{}).resolve(n)
		if !ok {
			t.Fatal("color resolution failed")
		}
		fmt.Fprintf(out, "  check_sat_modifiers(0x%06xU, %.17g, %.17g, 0x%08xU)\n", rgb, float64(mod)/100000, float64(off)/100000, uint32(got.bdf()))
		sat := (i * 32719) % 100001
		lum := (i * 37199) % 100001
		n, err = ooxml.Parse([]byte(fmt.Sprintf(`<srgbClr val="%06X"><sat val="%d"/><lum val="%d"/></srgbClr>`, rgb, sat, lum)))
		if err != nil {
			t.Fatal(err)
		}
		got, ok = (&colorCtx{}).resolve(n)
		if !ok {
			t.Fatal("color resolution failed")
		}
		fmt.Fprintf(out, "  check_absolute_hsl(0x%06xU, %.17g, %.17g, 0x%08xU)\n", rgb, float64(sat)/100000, float64(lum)/100000, uint32(got.bdf()))
	}
	fmt.Fprintln(out, `}

///|
fn check_sat_modifiers(rgb : UInt32, mod : Double, off : Double, expected : UInt32) -> Unit raise {
  let color = xlsx_rgb_from_uint(rgb)
  let color = xlsx_shape_apply_hsl_modifier(color, "satMod", mod)
  let color = xlsx_shape_apply_hsl_modifier(color, "satOff", off)
  assert_eq(xlsx_shape_pack_rgb(color, 255U), expected)
}

///|
fn check_absolute_hsl(rgb : UInt32, sat : Double, lum : Double, expected : UInt32) -> Unit raise {
  let color = xlsx_rgb_from_uint(rgb)
  let color = xlsx_shape_apply_hsl_modifier(color, "sat", sat)
  let color = xlsx_shape_apply_hsl_modifier(color, "lum", lum)
  assert_eq(xlsx_shape_pack_rgb(color, 255U), expected)
}`)
}
