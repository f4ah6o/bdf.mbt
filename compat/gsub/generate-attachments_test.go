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
	"sort"
	"testing"
)

func TestCodexAttachments(t *testing.T) {
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
	// Two marks and two bases, one class, with signed anchor coordinates.
	sub := wordsFixture(1, 12, 20, 1, 28, 50, 1, 2, 7, 8, 1, 2, 9, 10, 2, 0, 10, 0, 16, 1, 0xfffe, 3, 2, 4, 0xfffb, 2, 6, 12, 1, 20, 30, 3, 40, 0xffce)
	for _, typ := range []int{3, 4, 5, 6} {
		data := tableFixture(lookupFixture(typ, sub, sub))
		source = append(source, struct {
			Name string
			Data []byte
			Gpos bool
		}{"synthetic", data, true})
	}
	anchor := func(a Anchor) any { return map[string]int{"x": a.X, "y": a.Y} }
	cases := []any{}
	for _, sample := range source {
		if !sample.Gpos {
			continue
		}
		table, err := ParseGPOS(sample.Data)
		if err != nil {
			continue
		}
		lookups := []any{}
		for i := -1; i <= len(table.Lookups); i++ {
			m, b := table.MarkCounts(i)
			attachments := []any{}
			for _, a := range table.Attachments(i) {
				marks := []any{}
				bases := []any{}
				ids := []int{}
				for g := range a.Marks {
					ids = append(ids, int(g))
				}
				sort.Ints(ids)
				for _, id := range ids {
					v := a.Marks[uint16(id)]
					marks = append(marks, map[string]any{"glyph": id, "class": v.Class, "anchor": anchor(v.Anchor)})
				}
				ids = nil
				for g := range a.Bases {
					ids = append(ids, int(g))
				}
				sort.Ints(ids)
				for _, id := range ids {
					values := []any{}
					for _, v := range a.Bases[uint16(id)] {
						if v == nil {
							values = append(values, nil)
						} else {
							values = append(values, anchor(*v))
						}
					}
					bases = append(bases, map[string]any{"glyph": id, "anchors": values})
				}
				attachments = append(attachments, map[string]any{"marks": marks, "bases": bases})
			}
			lookups = append(lookups, map[string]any{"counts": []int{m, b}, "attachments": attachments})
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
	if err = os.WriteFile(filepath.Join(root, "compat/gsub/attachments.json.gz"), out.Bytes(), 0644); err != nil {
		t.Fatal(err)
	}
}
