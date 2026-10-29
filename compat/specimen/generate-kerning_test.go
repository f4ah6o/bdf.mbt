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
	"os"
	"path/filepath"
	"testing"
)

func unpackForCodex(b []byte) ([]byte, error) {
	z, e := gzip.NewReader(bytes.NewReader(b))
	if e != nil {
		return nil, e
	}
	defer z.Close()
	return io.ReadAll(z)
}
func TestCodexKerning(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	results := []any{}
	add := func(name string, data []byte) {
		fl, e := load(data)
		if e != nil {
			t.Fatal(e)
		}
		for _, fc := range fl.faces {
			fc.prepare()
			results = append(results, map[string]any{"name": name, "input": packFixture(data), "index": fc.index, "result": fc.kerning()})
		}
	}
	for _, name := range []string{"stix.ttf", "stix.otf", "features.ttf", "variable.ttf", "color.ttf", "bold.ttc"} {
		b, e := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if e != nil {
			t.Fatal(e)
		}
		add(name, b)
	}
	originals := filepath.Join(root, "compat/gsub/gpos.json.gz")
	packed, e := os.ReadFile(originals)
	if e != nil {
		t.Fatal(e)
	}
	decoded, e := unpackForCodex(packed)
	if e != nil {
		t.Fatal(e)
	}
	var cases []struct {
		Name string `json:"name"`
		Data []byte `json:"data"`
	}
	if e = json.Unmarshal(decoded, &cases); e != nil {
		t.Fatal(e)
	}
	var raw []byte
	for _, v := range cases {
		if v.Name == "synthetic" {
			raw = v.Data
			break
		}
	}
	if raw == nil {
		t.Fatal("synthetic GPOS missing")
	}
	// A kern feature referencing both lookups of the synthetic GPOS table.
	f := make([]byte, 16)
	binary.BigEndian.PutUint16(f, 1)
	copy(f[2:], "kern")
	binary.BigEndian.PutUint16(f[6:], 8)
	binary.BigEndian.PutUint16(f[10:], 2)
	binary.BigEndian.PutUint16(f[12:], 0)
	binary.BigEndian.PutUint16(f[14:], 1)
	table := make([]byte, 10)
	binary.BigEndian.PutUint16(table, 1)
	binary.BigEndian.PutUint16(table[6:], 10)
	binary.BigEndian.PutUint16(table[8:], 26)
	table = append(table, f...)
	table = append(table, raw[10:]...)
	kern := make([]byte, 18)
	binary.BigEndian.PutUint16(kern[10:], 1234)
	for _, v := range []struct {
		name       string
		gpos, kern []byte
	}{{"gpos", table, nil}, {"legacy", nil, kern}, {"both", table, kern}, {"invalid-gpos", []byte{1, 2, 3}, kern}, {"empty", nil, nil}} {
		tables := map[string][]byte{"maxp": {0, 1, 0, 0, 0, 2}}
		if v.gpos != nil {
			tables["GPOS"] = v.gpos
		}
		if v.kern != nil {
			tables["kern"] = v.kern
		}
		add(v.name, sfnt.Build(tables, false))
	}
	encoded, e := json.Marshal(results)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/specimen/kerning.json.gz"), packFixture(encoded), 0644); e != nil {
		t.Fatal(e)
	}
}
