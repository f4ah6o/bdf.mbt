//go:build ignore

// Copy into upstream converter/internal/ooxml/drawingml and run
// TestCodexHueReference with BDF_REFERENCE_OUTPUT set.
package drawingml

import (
	"fmt"
	"github.com/shibukawa/bdf/converter/internal/ooxml"
	"os"
	"testing"
)

func TestCodexHueReference(t *testing.T) {
	path := os.Getenv("BDF_REFERENCE_OUTPUT")
	if path == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	fmt.Fprintln(out, "///|\n// Generated using the upstream DrawingML color modifiers.\ntest \"hue modifiers match Go\" {")
	for i := 0; i < 512; i++ {
		rgb := uint32((i*791917 + 12345) % (1 << 24))
		mod := (i * 7919) % 1000001
		off := (i*123477)%43200001 - 21600000
		n, err := ooxml.Parse([]byte(fmt.Sprintf(`<srgbClr val="%06X"><hueMod val="%d"/><hueOff val="%d"/></srgbClr>`, rgb, mod, off)))
		if err != nil {
			t.Fatal(err)
		}
		got, ok := (&colorCtx{}).resolve(n)
		if !ok {
			t.Fatal("color resolution failed")
		}
		fmt.Fprintf(out, "  check_hue_modifiers(0x%06xU, %.17g, %.17g, 0x%08xU)\n", rgb, float64(mod)/100000, float64(off)/60000/360, uint32(got.bdf()))
		hue := (i * 71993) % 21600001
		n, err = ooxml.Parse([]byte(fmt.Sprintf(`<srgbClr val="%06X"><hue val="%d"/></srgbClr>`, rgb, hue)))
		if err != nil {
			t.Fatal(err)
		}
		got, ok = (&colorCtx{}).resolve(n)
		if !ok {
			t.Fatal("color resolution failed")
		}
		fmt.Fprintf(out, "  check_absolute_hue(0x%06xU, %.17g, 0x%08xU)\n", rgb, float64(hue)/60000/360, uint32(got.bdf()))
	}
	fmt.Fprintln(out, `}

///|
fn check_hue_modifiers(rgb : UInt32, mod : Double, off : Double, expected : UInt32) -> Unit raise {
  let color = xlsx_rgb_from_uint(rgb)
  let color = xlsx_shape_apply_hsl_modifier(color, "hueMod", mod)
  let color = xlsx_shape_apply_hsl_modifier(color, "hueOff", off)
  assert_eq(xlsx_shape_pack_rgb(color, 255U), expected)
}

///|
fn check_absolute_hue(rgb : UInt32, hue : Double, expected : UInt32) -> Unit raise {
  let color = xlsx_rgb_from_uint(rgb)
  let color = xlsx_shape_apply_hsl_modifier(color, "hue", hue)
  assert_eq(xlsx_shape_pack_rgb(color, 255U), expected)
}`)
}
