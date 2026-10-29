//go:build ignore

// Copy into the upstream converter/font package with generate_test.go.
package font

import (
	"encoding/json"
	"github.com/shibukawa/bdf/internal/sfnt"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexCoverage(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	results := []any{}
	add := func(name string, data []byte) {
		fl, err := load(data)
		if err != nil {
			t.Fatal(err)
		}
		for _, fc := range fl.faces {
			fc.prepare()
			output := []any{}
			for _, v := range fc.coverage() {
				output = append(output, map[string]any{"first": v.first, "last": v.last, "name": v.name, "assigned": v.assigned, "mapped": v.mapped})
			}
			results = append(results, map[string]any{"name": name, "input": packFixture(data), "index": fc.index, "coverage": output})
		}
	}
	for _, name := range []string{"stix.ttf", "stix.otf", "features.ttf", "variable.ttf", "color.ttf", "bold.ttc"} {
		b, err := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if err != nil {
			t.Fatal(err)
		}
		add(name, b)
	}
	cm := map[uint32]uint16{}
	for _, b := range blocks {
		cm[uint32(b.first)] = 1
		cm[uint32(b.last)] = 1
	}
	// Values between Unicode blocks and a glyph beyond maxp's range.
	for _, r := range []rune{0x2fe0, 0x323b0 - 1, 0x40000, 0xeffff} {
		cm[uint32(r)] = 1
	}
	cm[0x1f600] = 7
	add("all-block-boundaries", sfnt.Build(map[string][]byte{"maxp": {0, 1, 0, 0, 0, 2}, "cmap": sfnt.BuildCmap(cm)}, false))
	add("empty", sfnt.Build(map[string][]byte{"maxp": {0, 1, 0, 0, 0, 2}}, false))
	b, err := json.Marshal(results)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/specimen/coverage.json.gz"), packFixture(b), 0644); err != nil {
		t.Fatal(err)
	}
}
