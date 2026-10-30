//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexSingleStyledRunLegacy.
package xlsx

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexSingleStyledRunLegacy(t *testing.T) {
	src, root := os.Getenv("BDF_SOURCE_ROOT"), os.Getenv("BDF_FIXTURE_ROOT")
	if src == "" || root == "" {
		t.Fatal("BDF_SOURCE_ROOT and BDF_FIXTURE_ROOT required")
	}
	data, e := os.ReadFile(filepath.Join(src, "compat/xlsx/single-styled-run-legacy-inputs.json"))
	if e != nil {
		t.Fatal(e)
	}
	var inputs [][]byte
	if e = json.Unmarshal(data, &inputs); e != nil {
		t.Fatal(e)
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
	data, e = json.Marshal(out)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/single-styled-run-legacy.json"), data, 0644); e != nil {
		t.Fatal(e)
	}
}
