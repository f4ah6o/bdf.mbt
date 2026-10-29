//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexXLSXBuiltin.
package xlsx

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexXLSXBuiltin(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	out := []any{}
	for _, locale := range []string{"", "en", "ja", "JA", "ja-JP"} {
		for id := -10; id <= 200; id++ {
			out = append(out, map[string]any{"id": id, "locale": locale, "want": builtinFormat(id, locale)})
		}
	}
	b, err := json.Marshal(out)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/xlsx/builtin.json"), b, 0644); err != nil {
		t.Fatal(err)
	}
}
