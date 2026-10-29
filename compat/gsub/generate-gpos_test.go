//go:build ignore

// Copy into upstream internal/otlayout with generate_test.go.
package otlayout

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"github.com/shibukawa/bdf/internal/sfnt"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexGPOSPairs(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	results := []any{}
	add := func(name string, data []byte) {
		table, e := ParseGPOS(data)
		out := map[string]any{"name": name, "data": data, "valid": e == nil}
		if e == nil {
			queries := []int{-1, 0, 0, 0, 0, 0, 0, 0}
			for i := 1; i < min(len(table.Lookups)+2, 15); i++ {
				queries = append(queries, i)
			}
			counts := []int{}
			truncated := []bool{}
			for _, i := range queries {
				counts = append(counts, table.PairCount(i))
				truncated = append(truncated, table.Truncated())
			}
			out["queries"] = queries
			out["counts"] = counts
			out["truncated"] = truncated
		}
		results = append(results, out)
	}
	var bases [][]byte
	for _, name := range []string{"stix.ttf", "stix.otf", "features.ttf", "variable.ttf", "color.ttf"} {
		b, e := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if e != nil {
			t.Fatal(e)
		}
		f, e := sfnt.Parse(b)
		if e != nil {
			t.Fatal(e)
		}
		if b = f.Tables["GPOS"]; b != nil {
			add(name, b)
			bases = append(bases, b)
		}
	}
	st1 := wordsFixture(1, 12, 4, 0, 1, 18, 1, 1, 5, 2, 10, 65500, 11, 0)
	st2 := wordsFixture(2, 24, 4, 0, 30, 38, 2, 2, 0, 0, 0, 65500, 1, 1, 5, 1, 5, 1, 1, 1, 10, 2, 1, 1)
	synthetic := tableFixture(lookupFixture(2, st1, st2), lookupFixture(9, extensionFixture(2, st1)))
	add("synthetic", synthetic)
	bases = append(bases, synthetic)
	// Each PairCount visits one thousand references to a thousand-entry set.
	st := make([]byte, 10+2000)
	put16Fixture(st, 0, 1)
	put16Fixture(st, 4, 4)
	put16Fixture(st, 8, 1000)
	setoff := len(st)
	for i := 0; i < 1000; i++ {
		put16Fixture(st, 10+2*i, setoff)
	}
	st = append(st, wordsFixture(1000)...)
	for i := 0; i < 1000; i++ {
		st = append(st, wordsFixture(i, 65535)...)
	}
	add("shared-budget", tableFixture(lookupFixture(2, st)))
	rng := rand.New(rand.NewSource(98317))
	for i := 0; i < 900; i++ {
		base := bases[i%len(bases)]
		data := append([]byte(nil), base...)
		if i%3 == 0 {
			data = data[:rng.Intn(len(data)+1)]
		} else {
			for j := 0; j < 1+rng.Intn(6); j++ {
				data[rng.Intn(len(data))] = byte(rng.Intn(256))
			}
		}
		add("mutation", data)
	}
	raw, e := json.Marshal(results)
	if e != nil {
		t.Fatal(e)
	}
	var b bytes.Buffer
	z := gzip.NewWriter(&b)
	if _, e = z.Write(raw); e != nil {
		t.Fatal(e)
	}
	if e = z.Close(); e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/gsub/gpos.json.gz"), b.Bytes(), 0644); e != nil {
		t.Fatal(e)
	}
}
