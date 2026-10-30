//go:build ignore

// Run generate_rectangle_invalid.py first, then copy this file into upstream
// converter/xlsx and run TestCodexFormulaPreviouslyUnsupported.
package xlsx

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexFormulaPreviouslyUnsupported(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	data, err := os.ReadFile(filepath.Join(root, "compat/xlsx/formula-previously-unsupported-inputs.json"))
	if err != nil {
		t.Fatal(err)
	}
	var cases []struct {
		Input   []byte `json:"input"`
		Mode    string `json:"mode"`
		NoIndex bool   `json:"no_index"`
		Label   string `json:"label"`
	}
	if err := json.Unmarshal(data, &cases); err != nil {
		t.Fatal(err)
	}
	if len(cases) != 2 {
		t.Fatalf("expected 2 input cases, got %d", len(cases))
	}
	out := make([]any, 0, len(cases))
	for _, c := range cases {
		result, err := Convert(bytes.NewReader(c.Input), int64(len(c.Input)), &Options{NoSystemFonts: true, SystemFonts: true, NoTextIndex: c.NoIndex, Data: c.Mode})
		if err != nil {
			t.Fatalf("%s: %v", c.Label, err)
		}
		var doc bytes.Buffer
		if err := result.Doc.WriteSingle(&doc); err != nil {
			t.Fatalf("%s: %v", c.Label, err)
		}
		out = append(out, map[string]any{"input": c.Input, "bdf": doc.Bytes(), "warnings": result.Warnings, "mode": c.Mode, "no_index": c.NoIndex, "label": c.Label})
	}
	data, err = json.Marshal(out)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "compat/xlsx/formula-previously-unsupported.json"), data, 0644); err != nil {
		t.Fatal(err)
	}
}
