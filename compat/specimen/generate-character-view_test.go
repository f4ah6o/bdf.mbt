//go:build ignore

// Copy into upstream converter/font alongside generate_test.go.
package font

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"testing/fstest"

	"github.com/shibukawa/bdf"
	"github.com/shibukawa/bdf/converter/internal/canvas"
	"github.com/shibukawa/bdf/converter/internal/fontset"
	"github.com/shibukawa/bdf/internal/fontdb"
)

func TestCodexCharacterView(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	files := map[string][]byte{}
	for _, name := range []string{"stix.ttf", "stix.otf", "features.ttf", "restricted.ttf", "variable.ttf", "bold.ttc"} {
		data, err := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if err != nil {
			t.Fatal(err)
		}
		files[name] = data
	}
	cases := []any{}
	for _, name := range []string{"stix.ttf", "stix.otf", "features.ttf", "restricted.ttf", "variable.ttf", "bold.ttc"} {
		fl, err := load(files[name])
		if err != nil {
			t.Fatal(err)
		}
		for _, fc := range fl.faces {
			fc.prepare()
			for mode := 0; mode < 4; mode++ {
				system := mode&1 == 0
				outlined := mode&2 != 0
				fsys := fstest.MapFS{}
				if mode%3 != 0 {
					fsys["stix.ttf"] = &fstest.MapFile{Data: files["stix.ttf"]}
				}
				doc := bdf.NewDocument()
				set := fontset.New(fontdb.New(fsys, nil, false), nil)
				builder := canvas.NewBuilder(doc, set)
				gf := bdf.EmbeddedFont(doc.AddFont([]byte("glyph")), 400, bdf.StyleNormal)
				paint := &painter{fc: fc}
				if !outlined {
					paint.glyphFont = &gf
				}
				c := &converter{fc: fc, paint: paint, ui: &texter{set: set}, cvs: builder}
				scroll := newScroll(c)
				c.characters(scroll)
				view := doc.NewView("glyphs", bdf.ViewScroll, "Glyphs")
				strips := scroll.finish(view)
				if !system {
					set.Embed(doc, fontset.EmbedOptions{NoWOFF2: true})
				}
				builder.Encode()
				pages := []any{}
				for _, strip := range strips {
					pages = append(pages, map[string]any{"height": float64(strip.page.H), "object": doc.Part(strip.cv.Hash()).Data})
				}
				cases = append(cases, map[string]any{"name": name, "index": fc.index, "uiFont": mode%3 != 0, "system": system, "outlined": outlined, "glyphHash": gf.Hash.String(), "pages": pages})
			}
		}
	}
	packed := map[string][]byte{}
	for name, data := range files {
		packed[name] = packFixture(data)
	}
	data, err := json.Marshal(map[string]any{"files": packed, "cases": cases})
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/specimen/character-view.json.gz"), packFixture(data), 0644); err != nil {
		t.Fatal(err)
	}
}
