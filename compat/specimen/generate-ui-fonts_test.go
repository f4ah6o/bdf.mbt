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
	"github.com/shibukawa/bdf/converter/internal/fontset"
	"github.com/shibukawa/bdf/internal/fontdb"
)

func TestCodexSpecimenUIFonts(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	files := map[string][]byte{}
	for _, name := range []string{"stix.ttf", "stix.otf", "restricted.ttf", "bold.ttc"} {
		b, e := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if e != nil {
			t.Fatal(e)
		}
		files[name] = b
	}
	texts := []string{"Hello BDF", "A漢B あ 한", "fi ffi AV", "é Ω ﬃ", ""}
	results := []any{}
	for _, config := range [][]string{{}, {"stix.ttf"}, {"stix.otf"}, {"restricted.ttf"}, {"bold.ttc", "stix.ttf"}} {
		for _, system := range []bool{false, true} {
			for _, noSubset := range []bool{false, true} {
				for _, ignore := range []bool{false, true} {
					fsys := fstest.MapFS{}
					for _, name := range config {
						fsys[name] = &fstest.MapFile{Data: files[name]}
					}
					warnings := []string{}
					set := fontset.New(fontdb.New(fsys, nil, false), func(s string) { warnings = append(warnings, s) })
					tx := &texter{set: set}
					lines := []*textLine{}
					for i, text := range texts {
						lines = append(lines, tx.line(text, 12, float64(i) == 1))
					}
					doc := bdf.NewDocument()
					parts := 0
					if !system {
						parts = set.Embed(doc, fontset.EmbedOptions{NoSubset: noSubset, NoWOFF2: true, IgnoreFSType: ignore})
					}
					fonts := [][]any{}
					for _, line := range lines {
						records := []any{}
						for _, run := range line.runs {
							f := set.Font(run.fc.Use)
							var hash any
							if f.Kind == bdf.FontEmbedded {
								hash = f.Hash.String()
							}
							records = append(records, map[string]any{"hash": hash, "family": f.Family, "weight": f.Weight, "style": f.Style})
						}
						fonts = append(fonts, records)
					}
					results = append(results, map[string]any{"fonts": append([]string{}, config...), "system": system, "noSubset": noSubset, "ignore": ignore, "texts": texts, "records": fonts, "parts": parts, "warnings": warnings})
				}
			}
		}
	}
	packed := map[string][]byte{}
	for name, data := range files {
		packed[name] = packFixture(data)
	}
	data, err := json.Marshal(map[string]any{"files": packed, "cases": results})
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/specimen/ui-fonts.json.gz"), packFixture(data), 0644); err != nil {
		t.Fatal(err)
	}
}
