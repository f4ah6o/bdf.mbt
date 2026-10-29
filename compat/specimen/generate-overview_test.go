//go:build ignore

// Copy into upstream converter/font with generate_test.go.
package font

import (
	"bytes"
	"compress/gzip"
	"encoding/binary"
	"encoding/json"
	"github.com/shibukawa/bdf/internal/sfnt"
	"io"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexOverview(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	results := []any{}
	add := func(name string, data []byte) {
		fl, e := load(data)
		if e != nil {
			t.Fatal(name, e)
		}
		for _, fc := range fl.faces {
			fc.prepare()
			for _, outline := range []bool{false, true} {
				sections := []any{}
				for _, s := range fc.sections(fl, outline) {
					rows := []any{}
					for _, r := range s.rows {
						rows = append(rows, map[string]any{"label": r.label, "value": r.value, "lang": r.lang})
					}
					sections = append(sections, map[string]any{"title": s.title, "rows": rows})
				}
				tables := []any{}
				for _, r := range fc.tableList() {
					tables = append(tables, map[string]any{"label": r.label, "value": r.value, "lang": r.lang})
				}
				results = append(results, map[string]any{"name": name, "input": packFixture(data), "index": fc.index, "outline": outline, "sections": sections, "tables": tables})
			}
		}
	}
	for _, name := range []string{"stix.ttf", "stix.otf", "features.ttf", "variable.ttf", "color.ttf", "bold.ttc"} {
		b, e := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if e != nil {
			t.Fatal(e)
		}
		add(name, b)
	}
	// Reuse WOFF and malformed specimens from the program compatibility corpus.
	packed, e := os.ReadFile(filepath.Join(root, "compat/specimen/upstream.json.gz"))
	if e != nil {
		t.Fatal(e)
	}
	unpack := func(data []byte) []byte {
		r, err := gzip.NewReader(bytes.NewReader(data))
		if err != nil {
			t.Fatal(err)
		}
		defer r.Close()
		out, err := io.ReadAll(r)
		if err != nil {
			t.Fatal(err)
		}
		return out
	}
	var original []struct {
		Name  string `json:"name"`
		Input []byte `json:"input"`
	}
	if e = json.Unmarshal(unpack(packed), &original); e != nil {
		t.Fatal(e)
	}
	for _, item := range original {
		if item.Name == "woff-input" || item.Name == "cff2-only" || item.Name == "bad-cff-fallback" || item.Name == "bad-cff-oversized" {
			add(item.Name, unpack(item.Input))
		}
	}
	b, e := os.ReadFile(filepath.Join(root, "compat/font/fixtures/variable.ttf"))
	if e != nil {
		t.Fatal(e)
	}
	real, e := sfnt.Parse(b)
	if e != nil {
		t.Fatal(e)
	}
	base := map[string][]byte{"maxp": {0, 1, 0, 0, 0, 3}, "name": real.Tables["name"], "head": make([]byte, 54), "hhea": make([]byte, 36), "OS/2": make([]byte, 100), "post": make([]byte, 32)}
	binary.BigEndian.PutUint16(base["head"][18:], 1000)
	binary.BigEndian.PutUint16(base["OS/2"][4:], 400)
	binary.BigEndian.PutUint16(base["OS/2"][6:], 5)
	add("synthetic", sfnt.Build(base, false))
	rng := rand.New(rand.NewSource(56294))
	tags := []string{"head", "hhea", "OS/2", "post"}
	for i := 0; i < 160; i++ {
		tables := map[string][]byte{}
		for k, v := range base {
			tables[k] = append([]byte(nil), v...)
		}
		tag := tags[i%len(tags)]
		data := tables[tag]
		if i%7 == 0 {
			data = data[:rng.Intn(len(data)+1)]
		} else {
			for j := 0; j < 1+rng.Intn(8); j++ {
				data[rng.Intn(len(data))] = byte(rng.Intn(256))
			}
		}
		tables[tag] = data
		if i%5 == 0 {
			tables["fvar"] = real.Tables["fvar"]
		}
		if i%9 == 0 {
			tables["MATH"] = []byte{0, 0}
		}
		add("mutation", sfnt.Build(tables, false))
	}

	// Head dates and fixed-point angles around all formatting boundaries.
	for _, sec := range []uint64{0, 1, 59, 60, 86399, 86400, 31536000, 126230400, 3155760000, 6307200000, 6307200001, ^uint64(0)} {
		tables := map[string][]byte{}
		for k, v := range base {
			tables[k] = append([]byte(nil), v...)
		}
		binary.BigEndian.PutUint64(tables["head"][20:], sec)
		binary.BigEndian.PutUint64(tables["head"][28:], sec)
		add("head-time", sfnt.Build(tables, false))
	}
	for _, fixed := range []int32{-65536, -655, -33, -32, -1, 0, 1, 32, 33, 655, 65536} {
		tables := map[string][]byte{}
		for k, v := range base {
			tables[k] = append([]byte(nil), v...)
		}
		binary.BigEndian.PutUint32(tables["post"][4:], uint32(fixed))
		add("italic-fixed", sfnt.Build(tables, false))
	}
	for _, size := range []int{0, 1, 1023, 1024, 1536, 1048575, 1048576, 1572864} {
		tables := map[string][]byte{}
		for k, v := range base {
			tables[k] = v
		}
		tables["test"] = make([]byte, size)
		add("table-size", sfnt.Build(tables, false))
	}
	encoded, e := json.Marshal(results)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/specimen/overview.json.gz"), packFixture(encoded), 0644); e != nil {
		t.Fatal(e)
	}
}
