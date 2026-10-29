//go:build ignore

// Copy into upstream internal/otlayout and run TestCodexSubstitutions.
package otlayout

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexSubstitutions(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	packed, err := os.Open(filepath.Join(root, "compat/gsub/upstream.json.gz"))
	if err != nil {
		t.Fatal(err)
	}
	defer packed.Close()
	reader, err := gzip.NewReader(packed)
	if err != nil {
		t.Fatal(err)
	}
	raw, err := io.ReadAll(reader)
	if err != nil {
		t.Fatal(err)
	}
	var source []struct {
		Name string
		Data []byte
	}
	if err = json.Unmarshal(raw, &source); err != nil {
		t.Fatal(err)
	}
	seen := map[string]bool{}
	cases := []any{}
	for _, sample := range source {
		key := string(sample.Data)
		if seen[key] {
			continue
		}
		seen[key] = true
		parsed, err := ParseGSUB(sample.Data)
		if err != nil {
			continue
		}
		for i := -1; i <= len(parsed.Lookups); i++ {
			for _, limit := range []int{1, 7, 10000} {
				table, _ := ParseGSUB(sample.Data)
				list := []any{}
				table.Substs(i, func(s Subst) bool {
					in := []int{}
					out := []int{}
					for _, x := range s.In {
						in = append(in, int(x))
					}
					for _, x := range s.Out {
						out = append(out, int(x))
					}
					list = append(list, map[string]any{"input": in, "output": out})
					return len(list) < limit
				})
				cases = append(cases, map[string]any{"name": sample.Name, "data": sample.Data, "index": i, "limit": limit, "items": list, "truncated": table.Truncated()})
			}
		}
	}
	encoded, err := json.Marshal(cases)
	if err != nil {
		t.Fatal(err)
	}
	var out bytes.Buffer
	writer := gzip.NewWriter(&out)
	if _, err = writer.Write(encoded); err != nil {
		t.Fatal(err)
	}
	if err = writer.Close(); err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/gsub/substitutions.json.gz"), out.Bytes(), 0644); err != nil {
		t.Fatal(err)
	}
}
