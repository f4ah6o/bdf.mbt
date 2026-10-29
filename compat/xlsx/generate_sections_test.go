//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexXLSXSections.
package xlsx

import (
	"encoding/json"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexXLSXSections(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	values := []string{"", "0;0;0;@", `";";[Red]0`, `\;;_;;*;;`, `*🦊;0`, `[a;b];[;]`, `"unclosed;0`, `[_;]`}
	r := rand.New(rand.NewSource(240223))
	parts := []string{";", "[", "]", "\"", "\\", "_", "*", "0", "%", "a", "年", "🦊", "\ufeff"}
	for i := 0; i < 10000; i++ {
		s := ""
		for j := 0; j < r.Intn(35); j++ {
			s += parts[r.Intn(len(parts))]
		}
		values = append(values, s)
	}
	out := []any{}
	for _, v := range values {
		out = append(out, map[string]any{"code": v, "want": splitSections(v)})
	}
	b, err := json.Marshal(out)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/xlsx/sections.json"), b, 0644); err != nil {
		t.Fatal(err)
	}
}
