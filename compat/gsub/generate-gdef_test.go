//go:build ignore

// Copy into upstream internal/otlayout with generate_test.go.
package otlayout

import (
	"bytes"
	"compress/gzip"
	"encoding/binary"
	"encoding/json"
	"github.com/shibukawa/bdf/internal/sfnt"
	"math/rand"
	"os"
	"path/filepath"
	"sort"
	"testing"
)

func TestCodexGDEF(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	results := []any{}
	add := func(name string, b []byte) {
		g := ParseGDEF(b)
		out := map[string]any{"name": name, "data": b, "valid": g != nil}
		if g != nil {
			pairs := func(m map[uint16]int) []any {
				keys := []int{}
				for k := range m {
					keys = append(keys, int(k))
				}
				sort.Ints(keys)
				p := []any{}
				for _, k := range keys {
					p = append(p, []int{k, m[uint16(k)]})
				}
				return p
			}
			sets := [][]uint16{}
			for _, s := range g.MarkSets {
				sets = append(sets, append([]uint16{}, s...))
			}
			out["classes"] = pairs(g.Classes)
			out["attach"] = pairs(g.MarkAttach)
			out["sets"] = sets
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
		if b = f.Tables["GDEF"]; b != nil {
			add(name, b)
			bases = append(bases, b)
		}
	}
	header := wordsFixture(1, 2, 14, 0, 0, 28, 44)
	classes := wordsFixture(1, 10, 4, 1, 0, 2, 3)
	attach := wordsFixture(2, 2, 10, 12, 3, 12, 14, 2)
	sets := wordsFixture(1, 2, 0, 12, 0, 22, 1, 3, 4, 5, 6, 2, 1, 20, 22, 0)
	synthetic := append(append(append(header, classes...), attach...), sets...)
	add("synthetic", synthetic)
	bases = append(bases, synthetic)
	// Repeated maximal class/coverage ranges exercise both work limits.
	limit := wordsFixture(1, 2, 14, 0, 0, 0, 30)
	limit = append(limit, wordsFixture(2, 2, 0, 65535, 1, 0, 65535, 2)...)
	ms := make([]byte, 4+17*4)
	binary.BigEndian.PutUint16(ms, 1)
	binary.BigEndian.PutUint16(ms[2:], 17)
	for i := 0; i < 17; i++ {
		binary.BigEndian.PutUint32(ms[4+i*4:], uint32(len(ms)))
	}
	ms = append(ms, wordsFixture(2, 1, 0, 65535, 0)...)
	limit = append(limit, ms...)
	add("limits", limit)
	rng := rand.New(rand.NewSource(93245))
	for i := 0; i < 600; i++ {
		base := bases[i%len(bases)]
		data := append([]byte(nil), base...)
		if i%3 == 0 {
			data = data[:rng.Intn(len(data)+1)]
		} else {
			for j := 0; j < 1+rng.Intn(5); j++ {
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
	if e = os.WriteFile(filepath.Join(root, "compat/gsub/gdef.json.gz"), b.Bytes(), 0644); e != nil {
		t.Fatal(e)
	}
}
