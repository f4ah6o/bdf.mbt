//go:build ignore

// Copy into upstream converter/internal/ooxml/drawingml and run
// TestCodexChannelReference with BDF_REFERENCE_OUTPUT set.
package drawingml

import (
	"fmt"
	"github.com/shibukawa/bdf/converter/internal/ooxml"
	"os"
	"testing"
)

func TestCodexChannelReference(t *testing.T) {
	path := os.Getenv("BDF_REFERENCE_OUTPUT")
	if path == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	fmt.Fprintln(out, "///|\n// Generated using the upstream DrawingML color modifiers.\ntest \"channel, complement and gray modifiers match Go\" {")
	channels := []string{"red", "green", "blue"}
	for i := 0; i < 1024; i++ {
		rgb := uint32((i*791917 + 12345) % (1 << 24))
		mod := (i * 7919) % 1000001
		off := (i*12347)%2000001 - 1000000
		val := (i * 32719) % 100001
		first, second, third := channels[i%3], channels[(i+1)%3]+"Mod", channels[(i+2)%3]+"Off"
		n, err := ooxml.Parse([]byte(fmt.Sprintf(`<srgbClr val="%06X"><%s val="%d"/><%s val="%d"/><%s val="%d"/><comp/></srgbClr>`, rgb, first, val, second, mod, third, off)))
		if err != nil {
			t.Fatal(err)
		}
		got, ok := (&colorCtx{}).resolve(n)
		if !ok {
			t.Fatal("color resolution failed")
		}
		fmt.Fprintf(out, "  check_channels(0x%06xU, %q, %.17g, %q, %.17g, %q, %.17g, 0x%08xU)\n", rgb, first, float64(val)/100000, second, float64(mod)/100000, third, float64(off)/100000, uint32(got.bdf()))
		n, err = ooxml.Parse([]byte(fmt.Sprintf(`<srgbClr val="%06X"><lumMod val="%d"/><gray/></srgbClr>`, rgb, mod)))
		if err != nil {
			t.Fatal(err)
		}
		got, ok = (&colorCtx{}).resolve(n)
		if !ok {
			t.Fatal("color resolution failed")
		}
		fmt.Fprintf(out, "  check_gray_modifier(0x%06xU, %.17g, 0x%08xU)\n", rgb, float64(mod)/100000, uint32(got.bdf()))
	}
	fmt.Fprintln(out, `}

///|
fn check_channels(rgb : UInt32, a : String, av : Double, b : String, bv : Double, c : String, cv : Double, expected : UInt32) -> Unit raise {
  let color = xlsx_rgb_from_uint(rgb)
  let color = xlsx_shape_apply_channel(color, a, av)
  let color = xlsx_shape_apply_channel(color, b, bv)
  let color = xlsx_shape_apply_channel(color, c, cv)
  let color = xlsx_shape_apply_hsl_modifier(color, "hueOff", 0.5)
  assert_eq(xlsx_shape_pack_rgb(color, 255U), expected)
}

///|
fn check_gray_modifier(rgb : UInt32, mod : Double, expected : UInt32) -> Unit raise {
  let color = xlsx_rgb_from_uint(rgb)
  let color = xlsx_shape_apply_hsl_modifier(color, "lumMod", mod)
  let color = xlsx_shape_gray(color)
  assert_eq(xlsx_shape_pack_rgb(color, 255U), expected)
}`)
}
