//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexRepeatedChildrenLegacy.
package xlsx

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexRepeatedChildrenLegacy(t *testing.T) {
	root, source := os.Getenv("BDF_FIXTURE_ROOT"), os.Getenv("BDF_SOURCE_ROOT")
	if root == "" || source == "" {
		t.Fatal("fixture and source roots required")
	}
	var out []any
	for name, indices := range map[string][]int{"plain-run-unsupported.json": {2, 3}} {
		data, e := os.ReadFile(filepath.Join(source, "compat/xlsx", name))
		if e != nil {
			t.Fatal(e)
		}
		var inputs [][]byte
		if e = json.Unmarshal(data, &inputs); e != nil {
			t.Fatal(e)
		}
		for _, i := range indices {
			input := inputs[i]
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
	}
	data, e := json.Marshal(out)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/repeated-children-legacy.json"), data, 0644); e != nil {
		t.Fatal(e)
	}
}
