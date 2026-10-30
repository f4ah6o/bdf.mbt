//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexConditionalIdenticalBlocks.
package xlsx

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexConditionalIdenticalBlocks(t *testing.T) {
	src, root := os.Getenv("BDF_SOURCE_ROOT"), os.Getenv("BDF_FIXTURE_ROOT")
	if src == "" || root == "" {
		t.Fatal("BDF_SOURCE_ROOT and BDF_FIXTURE_ROOT required")
	}
	data, err := os.ReadFile(filepath.Join(src, "compat/xlsx/conditional-identical-blocks-inputs.json"))
	if err != nil {
		t.Fatal(err)
	}
	var inputs [][]byte
	if err = json.Unmarshal(data, &inputs); err != nil {
		t.Fatal(err)
	}
	out := []any{}
	for _, input := range inputs {
		result, err := Convert(bytes.NewReader(input), int64(len(input)), &Options{NoSystemFonts: true, SystemFonts: true, NoTextIndex: true, Data: "none"})
		if err != nil {
			t.Fatal(err)
		}
		var doc bytes.Buffer
		if err = result.Doc.WriteSingle(&doc); err != nil {
			t.Fatal(err)
		}
		out = append(out, map[string]any{"input": input, "bdf": doc.Bytes(), "warnings": result.Warnings, "mode": "none", "no_index": true})
	}
	data, err = json.Marshal(out)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/xlsx/conditional-identical-blocks.json"), data, 0644); err != nil {
		t.Fatal(err)
	}
}
