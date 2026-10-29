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

type codexLabel struct {
	Text       string
	X, Y, Size float64
	Bold       bool
	Color      uint32
	Align      int
}

func TestCodexSpecimenUIPaint(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	fontRaw, err := os.ReadFile(filepath.Join(root, "compat/font/fixtures/stix.ttf"))
	if err != nil {
		t.Fatal(err)
	}
	fl, err := load(fontRaw)
	if err != nil {
		t.Fatal(err)
	}
	fc := fl.faces[0]
	fc.prepare()
	files := map[string][]byte{}
	for _, name := range []string{"stix.ttf", "stix.otf", "restricted.ttf", "bold.ttc"} {
		b, e := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if e != nil {
			t.Fatal(e)
		}
		files[name] = b
	}
	texts := []string{"", "Arial heading", "A漢B あ 한", "α β γ", "é😀", "first line", "100%", "X ſẞİ"}
	colors := []uint32{uint32(colText), uint32(colGray), uint32(colAccent), uint32(colMissing)}
	rng := rand.New(rand.NewSource(28365))
	results := []any{}
	for _, config := range [][]string{{}, {"stix.ttf"}, {"stix.otf"}, {"restricted.ttf"}, {"bold.ttc", "stix.ttf"}} {
		for i := 0; i < 35; i++ {
			events := []codexLabel{}
			for j := 0; j < 1+rng.Intn(8); j++ {
				events = append(events, codexLabel{texts[rng.Intn(len(texts))], float64(rng.Intn(700)), float64(rng.Intn(900)), float64(8 + rng.Intn(30)), rng.Intn(2) == 0, colors[rng.Intn(len(colors))], rng.Intn(3)})
			}
			system := i%2 == 0
			noSubset := i%3 == 0
			ignore := i%5 == 0
			lang := ""
			if i%2 == 0 {
				lang = "ja-JP"
			}
			doc := bdf.NewDocument()
			if lang != "" {
				doc.Meta.DC.Language = bdf.DCValues{lang}
			}
			fsys := fstest.MapFS{}
			for _, name := range config {
				fsys[name] = &fstest.MapFile{Data: files[name]}
			}
			set := fontset.New(fontdb.New(fsys, nil, false), nil)
			builder := canvas.NewBuilder(doc, set)
			cv := builder.New()
			cv.Obj.SetBBox(0, 0, 720, 1024)
			glyph := bdf.EmbeddedFont(doc.AddFont([]byte("glyph")), 400, bdf.StyleNormal)
			sample := bdf.EmbeddedFont(doc.AddFont([]byte("sample")), 400, bdf.StyleNormal)
			paint := &painter{fc: fc, glyphFont: &glyph, sampleFont: &sample}
			c := &converter{fc: fc, paint: paint, ui: &texter{set: set}}
			p := &pen{c: c, cv: cv}
			// Switch among UI text, shaped sample text and glyph text to test shared state.
			for j, e := range events {
				p.label(e.Text, e.X, e.Y, e.Size, e.Bold, bdf.Color(e.Color), e.Align)
				if j%2 == 0 {
					p.sample("Sample あ", 200, 300, 18, j%4 == 0, "ja")
				}
				if j%3 == 0 {
					p.run([]uint16{1, 2}, []float64{0, fc.advances[1]}, 100, 130, 16, "alt")
				}
			}
			if !system {
				set.Embed(doc, fontset.EmbedOptions{NoSubset: noSubset, NoWOFF2: true, IgnoreFSType: ignore})
			}
			builder.Encode()
			object := doc.Part(cv.Hash()).Data
			results = append(results, map[string]any{"fonts": append([]string{}, config...), "system": system, "noSubset": noSubset, "ignore": ignore, "docLanguage": lang, "glyphHash": glyph.Hash.String(), "sampleHash": sample.Hash.String(), "events": events, "advance": fc.advances[1], "object": object})
		}
	}
	packed := map[string][]byte{}
	for name, data := range files {
		packed[name] = packFixture(data)
	}
	output, err := json.Marshal(map[string]any{"files": packed, "face": packFixture(fontRaw), "cases": results})
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/specimen/ui-paint.json.gz"), packFixture(output), 0644); err != nil {
		t.Fatal(err)
	}
}
