//go:build ignore

// Copy into upstream converter/font alongside generate_test.go.
package font

import (
	"encoding/json"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
	"testing/fstest"

	"github.com/shibukawa/bdf"
	"github.com/shibukawa/bdf/converter/internal/canvas"
	"github.com/shibukawa/bdf/converter/internal/fontset"
	"github.com/shibukawa/bdf/internal/fontdb"
)

type codexCell struct {
	Glyph      int
	X, Y, W, H float64
	Alt        string
}

func TestCodexChartCells(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	files := map[string][]byte{}
	cases := []any{}
	rng := rand.New(rand.NewSource(338029))
	for _, name := range []string{"stix.ttf", "stix.otf", "features.ttf", "restricted.ttf", "variable.ttf", "bold.ttc"} {
		data, err := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if err != nil {
			t.Fatal(err)
		}
		files[name] = packFixture(data)
		fl, err := load(data)
		if err != nil {
			t.Fatal(err)
		}
		for _, fc := range fl.faces {
			fc.prepare()
			for mode := 0; mode < 2; mode++ {
				doc := bdf.NewDocument()
				set := fontset.New(fontdb.New(fstest.MapFS{}, nil, false), nil)
				builder := canvas.NewBuilder(doc, set)
				gf := bdf.EmbeddedFont(doc.AddFont([]byte("glyph")), 400, bdf.StyleNormal)
				paint := &painter{fc: fc}
				if mode == 0 {
					paint.glyphFont = &gf
				}
				c := &converter{fc: fc, paint: paint, ui: &texter{set: set}, cvs: builder}
				scroll := newScroll(c)
				cells := []codexCell{}
				for i := 0; i < 200; i++ {
					cell := codexCell{rng.Intn(fc.f.NumGlyphs), rng.Float64() * 500, rng.Float64() * 500, 5 + rng.Float64()*100, 5 + rng.Float64()*100, "Aあ"}
					cells = append(cells, cell)
				}
				scroll.add(700, func(p *pen, y float64) {
					for _, cell := range cells {
						c.cellGlyph(p, uint16(cell.Glyph), cell.X, cell.Y, cell.W, cell.H, cell.Alt)
					}
				})
				view := doc.NewView("cell", bdf.ViewScroll, "Cells")
				strips := scroll.finish(view)
				builder.Encode()
				cases = append(cases, map[string]any{"name": name, "index": fc.index, "outlined": mode != 0, "glyphHash": gf.Hash.String(), "height": float64(strips[0].page.H), "object": doc.Part(strips[0].cv.Hash()).Data, "cells": cells})
			}
		}
	}
	data, err := json.Marshal(map[string]any{"files": files, "cases": cases})
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/specimen/chart-cell.json.gz"), packFixture(data), 0644); err != nil {
		t.Fatal(err)
	}
}
