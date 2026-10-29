//go:build ignore

// Copy into upstream converter/font alongside generate_test.go.
package font

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexFeatureExamples(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	files := map[string][]byte{}
	cases := []any{}
	placed := func(ps []placed) []any {
		out := []any{}
		for _, p := range ps {
			out = append(out, map[string]any{"glyph": p.g, "x": p.x, "y": p.y})
		}
		return out
	}
	for _, name := range []string{"stix.ttf", "stix.otf", "features.ttf", "restricted.ttf", "variable.ttf", "bold.ttc"} {
		raw, err := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if err != nil {
			t.Fatal(err)
		}
		files[name] = packFixture(raw)
		for _, limit := range []int{0, 1, 5, 100} {
			fl, err := load(raw)
			if err != nil {
				t.Fatal(err)
			}
			for _, fc := range fl.faces {
				fc.prepare()
				c := &converter{fc: fc, examples: limit}
				groups := fc.featureGroups()
				examples := []any{}
				for index, g := range groups {
					if g.table != "GSUB" {
						continue
					}
					items, total := c.featureExamples(g)
					out := []any{}
					for _, it := range items {
						out = append(out, map[string]any{"before": placed(it.before), "after": placed(it.after), "beforeWidth": it.bw, "afterWidth": it.aw, "alternatives": it.alts, "boxes": it.boxes, "beforeAdvance": it.advB, "afterAdvance": it.advA, "offset": it.offset, "note": it.note})
					}
					examples = append(examples, map[string]any{"group": index, "items": out, "total": total})
				}
				cases = append(cases, map[string]any{"name": name, "index": fc.index, "limit": limit, "groups": examples})
			}
		}
	}
	data, err := json.Marshal(map[string]any{"files": files, "cases": cases})
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/specimen/feature-examples.json.gz"), packFixture(data), 0644); err != nil {
		t.Fatal(err)
	}
}
