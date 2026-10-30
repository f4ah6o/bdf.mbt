//go:build ignore

// Copy into upstream converter/internal/ooxml/drawingml and run
// TestCodexLumReference with BDF_REFERENCE_OUTPUT set.
package drawingml

import (
	"fmt"
	"github.com/shibukawa/bdf/converter/internal/ooxml"
	"os"
	"testing"
)

func TestCodexLumReference(t *testing.T) {
	path := os.Getenv("BDF_REFERENCE_OUTPUT")
	if path == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	fmt.Fprintln(out, "///|\n// Generated using the upstream DrawingML color modifiers.\ntest \"luminance modifiers match Go\" {")
	for i := 0; i < 512; i++ {
		rgb := uint32((i*791917 + 12345) % (1 << 24))
		mod := (i * 7919) % 1000001
		off := (i*12347)%2000001 - 1000000
		second := (i * 31337) % 1000001
		n, err := ooxml.Parse([]byte(fmt.Sprintf(`<srgbClr val="%06X"><lumMod val="%d"/><lumOff val="%d"/><lumMod val="%d"/></srgbClr>`, rgb, mod, off, second)))
		if err != nil {
			t.Fatal(err)
		}
		got, ok := (&colorCtx{}).resolve(n)
		if !ok {
			t.Fatal("color resolution failed")
		}
		fmt.Fprintf(out, "  check_lum_modifiers(0x%06xU, %.17g, %.17g, %.17g, 0x%08xU)\n", rgb, float64(mod)/100000, float64(off)/100000, float64(second)/100000, uint32(got.bdf()))
	}
	fmt.Fprintln(out, `}

///|
fn check_lum_modifiers(rgb : UInt32, mod : Double, off : Double, second : Double, expected : UInt32) -> Unit raise {
  let color = xlsx_rgb_from_uint(rgb)
  let color = xlsx_shape_apply_lum(color, "lumMod", mod)
  let color = xlsx_shape_apply_lum(color, "lumOff", off)
  let color = xlsx_shape_apply_lum(color, "lumMod", second)
  assert_eq(xlsx_shape_pack_rgb(color, 255U), expected)
}`)
}
