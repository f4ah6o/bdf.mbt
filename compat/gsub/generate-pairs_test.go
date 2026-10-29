//go:build ignore

// Copy into upstream internal/otlayout alongside generate_test.go.
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

func TestCodexPositionPairs(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	packed, err := os.Open(filepath.Join(root, "compat/gsub/gpos.json.gz"))
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
		Name  string
		Data  []byte
		Valid bool
	}
	if err = json.Unmarshal(raw, &source); err != nil {
		t.Fatal(err)
	}
	value := func(v Value) any {
		return map[string]int{"xPlacement": v.XPlacement, "yPlacement": v.YPlacement, "xAdvance": v.XAdvance, "yAdvance": v.YAdvance}
	}
	cases := []any{}
	for _, sample := range source {
		if !sample.Valid {
			continue
		}
		table, err := ParseGPOS(sample.Data)
		if err != nil {
			continue
		}
		lookups := []any{}
		for i := -1; i <= len(table.Lookups); i++ {
			runs := []any{}
			for _, limit := range []int{1, 20, 100} {
				pairs := []any{}
				table.Pairs(i, func(p Pair) bool {
					pairs = append(pairs, map[string]any{"first": p.First, "second": p.Second, "v1": value(p.V1), "v2": value(p.V2)})
					return len(pairs) < limit
				})
				runs = append(runs, pairs)
			}
			lookups = append(lookups, runs)
		}
		cases = append(cases, map[string]any{"name": sample.Name, "data": sample.Data, "lookups": lookups, "truncated": table.Truncated()})
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
	if err = os.WriteFile(filepath.Join(root, "compat/gsub/pairs.json.gz"), out.Bytes(), 0644); err != nil {
		t.Fatal(err)
	}
}
