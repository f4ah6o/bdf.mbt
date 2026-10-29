//go:build ignore

// Copy into upstream converter/font alongside generate_test.go.
package font

import (
	"encoding/json"
	"math/rand"
	"os"
	"path/filepath"
	"testing"

	"github.com/shibukawa/bdf"
	"github.com/shibukawa/bdf/converter/internal/canvas"
)

type codexDraw struct {
	Glyphs     []uint16  `json:"glyphs"`
	Offsets    []float64 `json:"offsets"`
	X, Y, Size float64
	Alt        string
}

func TestCodexOutlinePainting(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	results := []any{}
	rng := rand.New(rand.NewSource(58654))
	for _, name := range []string{"stix.ttf", "stix.otf", "restricted.ttf", "bold.ttc", "features.ttf"} {
		raw, err := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if err != nil {
			t.Fatal(err)
		}
		fl, err := load(raw)
		if err != nil {
			t.Fatal(err)
		}
		for _, fc := range fl.faces {
			fc.prepare()
			cases := []any{}
			for i := 0; i < 80; i++ {
				events := []codexDraw{}
				for j := 0; j < 1+rng.Intn(5); j++ {
					n := rng.Intn(6)
					glyphs := []uint16{}
					offsets := []float64{}
					for k := 0; k < n; k++ {
						g := rng.Intn(fc.f.NumGlyphs + 4)
						if i%3 == 0 && k > 0 {
							g = int(glyphs[0])
						}
						glyphs = append(glyphs, uint16(g))
						offsets = append(offsets, float64(rng.Intn(200)-50)/64)
					}
					alt := ""
					if i%2 == 0 {
						alt = "Text 日本語"
					}
					events = append(events, codexDraw{glyphs, offsets, float64(rng.Intn(700)), float64(rng.Intn(900)), float64(8 + rng.Intn(90)), alt})
				}
				doc := bdf.NewDocument()
				cv := canvas.NewBuilder(doc, nil).New()
				cv.Obj.SetBBox(0, 0, 720, 1024)
				c := &converter{fc: fc, paint: &painter{fc: fc}}
				p := &pen{c: c, cv: cv}
				for _, e := range events {
					p.run(e.Glyphs, e.Offsets, e.X, e.Y, e.Size, e.Alt)
				}
				cases = append(cases, map[string]any{"events": events, "object": cv.Obj.Encode()})
			}
			results = append(results, map[string]any{"name": name, "input": packFixture(raw), "index": fc.index, "cases": cases})
		}
	}
	data, err := json.Marshal(results)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/specimen/paint.json.gz"), packFixture(data), 0644); err != nil {
		t.Fatal(err)
	}
}
