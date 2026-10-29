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

func TestCodexLookupContexts(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	packed, err := os.Open(filepath.Join(root, "compat/gsub/layout.json.gz"))
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
		Gpos  bool
		Valid bool
	}
	if err = json.Unmarshal(raw, &source); err != nil {
		t.Fatal(err)
	}
	// Format 3, two inputs, three records: duplicate and out-of-range references.
	for _, gpos := range []bool{false, true} {
		for _, chained := range []bool{false, true} {
			typ := 5
			if gpos {
				typ = 7
			}
			if chained {
				typ++
			}
			var sub []byte
			if chained {
				sub = wordsFixture(3, 0, 2, 0, 0, 0, 3, 0, 1, 1, 1, 1, 9)
			} else {
				sub = wordsFixture(3, 2, 3, 0, 0, 0, 1, 1, 1, 1, 9)
			}
			data := tableFixture(lookupFixture(typ, sub), lookupFixture(1, singleFixture([]int{1}, []int{2}, false)))
			source = append(source, struct {
				Name  string
				Data  []byte
				Gpos  bool
				Valid bool
			}{"format3", data, gpos, true})
		}
	}
	// Formats 1 and 2 rule sets with multiple records, including duplicates.
	for _, gpos := range []bool{false, true} {
		for _, chained := range []bool{false, true} {
			for _, format := range []int{1, 2} {
				typ := 5
				if gpos {
					typ = 7
				}
				if chained {
					typ++
				}
				offset := 4
				if format == 2 {
					offset = 6
					if chained {
						offset = 10
					}
				}
				sub := make([]byte, offset+4)
				put16Fixture(sub, 0, format)
				put16Fixture(sub, offset, 1)
				put16Fixture(sub, offset+2, len(sub))
				set := wordsFixture(1, 4)
				if chained {
					set = append(set, wordsFixture(1, 8, 2, 9, 1, 10, 3, 0, 1, 1, 1, 2, 9)...)
				} else {
					set = append(set, wordsFixture(2, 3, 9, 0, 1, 1, 1, 2, 9)...)
				}
				sub = append(sub, set...)
				data := tableFixture(lookupFixture(typ, sub), lookupFixture(1, singleFixture([]int{1}, []int{2}, false)))
				source = append(source, struct {
					Name  string
					Data  []byte
					Gpos  bool
					Valid bool
				}{"rule-set", data, gpos, true})
			}
		}
	}
	cases := []any{}
	for _, sample := range source {
		if !sample.Valid {
			continue
		}
		var table *Table
		if sample.Gpos {
			table, err = ParseGPOS(sample.Data)
		} else {
			table, err = ParseGSUB(sample.Data)
		}
		if err != nil {
			continue
		}
		indices := []int{-1}
		for i := range table.Lookups {
			indices = append(indices, i)
		}
		indices = append(indices, len(table.Lookups))
		contexts := []any{}
		for _, index := range indices {
			c, ok := table.Context(index)
			if !ok {
				contexts = append(contexts, nil)
			} else {
				contexts = append(contexts, map[string]any{"rules": c.Rules, "nested": append([]int{}, c.Nested...)})
			}
		}
		cases = append(cases, map[string]any{"name": sample.Name, "data": sample.Data, "gpos": sample.Gpos, "contexts": contexts, "truncated": table.Truncated()})
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
	if err = os.WriteFile(filepath.Join(root, "compat/gsub/context.json.gz"), out.Bytes(), 0644); err != nil {
		t.Fatal(err)
	}
}
