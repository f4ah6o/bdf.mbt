//go:build ignore

// Copy into upstream internal/sfnt and run TestCodexOutlines.
package sfnt

import (
	"bytes"
	"compress/gzip"
	"encoding/binary"
	"encoding/json"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

type codexOutlinePen struct{ cmds [][]any }

func (p *codexOutlinePen) MoveTo(x, y float64)       { p.cmds = append(p.cmds, []any{"M", x, y}) }
func (p *codexOutlinePen) LineTo(x, y float64)       { p.cmds = append(p.cmds, []any{"L", x, y}) }
func (p *codexOutlinePen) QuadTo(a, b, c, d float64) { p.cmds = append(p.cmds, []any{"Q", a, b, c, d}) }
func (p *codexOutlinePen) CubeTo(a, b, c, d, e, f float64) {
	p.cmds = append(p.cmds, []any{"C", a, b, c, d, e, f})
}
func (p *codexOutlinePen) Close() { p.cmds = append(p.cmds, []any{"Z"}) }
func codexOutlinePack(raw []byte) []byte {
	var b bytes.Buffer
	w := gzip.NewWriter(&b)
	if _, err := w.Write(raw); err != nil {
		panic(err)
	}
	if err := w.Close(); err != nil {
		panic(err)
	}
	return b.Bytes()
}
func TestCodexOutlines(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	results := []any{}
	add := func(name string, raw []byte, index int, glyphs []int) {
		f, err := ParseIndex(raw, index)
		if err != nil {
			t.Fatal(name, err)
		}
		o := NewOutlines(f)
		if glyphs == nil {
			for g := 0; g < f.NumGlyphs; g++ {
				glyphs = append(glyphs, g)
			}
		}
		cases := []any{}
		for _, g := range glyphs {
			p := &codexOutlinePen{cmds: [][]any{}}
			ok := o.Outline(uint16(g), p)
			cases = append(cases, map[string]any{"glyph": g, "ok": ok, "commands": p.cmds})
		}
		results = append(results, map[string]any{"name": name, "input": codexOutlinePack(raw), "index": index, "cases": cases})
	}
	for _, name := range []string{"stix.ttf", "variable.ttf", "color.ttf", "features.ttf", "restricted.ttf"} {
		raw, err := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if err != nil {
			t.Fatal(err)
		}
		add(name, raw, 0, nil)
	}
	ttc, err := os.ReadFile(filepath.Join(root, "compat/font/fixtures/bold.ttc"))
	if err != nil {
		t.Fatal(err)
	}
	add("ttc-0", ttc, 0, nil)
	add("ttc-1", ttc, 1, nil)
	raw, err := os.ReadFile(filepath.Join(root, "compat/font/fixtures/stix.ttf"))
	if err != nil {
		t.Fatal(err)
	}
	base, err := Parse(raw)
	if err != nil {
		t.Fatal(err)
	}
	rng := rand.New(rand.NewSource(12389))
	for n := 0; n < 25; n++ {
		tables := map[string][]byte{}
		for k, v := range base.Tables {
			tables[k] = v
		}
		g := append([]byte(nil), tables["glyf"]...)
		for j := 0; j < 1+rng.Intn(15); j++ {
			g[rng.Intn(len(g))] = byte(rng.Intn(256))
		}
		tables["glyf"] = g
		if n%5 == 0 {
			l := append([]byte(nil), tables["loca"]...)
			for j := 0; j < 3; j++ {
				l[rng.Intn(len(l))] = byte(rng.Intn(256))
			}
			tables["loca"] = l
		}
		ids := []int{0, 1, 2, 3, 4, 5, 20, 50, 100}
		for j := 0; j < 10; j++ {
			ids = append(ids, rng.Intn(base.NumGlyphs))
		}
		add("mutation", Build(tables, false), 0, ids)
	}
	// Two-point all-off-curve contour and a self-referencing composite.
	head := make([]byte, 54)
	binary.BigEndian.PutUint16(head[18:], 1000)
	simple := []byte{0, 1, 0, 0, 0, 0, 0, 10, 0, 10, 0, 1, 0, 0, 0x36, 0x36, 0, 10, 0, 10}
	composite := []byte{0xff, 0xff, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 1, 0, 0}
	glyf := append(simple, composite...)
	loca := make([]byte, 8)
	binary.BigEndian.PutUint16(loca[2:], uint16(len(simple)/2))
	binary.BigEndian.PutUint16(loca[4:], uint16(len(glyf)/2))
	binary.BigEndian.PutUint16(loca[6:], uint16(len(glyf)/2))
	add("synthetic", Build(map[string][]byte{"head": head, "maxp": {0, 1, 0, 0, 0, 3}, "loca": loca, "glyf": glyf}, false), 0, nil)
	// Mutate every part of short glyphs to exercise flag runs, truncation,
	// signed deltas, component transforms, recursion and partial output.
	for n := 0; n < 250; n++ {
		g := append([]byte(nil), glyf...)
		for j := 0; j < 1+rng.Intn(5); j++ {
			g[rng.Intn(len(g))] = byte(rng.Intn(256))
		}
		if n%7 == 0 {
			g = g[:rng.Intn(len(g)+1)]
		}
		add("synthetic-mutation", Build(map[string][]byte{"head": head, "maxp": {0, 1, 0, 0, 0, 3}, "loca": loca, "glyf": g}, false), 0, nil)
	}
	// Two transformed references to the first glyph, then a truncated component.
	component := []byte{0xff, 0xff, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x2a, 0, 0, 12, 0xff, 0x20, 0x00, 0, 0x82, 0, 0, 1, 2, 0x40, 0, 0x20, 0, 0xe0, 0, 0x40, 0}
	all := append(append([]byte(nil), simple...), component...)
	newloca := append([]byte(nil), loca...)
	binary.BigEndian.PutUint16(newloca[4:], uint16(len(all)/2))
	binary.BigEndian.PutUint16(newloca[6:], uint16(len(all)/2))
	add("transforms", Build(map[string][]byte{"head": head, "maxp": {0, 1, 0, 0, 0, 3}, "loca": newloca, "glyf": all}, false), 0, nil)

	output, err := json.Marshal(results)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/font/outlines.json.gz"), codexOutlinePack(output), 0644); err != nil {
		t.Fatal(err)
	}
}
