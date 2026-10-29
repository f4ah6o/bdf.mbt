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

func TestCodexPositionValues(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	packed, err := os.Open(filepath.Join(root, "compat/gsub/context.json.gz"))
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
		Gpos bool
	}
	if err = json.Unmarshal(raw, &source); err != nil {
		t.Fatal(err)
	}
	// Single-adjustment formats, including a zero-size value record and duplicates.
	for _, sub := range [][]byte{
		wordsFixture(1, 10, 5, 0xfffe, 30, 1, 2, 2, 3),
		wordsFixture(2, 16, 3, 2, 0xfffd, 4, 5, 0xfffa, 1, 2, 2, 3),
		wordsFixture(2, 8, 0, 3, 1, 2, 2, 3),
	} {
		data := tableFixture(lookupFixture(1, sub, sub))
		source = append(source, struct {
			Name string
			Data []byte
			Gpos bool
		}{"single", data, true})
	}
	value := func(v Value) any {
		return map[string]int{"xPlacement": v.XPlacement, "yPlacement": v.YPlacement, "xAdvance": v.XAdvance, "yAdvance": v.YAdvance}
	}
	cases := []any{}
	for _, sample := range source {
		if !sample.Gpos {
			continue
		}
		table, err := ParseGPOS(sample.Data)
		if err != nil {
			continue
		}
		other, _ := ParseGPOS(sample.Data)
		lookups := []any{}
		for i := range table.Lookups {
			singles := []any{}
			table.Singles(i, func(g uint16, v Value) bool {
				singles = append(singles, map[string]any{"glyph": g, "value": value(v)})
				return len(singles) < 100
			})
			pairs := [][2]uint16{{0, 0}, {1, 1}, {1, 2}, {10, 11}, {30, 50}, {100, 200}, {65535, 65535}}
			other.Pairs(i, func(p Pair) bool { pairs = append(pairs, [2]uint16{p.First, p.Second}); return len(pairs) < 20 })
			results := []any{}
			for _, p := range pairs {
				a, b, ok := table.PairValue(i, p[0], p[1])
				if ok {
					results = append(results, map[string]any{"first": p[0], "second": p[1], "v1": value(a), "v2": value(b)})
				} else {
					results = append(results, map[string]any{"first": p[0], "second": p[1], "v1": nil, "v2": nil})
				}
			}
			lookups = append(lookups, map[string]any{"singles": singles, "pairs": results})
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
	if err = os.WriteFile(filepath.Join(root, "compat/gsub/position-values.json.gz"), out.Bytes(), 0644); err != nil {
		t.Fatal(err)
	}
}
