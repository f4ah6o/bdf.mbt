//go:build ignore

// Copy into upstream converter/internal/music and run TestCodexMusicPrimitives.
package music

import (
	"encoding/json"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexMusicPrimitives(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	r := rand.New(rand.NewSource(272312))
	randnum := func() float64 { return float64(r.Intn(400)-200) / 10 }
	curves := []any{}
	for i := 0; i < 3000; i++ {
		v := make([]float64, 7)
		for j := range v {
			v[j] = randnum()
		}
		o := curve(v[0], v[1], v[2], v[3], v[4], v[5], v[6])
		a, b, c, d := o.bounds()
		verbs := []int{}
		for _, verb := range o.verbs {
			verbs = append(verbs, int(verb))
		}
		curves = append(curves, map[string]any{"input": v, "want": map[string]any{"verbs": verbs, "coordinates": o.args, "bounds": [4]float64{a, b, c, d}}})
	}
	drawings := []any{}
	names := []string{"gClef", "noteheadBlack", "accidentalSharp", "restQuarter"}
	for i := 0; i < 1000; i++ {
		d := newDrawing()
		ops := []float64{}
		for j := 0; j < 1+r.Intn(15); j++ {
			v := make([]float64, 9)
			v[0] = float64(r.Intn(4))
			for k := 1; k < 9; k++ {
				v[k] = randnum()
			}
			switch int(v[0]) {
			case 0:
				d.rect(v[1], v[2], v[3], v[4])
			case 1:
				v[5] = float64(r.Intn(30)) / 10
				d.line(v[1], v[2], v[3], v[4], v[5], v[6])
			case 2:
				v[1] = float64(r.Intn(len(names)))
				v[4] = float64(1+r.Intn(30)) / 10
				d.glyph(sym(names[int(v[1])]), v[2], v[3], v[4])
			case 3:
				d.fill(quad(v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8]))
			}
			ops = append(ops, v...)
		}
		prims := []any{}
		for _, p := range d.prims {
			name := ""
			if p.g != nil {
				name = p.g.name
			}
			prims = append(prims, []any{int(p.kind), name, p.x, p.y, p.w, p.h, p.scale, p.width, p.dash})
		}
		qs := []float64{}
		sky := []float64{}
		for j := 0; j < 5; j++ {
			a, b, base := randnum(), randnum(), randnum()
			above := r.Intn(2)
			qs = append(qs, a, b, base, float64(above))
			if above == 1 {
				sky = append(sky, d.top.at(a, b, base))
			} else {
				sky = append(sky, d.bot.at(a, b, base))
			}
		}
		drawings = append(drawings, map[string]any{"ops": ops, "queries": qs, "want": map[string]any{"primitives": prims, "skylines": sky}})
	}
	out, err := json.Marshal(map[string]any{"curves": curves, "drawings": drawings})
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/musicnotation/primitives.json"), out, 0644); err != nil {
		t.Fatal(err)
	}
}
