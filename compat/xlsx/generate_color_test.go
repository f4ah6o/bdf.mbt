//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexXLSXColor.
package xlsx

import (
	"encoding/json"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexXLSXColor(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	st := &styles{palette: defaultPalette, themeColor: func(name string) (rgb, bool) {
		for i, n := range themeNames {
			if n == name && i != 3 {
				return rgb{float64(i) / 12, 0.5, 1 - float64(i)/12}, true
			}
		}
		return rgb{}, false
	}}
	r := rand.New(rand.NewSource(492104))
	out := []any{}
	for i := 0; i < 20000; i++ {
		kind := r.Intn(6)
		index := r.Intn(100) - 10
		raw := r.Uint32() & 0xffffff
		tint := []float64{0, -1, -0.5, 0.1, 0.5, 1, 1.5, -2}[r.Intn(8)]
		c := colorRef{kind: byte(kind), rgb: hexRGB(raw), idx: index, tint: tint}
		def := rgb{0.1, 0.2, 0.3}
		v := st.color(c, def)
		out = append(out, map[string]any{"kind": kind, "rgb": raw, "index": index, "tint": tint, "want": []any{v.R, v.G, v.B, uint32(v.bdf())}})
	}
	b, e := json.Marshal(out)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/color.json"), b, 0644); e != nil {
		t.Fatal(e)
	}
}
