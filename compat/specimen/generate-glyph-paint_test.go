//go:build ignore

// Copy into upstream converter/font alongside generate_test.go and generate-paint_test.go.
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

func TestCodexGlyphPainting(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	rng := rand.New(rand.NewSource(519328))
	results := []any{}
	for _, name := range []string{"stix.ttf", "stix.otf", "features.ttf", "bold.ttc"} {
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
			for i := 0; i < 100; i++ {
				events := []codexDraw{}
				for j := 0; j < 1+rng.Intn(5); j++ {
					n := rng.Intn(7)
					gs := []uint16{}
					dx := []float64{}
					adv := 0.0
					for k := 0; k < n; k++ {
						glyph := 1 + rng.Intn(fc.f.NumGlyphs-1)
						if i%11 == 0 && k == 0 {
							glyph = 0
						}
						gs = append(gs, uint16(glyph))
						off := adv
						if i%4 == 1 {
							off += float64(k) / 2
						}
						if i%4 == 2 {
							off += 0.0000011
						}
						if i%4 == 3 {
							off += 0.0000009
						}
						dx = append(dx, off)
						adv += fc.advances[glyph]
					}
					alt := ""
					if i%2 == 0 {
						alt = "Accessible テキスト"
					}
					events = append(events, codexDraw{gs, dx, float64(rng.Intn(700)), float64(rng.Intn(900)), float64(8 + rng.Intn(90)), alt})
				}
				doc := bdf.NewDocument()
				cv := canvas.NewBuilder(doc, nil).New()
				cv.Obj.SetBBox(0, 0, 720, 1024)
				glyphFont := bdf.EmbeddedFont(bdf.Hash{}, 400, bdf.StyleNormal)
				c := &converter{fc: fc, paint: &painter{fc: fc, glyphFont: &glyphFont}}
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
	if err = os.WriteFile(filepath.Join(root, "compat/specimen/glyph-paint.json.gz"), packFixture(data), 0644); err != nil {
		t.Fatal(err)
	}
}
