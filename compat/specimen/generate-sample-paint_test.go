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

type codexSample struct {
	Text       string
	X, Y, Size float64
	Rtl        bool
	Lang       string
}

func TestCodexSamplePainting(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	rng := rand.New(rand.NewSource(152231))
	results := []any{}
	texts := []string{"", "ABC", "fi ffi", "日本語", "مرحبا", "x y", "A😀B", "\u0301", "BDF"}
	langs := []string{"", "en", "ja", "ja-JP", "ar", " x-none ", "fr", " JA ", "zh-Hant", "ſ", "S", "K", "İ", "ẞ", "ß", "X-NONE", "😀"}
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
				events := []codexSample{}
				for j := 0; j < 1+rng.Intn(6); j++ {
					events = append(events, codexSample{texts[rng.Intn(len(texts))], float64(rng.Intn(600)), float64(rng.Intn(900)), float64(8 + rng.Intn(72)), rng.Intn(2) == 0, langs[rng.Intn(len(langs))]})
				}
				mode := i % 5
				docs := []string{"", "ja-JP", "s-Latn", "S", "k-KR", "i", "ẞ-DE", "😀-foo"}
				docLang := docs[i%len(docs)]
				doc := bdf.NewDocument()
				if docLang != "" {
					doc.Meta.DC.Language = bdf.DCValues{docLang}
				}
				cv := canvas.NewBuilder(doc, nil).New()
				cv.Obj.SetBBox(0, 0, 720, 1024)
				gf := bdf.EmbeddedFont(bdf.Hash{}, 400, bdf.StyleNormal)
				sf := bdf.EmbeddedFont(bdf.Hash{1}, 400, bdf.StyleNormal)
				if mode == 4 {
					sf = gf
				}
				paint := &painter{fc: fc}
				if mode == 1 || mode >= 3 {
					paint.glyphFont = &gf
				}
				if mode >= 2 {
					paint.sampleFont = &sf
				}
				c := &converter{fc: fc, paint: paint}
				p := &pen{c: c, cv: cv}
				glyphs := []uint16{1, 2}
				offsets := []float64{0, fc.advances[1]}
				pre := i%2 == 0
				post := i%3 == 0
				if pre {
					p.run(glyphs, offsets, 10, 20, 16, "pre")
				}
				for _, e := range events {
					p.sample(e.Text, e.X, e.Y, e.Size, e.Rtl, e.Lang)
				}
				if post {
					p.run(glyphs, offsets, 30, 40, 16, "post")
				}
				cases = append(cases, map[string]any{"events": events, "mode": mode, "docLanguage": docLang, "pre": pre, "post": post, "advance": fc.advances[1], "object": cv.Obj.Encode()})
			}
			results = append(results, map[string]any{"name": name, "input": packFixture(raw), "index": fc.index, "cases": cases})
		}
	}
	data, err := json.Marshal(results)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/specimen/sample-paint.json.gz"), packFixture(data), 0644); err != nil {
		t.Fatal(err)
	}
}
