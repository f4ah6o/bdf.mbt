//go:build ignore

// Copy into upstream converter/font alongside generate_test.go.
package font

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	conv "github.com/shibukawa/bdf/converter"
	"github.com/shibukawa/bdf/internal/sfnt"
)

func TestCodexDocumentPlan(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	results := []any{}
	add := func(name string, raw []byte, selection, title string) {
		o := &conv.Options{NoWOFF2: true, NoSystemFonts: true, SystemFonts: true, NoTextIndex: true, Title: title, Params: map[string]string{"font": selection, "examples": "1"}}
		warnings := []string{}
		r, err := convert(raw, o, func(s string) { warnings = append(warnings, s) })
		if err != nil {
			t.Fatal(name, err)
		}
		dc := r.Doc.Meta.DC
		views := []any{}
		for _, v := range r.Doc.Views {
			views = append(views, map[string]any{"id": v.ID, "title": v.Title})
		}
		results = append(results, map[string]any{"name": name, "input": packFixture(raw), "selection": selection, "title": title, "metadata": map[string]any{"source": r.Doc.Meta.Source, "type": dc.Type.First(), "title": dc.Title.First(), "creator": dc.Creator.First(), "rights": dc.Rights.First(), "description": dc.Description.First(), "created": dc.Created.First(), "modified": dc.Modified.First()}, "views": views})
	}
	for _, name := range []string{"stix.ttf", "stix.otf", "features.ttf", "restricted.ttf", "variable.ttf", "color.ttf", "bold.ttc"} {
		raw, err := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if err != nil {
			t.Fatal(err)
		}
		add(name, raw, "", "")
		if name == "bold.ttc" {
			add(name, raw, "all", "")
			add(name, raw, "2,1", "Custom title")
			add(name, raw, "2", "")
			add(name, raw, "1,1", "")
		}
	}
	raw := sfnt.Build(map[string][]byte{"maxp": {0, 1, 0, 0, 0, 2}}, false)
	add("minimal", raw, "", "")
	add("minimal", raw, "1,1", "")
	add("minimal", raw, "", "Custom title")
	data, err := json.Marshal(results)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/specimen/document-plan.json.gz"), packFixture(data), 0644); err != nil {
		t.Fatal(err)
	}
}
