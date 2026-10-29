//go:build ignore

// Copy into upstream converter/font alongside generate_test.go.
package font

import (
	"encoding/json"
	"fmt"
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

type codexPageBand struct {
	Space, Height        float64
	Keep                 bool
	Anchor, Target, Text string
	Bold                 bool
	Color                uint32
}

func TestCodexSpecimenPagePaint(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	raw, err := os.ReadFile(filepath.Join(root, "compat/font/fixtures/stix.ttf"))
	if err != nil {
		t.Fatal(err)
	}
	fl, err := load(raw)
	if err != nil {
		t.Fatal(err)
	}
	fc := fl.faces[0]
	fc.prepare()
	files := map[string][]byte{}
	for _, name := range []string{"stix.ttf", "stix.otf", "restricted.ttf"} {
		b, e := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if e != nil {
			t.Fatal(e)
		}
		files[name] = b
	}
	texts := []string{"Title", "日本語 sample", "ABC", "α β γ", "", "Text あ 한"}
	colors := []uint32{uint32(colText), uint32(colGray), uint32(colAccent)}
	rng := rand.New(rand.NewSource(182891))
	cases := []any{}
	for i := 0; i < 45; i++ {
		configs := [][]string{{}, {"stix.ttf"}, {"stix.otf"}, {"restricted.ttf"}}
		config := configs[i%len(configs)]
		fsys := fstest.MapFS{}
		for _, n := range config {
			fsys[n] = &fstest.MapFile{Data: files[n]}
		}
		doc := bdf.NewDocument()
		set := fontset.New(fontdb.New(fsys, nil, false), nil)
		builder := canvas.NewBuilder(doc, set)
		gf := bdf.EmbeddedFont(doc.AddFont([]byte("glyph")), 400, bdf.StyleNormal)
		sf := bdf.EmbeddedFont(doc.AddFont([]byte("sample")), 400, bdf.StyleNormal)
		c := &converter{fc: fc, paint: &painter{fc: fc, glyphFont: &gf, sampleFont: &sf}, ui: &texter{set: set}, cvs: builder}
		scroll := newScroll(c)
		bands := []codexPageBand{}
		for j := 0; j < 10+rng.Intn(32); j++ {
			band := codexPageBand{float64(rng.Intn(20)), float64(50 + rng.Intn(180)), rng.Intn(5) == 0, "", fmt.Sprintf("a%d", rng.Intn(5)), texts[rng.Intn(len(texts))], rng.Intn(2) == 0, colors[rng.Intn(len(colors))]}
			if j%6 == 0 {
				band.Anchor = fmt.Sprintf("a%d", j/6)
			}
			bands = append(bands, band)
			scroll.space(band.Space)
			if band.Anchor != "" {
				scroll.anchor(band.Anchor)
			}
			b := scroll.add(band.Height, func(p *pen, y float64) {
				p.rect(36, y+2, 200, 4, bdf.Color(band.Color))
				p.obj().Mark(bdf.MarkParagraph, "")
				p.label(band.Text, 36, y+18, 11, band.Bold, bdf.Color(band.Color), 0)
				p.linkTo(36, y, 30, 20, band.Target)
				p.obj().Save()
				p.obj().ClipRect(36, float32(y), 300, 30)
				p.sample("Aあ", 40, y+24, 12, false, "ja")
				p.obj().Restore()
				p.set, p.fset = false, false
				p.run([]uint16{1, 2}, []float64{0, fc.advances[1]}, 360, y+25, 13, "alt")
			})
			b.keep = band.Keep
		}
		v := doc.NewView("test", bdf.ViewScroll, "Test")
		strips := scroll.finish(v)
		system := i%2 == 0
		noSubset := i%3 == 0
		ignore := i%5 == 0
		if !system {
			set.Embed(doc, fontset.EmbedOptions{NoSubset: noSubset, NoWOFF2: true, IgnoreFSType: ignore})
		}
		builder.Encode()
		pages := []any{}
		for _, strip := range strips {
			pages = append(pages, map[string]any{"height": float64(strip.page.H), "object": doc.Part(strip.cv.Hash()).Data})
		}
		cases = append(cases, map[string]any{"fonts": append([]string{}, config...), "system": system, "noSubset": noSubset, "ignore": ignore, "glyphHash": gf.Hash.String(), "sampleHash": sf.Hash.String(), "advance": fc.advances[1], "bands": bands, "pages": pages})
	}
	packed := map[string][]byte{}
	for name, data := range files {
		packed[name] = packFixture(data)
	}
	data, err := json.Marshal(map[string]any{"files": packed, "face": packFixture(raw), "cases": cases})
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/specimen/page-paint.json.gz"), packFixture(data), 0644); err != nil {
		t.Fatal(err)
	}
}
