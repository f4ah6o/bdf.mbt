//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexRichRunLegacy.
package xlsx

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexRichRunLegacy(t *testing.T) {
	src, root := os.Getenv("BDF_SOURCE_ROOT"), os.Getenv("BDF_FIXTURE_ROOT")
	if src == "" || root == "" {
		t.Fatal("BDF_SOURCE_ROOT and BDF_FIXTURE_ROOT required")
	}
	var inputs [][]byte
	for _, name := range []string{"multiple-plain-runs-legacy-inputs.json", "multiple-plain-runs-extra-inputs.json"} {
		data, e := os.ReadFile(filepath.Join(src, "compat/xlsx", name))
		if e != nil {
			t.Fatal(e)
		}
		var next [][]byte
		if e = json.Unmarshal(data, &next); e != nil {
			t.Fatal(e)
		}
		inputs = append(inputs, next...)
	}
	out := []any{}
	for _, input := range inputs {
		result, e := Convert(bytes.NewReader(input), int64(len(input)), &Options{NoSystemFonts: true, SystemFonts: true, NoTextIndex: true, Data: "none"})
		if e != nil {
			t.Fatal(e)
		}
		var doc bytes.Buffer
		if e = result.Doc.WriteSingle(&doc); e != nil {
			t.Fatal(e)
		}
		out = append(out, map[string]any{"input": input, "bdf": doc.Bytes(), "warnings": result.Warnings, "mode": "none", "no_index": true})
	}
	data, e := json.Marshal(out)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/rich-run-legacy.json"), data, 0644); e != nil {
		t.Fatal(e)
	}
}
