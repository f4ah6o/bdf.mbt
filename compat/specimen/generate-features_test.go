//go:build ignore

// Copy into upstream converter/font alongside generate_test.go.
package font

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"testing"

	"github.com/shibukawa/bdf/internal/otlayout"
	"github.com/shibukawa/bdf/internal/sfnt"
)

func TestCodexFeatureGroups(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	results := []any{}
	add := func(name string, data []byte) {
		fl, err := load(data)
		if err != nil {
			t.Fatal(name, err)
		}
		for _, fc := range fl.faces {
			fc.prepare()
			groups := []any{}
			for _, g := range fc.featureGroups() {
				displayName := g.uiName
				if displayName == "" {
					displayName = otlayout.FeatureName(g.tag)
				}
				groups = append(groups, map[string]any{"table": g.table, "tag": g.tag, "lookups": append([]int{}, g.lookups...), "scripts": append([]string{}, g.scripts...), "uiName": g.uiName, "displayName": displayName, "scriptList": scriptList(g.scripts), "scriptTags": scriptTags(g.scripts), "defaultNote": defaultNote(g.tag), "characters": append([]rune{}, g.chars...)})
			}
			results = append(results, map[string]any{"name": name, "input": packFixture(data), "index": fc.index, "groups": groups})
		}
	}
	for _, name := range []string{"stix.ttf", "stix.otf", "features.ttf", "variable.ttf", "color.ttf", "bold.ttc"} {
		b, err := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if err != nil {
			t.Fatal(err)
		}
		add(name, b)
	}
	// Exercise repeated features and malformed/truncated layout data from the
	// separately generated structural parser corpus, using a small SFNT wrapper.
	compressed, err := os.ReadFile(filepath.Join(root, "compat/gsub/layout.json.gz"))
	if err != nil {
		t.Fatal(err)
	}
	z, err := gzip.NewReader(bytes.NewReader(compressed))
	if err != nil {
		t.Fatal(err)
	}
	decoded, err := io.ReadAll(z)
	if err != nil {
		t.Fatal(err)
	}
	z.Close()
	var cases []struct {
		Name string `json:"name"`
		Data []byte `json:"data"`
		Gpos bool   `json:"gpos"`
	}
	if err = json.Unmarshal(decoded, &cases); err != nil {
		t.Fatal(err)
	}
	for i, c := range cases {
		if c.Name != "synthetic" && (c.Name != "mutation" || i%5 != 0) {
			continue
		}
		tag := "GSUB"
		if c.Gpos {
			tag = "GPOS"
		}
		add(c.Name, sfnt.Build(map[string][]byte{"maxp": {0, 1, 0, 0, 0, 3}, tag: c.Data}, false))
	}
	encoded, err := json.Marshal(results)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/specimen/features.json.gz"), packFixture(encoded), 0644); err != nil {
		t.Fatal(err)
	}
}
