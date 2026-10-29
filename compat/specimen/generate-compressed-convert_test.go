//go:build ignore

// Copy into upstream converter/font alongside generate_test.go.
package font

import (
	"bytes"
	"encoding/json"
	conv "github.com/shibukawa/bdf/converter"
	"github.com/shibukawa/bdf/font/woff2"
	"os"
	"path/filepath"
	"testing"
	"testing/fstest"
)

func TestCodexCompressedFontConvert(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	files := map[string][]byte{}
	for _, name := range []string{"stix.ttf", "stix.otf", "features.ttf", "restricted.ttf", "variable.ttf", "bold.ttc", "color.ttf"} {
		data, err := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if err != nil {
			t.Fatal(err)
		}
		files[name] = data
	}
	for _, item := range []struct{ source, target string }{{"stix.ttf", "stix-ttf.woff2"}, {"stix.otf", "stix-cff.woff2"}} {
		data, err := woff2.Encode(files[item.source])
		if err != nil {
			t.Fatal(err)
		}
		files[item.target] = data
	}
	cases := []any{}
	for _, name := range []string{"stix.ttf", "stix.otf", "restricted.ttf"} {
		for mode := 0; mode < 4; mode++ {
			system := mode == 0 || mode == 2
			noIndex := mode == 0
			uiFont := mode%3 != 0 && mode != 4
			selection := ""
			title := ""
			if name == "bold.ttc" && mode == 3 {
				selection = "2,1"
				title = "Custom title"
			}
			fsys := fstest.MapFS{}
			if uiFont {
				fsys["stix.ttf"] = &fstest.MapFile{Data: files["stix.ttf"]}
			}
			text := ""
			if mode == 2 {
				text = "Hello あ"
			}
			noSubset := mode == 3
			ignore := mode == 3
			o := &conv.Options{NoWOFF2: false, NoSystemFonts: true, SystemFonts: system, NoTextIndex: noIndex, NoSubset: noSubset, IgnoreFSType: ignore, Title: title, FontFS: fsys, Params: map[string]string{"font": selection, "examples": "5", "text": text}}
			warnings := []string{}
			result, err := convert(files[name], o, func(s string) { warnings = append(warnings, s) })
			if err != nil {
				t.Fatal(name, err)
			}
			var visual []byte
			if name == "stix.ttf" && mode == 1 {
				var buf bytes.Buffer
				if err := result.Doc.WriteSingle(&buf); err != nil {
					t.Fatal(err)
				}
				visual = buf.Bytes()
			}
			parts := []any{}
			for _, p := range result.Doc.Parts() {
				parts = append(parts, map[string]any{"hash": p.Hash.String(), "type": p.Type, "data": p.Data})
			}
			cases = append(cases, map[string]any{"name": name, "visual": visual, "system": system, "noIndex": noIndex, "uiFont": uiFont, "selection": selection, "title": title, "text": text, "noSubset": noSubset, "ignore": ignore, "summary": result.Summary, "warnings": warnings, "meta": result.Doc.Meta, "views": result.Doc.Views, "parts": parts})
		}
	}
	encoded := map[string][]byte{}
	for name, data := range files {
		encoded[name] = packFixture(data)
	}
	data, err := json.Marshal(map[string]any{"files": encoded, "cases": cases})
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/specimen/compressed-convert.json.gz"), packFixture(data), 0644); err != nil {
		t.Fatal(err)
	}
}
