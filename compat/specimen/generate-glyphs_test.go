//go:build ignore

// Copy into the upstream converter/font package with generate_test.go.
package font

import (
	"encoding/json"
	"github.com/shibukawa/bdf/internal/sfnt"
	"os"
	"path/filepath"
	"testing"
	"unicode"
)

func TestCodexGlyphs(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	results := []any{}
	add := func(name string, data []byte) {
		fl, e := load(data)
		if e != nil {
			t.Fatal(e)
		}
		for _, fc := range fl.faces {
			fc.prepare()
			glyphs := []any{}
			for g := 0; g < fc.f.NumGlyphs; g++ {
				cs := append([]rune{}, fc.chars[g]...)
				alt := ""
				if len(cs) > 0 && !unicode.IsControl(cs[0]) {
					alt = string(cs[0])
				}
				glyphs = append(glyphs, map[string]any{"name": fc.glyphs[g], "characters": cs, "label": charLabel(cs), "alternative": alt})
			}
			counts := []any{}
			for _, v := range fc.scriptCounts() {
				counts = append(counts, map[string]any{"name": v.name, "count": v.n})
			}
			results = append(results, map[string]any{"name": name, "index": fc.index, "input": packFixture(data), "glyphs": glyphs, "counts": counts})
		}
	}
	for _, name := range []string{"stix.ttf", "stix.otf", "features.ttf", "color.ttf", "bold.ttc"} {
		b, e := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if e != nil {
			t.Fatal(e)
		}
		add(name, b)
	}
	cm := map[uint32]uint16{}
	for _, rt := range unicode.Scripts {
		for _, r := range rt.R16 {
			cm[uint32(r.Lo)] = 1
			cm[uint32(r.Hi)] = 1
			cm[uint32(r.Lo)+uint32(r.Stride)] = 1
		}
		for _, r := range rt.R32 {
			cm[r.Lo] = 1
			cm[r.Hi] = 1
			cm[r.Lo+r.Stride] = 1
		}
	}
	for _, r := range []uint32{0, 0x1f, 0x7f, 0x9f, 0x37000, 0xd800, 0xe000, 0xffff, 0x10ffff} {
		cm[r] = 1
	}
	cm[0x1f600] = 6
	add("scripts-boundaries", sfnt.Build(map[string][]byte{"maxp": {0, 1, 0, 0, 0, 2}, "cmap": sfnt.BuildCmap(cm)}, false))
	add("empty", sfnt.Build(map[string][]byte{"maxp": {0, 1, 0, 0, 0, 2}}, false))
	b, e := json.Marshal(results)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/specimen/glyphs.json.gz"), packFixture(b), 0644); e != nil {
		t.Fatal(e)
	}
}
