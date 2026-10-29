//go:build ignore

// Copy into upstream internal/otlayout and run TestCodexTagNames.
package otlayout

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"testing"
)

func TestCodexTagNames(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	tags := map[string]bool{"": true, "xxxx": true, "ss1": true, "cv-1": true, "😀": true, "ENG\t": true}
	for s := range featureNames {
		tags[s] = true
	}
	for s := range scriptNames {
		tags[s] = true
	}
	for s := range langNames {
		tags[s] = true
		tags[s+"  "] = true
	}
	for i := 0; i <= 99; i++ {
		tags[fmt.Sprintf("ss%02d", i)] = true
		tags[fmt.Sprintf("cv%02d", i)] = true
	}
	order := []string{}
	for tag := range tags {
		order = append(order, tag)
	}
	sort.Strings(order)
	out := []any{}
	for _, tag := range order {
		out = append(out, map[string]any{"tag": tag, "feature": FeatureName(tag), "default": FeatureDefault(tag), "script": ScriptName(tag), "language": LangName(tag)})
	}
	typ := []any{}
	for n := -1; n <= 11; n++ {
		for _, gpos := range []bool{false, true} {
			table := &Table{gpos: gpos}
			typ = append(typ, map[string]any{"typ": n, "gpos": gpos, "name": table.TypeName(n)})
		}
	}
	data, err := json.Marshal(map[string]any{"tags": out, "types": typ})
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/gsub/names.json"), data, 0644); err != nil {
		t.Fatal(err)
	}
}
