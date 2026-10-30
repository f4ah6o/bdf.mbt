//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexConditionalMissingDxfLegacy.
package xlsx

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexConditionalMissingDxfLegacy(t *testing.T) {
	root, source := os.Getenv("BDF_FIXTURE_ROOT"), os.Getenv("BDF_SOURCE_ROOT")
	if root == "" || source == "" {
		t.Fatal("fixture and source roots required")
	}
	inputs := []struct {
		name  string
		index int
	}{
		{"active-cf-unsupported.json", 6},
		{"active-cf-unsupported.json", 7},
		{"conditional-absolute-unsupported.json", 6},
		{"conditional-absolute-unsupported.json", 7},
		{"conditional-average-unsupported.json", 6},
		{"conditional-average-unsupported.json", 7},
		{"conditional-axis-ref-unsupported.json", 6},
		{"conditional-axis-ref-unsupported.json", 7},
		{"conditional-between-unsupported.json", 6},
		{"conditional-between-unsupported.json", 7},
		{"conditional-blank-unsupported.json", 6},
		{"conditional-blank-unsupported.json", 7},
		{"conditional-border-unsupported.json", 6},
		{"conditional-border-unsupported.json", 7},
		{"conditional-duplicate-unsupported.json", 6},
		{"conditional-duplicate-unsupported.json", 7},
		{"conditional-equals-unsupported.json", 6},
		{"conditional-equals-unsupported.json", 7},
		{"conditional-fill-unsupported.json", 6},
		{"conditional-fill-unsupported.json", 7},
		{"conditional-invalid-reference-unsupported.json", 6},
		{"conditional-invalid-reference-unsupported.json", 7},
		{"conditional-large-stddev-unsupported.json", 6},
		{"conditional-large-stddev-unsupported.json", 7},
		{"conditional-literal-unsupported.json", 6},
		{"conditional-literal-unsupported.json", 7},
		{"conditional-moving-literal-unsupported.json", 6},
		{"conditional-moving-literal-unsupported.json", 7},
		{"conditional-moving-ref-unsupported.json", 6},
		{"conditional-moving-ref-unsupported.json", 7},
		{"conditional-negative-blank-unsupported.json", 6},
		{"conditional-negative-blank-unsupported.json", 7},
		{"conditional-negative-ref-unsupported.json", 6},
		{"conditional-negative-ref-unsupported.json", 7},
		{"conditional-negative-string-unsupported.json", 6},
		{"conditional-negative-string-unsupported.json", 7},
		{"conditional-nonfinite-average-unsupported.json", 6},
		{"conditional-nonfinite-average-unsupported.json", 7},
		{"conditional-ops-unsupported.json", 6},
		{"conditional-ops-unsupported.json", 7},
		{"conditional-overflow-mean-unsupported.json", 6},
		{"conditional-overflow-mean-unsupported.json", 7},
		{"conditional-paint-blank-unsupported.json", 6},
		{"conditional-paint-blank-unsupported.json", 7},
		{"conditional-predicates-unsupported.json", 6},
		{"conditional-predicates-unsupported.json", 7},
		{"conditional-single-ref-unsupported.json", 6},
		{"conditional-single-ref-unsupported.json", 7},
		{"conditional-stddev-unsupported.json", 6},
		{"conditional-stddev-unsupported.json", 7},
		{"conditional-text-unsupported.json", 6},
		{"conditional-text-unsupported.json", 7},
		{"conditional-top-unsupported.json", 6},
		{"conditional-top-unsupported.json", 7},
		{"conditional-typed-reference-unsupported.json", 6},
		{"conditional-typed-reference-unsupported.json", 7},
		{"inactive-cf-unsupported.json", 1},
		{"inactive-cf-unsupported.json", 3},
		{"inactive-cf-unsupported.json", 4},
		{"inactive-cf-unsupported.json", 5},
	}
	var out []any
	for _, item := range inputs {
		data, e := os.ReadFile(filepath.Join(source, "compat/xlsx", item.name))
		if e != nil {
			t.Fatal(e)
		}
		var cases [][]byte
		if e = json.Unmarshal(data, &cases); e != nil {
			t.Fatal(e)
		}
		input := cases[item.index]
		result, e := Convert(bytes.NewReader(input), int64(len(input)), &Options{NoSystemFonts: true, SystemFonts: true, NoTextIndex: true, Data: "none"})
		if e != nil {
			t.Fatal(e)
		}
		var doc bytes.Buffer
		if e = result.Doc.WriteSingle(&doc); e != nil {
			t.Fatal(e)
		}
		out = append(out, map[string]any{"source": item.name, "index": item.index, "input": input, "bdf": doc.Bytes(), "warnings": result.Warnings, "mode": "none", "no_index": true})
	}
	data, e := json.Marshal(out)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/conditional-missing-dxf-legacy.json"), data, 0644); e != nil {
		t.Fatal(e)
	}
}
