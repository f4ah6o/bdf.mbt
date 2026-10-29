//go:build ignore

// Copy into the upstream converter/font package with generate_test.go.
package font

import (
	"encoding/binary"
	"encoding/json"
	"github.com/shibukawa/bdf/internal/sfnt"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexGlyphNames(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	results := []any{}
	add := func(name string, data []byte, index int) {
		f, err := sfnt.ParseIndex(data, index)
		if err != nil {
			t.Fatal(name, err)
		}
		results = append(results, map[string]any{"name": name, "index": index, "input": packFixture(data), "names": glyphNames(f)})
	}
	for _, name := range []string{"stix.ttf", "stix.otf", "features.ttf", "variable.ttf", "color.ttf"} {
		data, err := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if err != nil {
			t.Fatal(err)
		}
		add(name, data, 0)
	}
	ttc, err := os.ReadFile(filepath.Join(root, "compat/font/fixtures/bold.ttc"))
	if err != nil {
		t.Fatal(err)
	}
	add("collection-0", ttc, 0)
	add("collection-1", ttc, 1)
	var synthetic []struct {
		Name string `json:"name"`
		Data []byte `json:"data"`
	}
	buf, err := os.ReadFile(filepath.Join(root, "compat/cff/synthetic.json"))
	if err != nil {
		t.Fatal(err)
	}
	if err = json.Unmarshal(buf, &synthetic); err != nil {
		t.Fatal(err)
	}
	for _, x := range synthetic {
		tables := map[string][]byte{"maxp": {0, 1, 0, 0, 0, 8}, "CFF ": x.Data}
		add("cff-"+x.Name, sfnt.Build(tables, true), 0)
	}
	makePost := func(indexes []uint16, names ...string) []byte {
		b := make([]byte, 34+2*len(indexes))
		binary.BigEndian.PutUint32(b, 0x00020000)
		binary.BigEndian.PutUint16(b[32:], uint16(len(indexes)))
		for i, v := range indexes {
			binary.BigEndian.PutUint16(b[34+2*i:], v)
		}
		for _, s := range names {
			b = append(b, byte(len(s)))
			b = append(b, []byte(s)...)
		}
		return b
	}
	for _, tc := range []struct {
		name string
		post []byte
	}{
		{"standard", makePost([]uint16{0, 1, 2, 3, 4, 257})},
		{"duplicates", makePost([]uint16{36, 36, 258, 259, 258, 260}, "X", "X", "custom")},
		{"out-of-range", makePost([]uint16{1000, 259, 258, 260}, "local")},
		{"empty", makePost(nil)},
		{"invalid-utf8", makePost([]uint16{258, 259, 260, 258}, string([]byte{0xff}), string([]byte{0xfe}), string([]byte{0xff}))},
		{"truncated", append(makePost([]uint16{258, 259}, "ok"), 5, 'x')},
		{"short-index", append(makePost(nil), 0, 0)},
	} {
		add("post-"+tc.name, sfnt.Build(map[string][]byte{"maxp": {0, 1, 0, 0, 0, 5}, "post": tc.post}, false), 0)
	}
	cff := synthetic[0].Data
	for _, post := range [][]byte{makePost(nil), makePost([]uint16{258}), makePost([]uint16{0})} {
		add("post-cff", sfnt.Build(map[string][]byte{"maxp": {0, 1, 0, 0, 0, 5}, "post": post, "CFF ": cff}, true), 0)
	}
	encoded, err := json.Marshal(results)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/specimen/glyphnames.json.gz"), packFixture(encoded), 0644); err != nil {
		t.Fatal(err)
	}
}
