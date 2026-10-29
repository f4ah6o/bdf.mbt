//go:build ignore

// Copy into the upstream converter/font package and run TestCodexFontInput.
package font

import (
	"bytes"
	"compress/gzip"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"math/rand"
	"os"
	"path/filepath"
	"testing"

	"github.com/shibukawa/bdf/internal/sfnt"
)

func compressFixture(b []byte) []byte {
	var out bytes.Buffer
	w := gzip.NewWriter(&out)
	if _, err := w.Write(b); err != nil {
		panic(err)
	}
	if err := w.Close(); err != nil {
		panic(err)
	}
	return out.Bytes()
}
func inflatedFixture(b []byte) []byte {
	r, e := gzip.NewReader(bytes.NewReader(b))
	if e != nil {
		panic(e)
	}
	out, e := io.ReadAll(r)
	if e != nil {
		panic(e)
	}
	if e = r.Close(); e != nil {
		panic(e)
	}
	return out
}

func TestCodexFontInput(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	type sample struct {
		Name  string `json:"name"`
		Input []byte `json:"input"`
	}
	var woffs []sample
	raw, e := os.ReadFile(filepath.Join(root, "compat/woff/upstream.json"))
	if e != nil {
		t.Fatal(e)
	}
	if e = json.Unmarshal(raw, &woffs); e != nil {
		t.Fatal(e)
	}
	data := []struct {
		name  string
		bytes []byte
	}{}
	for _, name := range []string{"stix.ttf", "stix.otf", "bold.ttc", "restricted.ttf"} {
		b, e := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if e != nil {
			t.Fatal(e)
		}
		data = append(data, struct {
			name  string
			bytes []byte
		}{name, b})
	}
	for _, w := range woffs {
		if w.Name == "stix.ttf-compressed" {
			data = append(data, struct {
				name  string
				bytes []byte
			}{w.Name, inflatedFixture(w.Input)})
			break
		}
	}
	data = append(data, struct {
		name  string
		bytes []byte
	}{"empty", nil}, struct {
		name  string
		bytes []byte
	}{"woff2", []byte("wOF2abcdefghijkl")}, struct {
		name  string
		bytes []byte
	}{"invalid", []byte("abcdefghijkl")}, struct {
		name  string
		bytes []byte
	}{"short-ttc", []byte{'t', 't', 'c', 'f', 0, 1, 0, 0, 0, 0, 0, 1}})
	shortWOFF2 := make([]byte, 50)
	copy(shortWOFF2, "wOF2")
	binary.BigEndian.PutUint32(shortWOFF2[4:], 0x00010000)
	binary.BigEndian.PutUint16(shortWOFF2[12:], 1)
	shortWOFF2[48], shortWOFF2[49] = 4, 3 // maxp, length 3, no transformed stream
	data = append(data, struct {
		name  string
		bytes []byte
	}{"woff2-valid-directory", shortWOFF2})
	woffsRng := rand.New(rand.NewSource(9283))
	for i := 0; i < 400; i++ {
		mutated := append([]byte(nil), shortWOFF2...)
		for j := 0; j < 1+woffsRng.Intn(3); j++ {
			position := 4 + woffsRng.Intn(len(mutated)-4)
			mutated[position] ^= byte(1 + woffsRng.Intn(255))
		}
		data = append(data, struct {
			name  string
			bytes []byte
		}{fmt.Sprintf("woff2-mutation-%d", i), mutated})
	}
	// A name table repeatedly refers to an invalid Macintosh string: upstream
	// counts every attempted notice against its 4 MiB input budget.
	nameTable := make([]byte, 6+100*12+60000)
	binary.BigEndian.PutUint16(nameTable[2:], 100)
	binary.BigEndian.PutUint16(nameTable[4:], 1206)
	for i := 0; i < 100; i++ {
		rec := 6 + i*12
		binary.BigEndian.PutUint16(nameTable[rec:], 1)
		binary.BigEndian.PutUint16(nameTable[rec+8:], 60000)
	}
	for i := 1206; i < len(nameTable); i++ {
		nameTable[i] = 0xa9
	}
	maxpTable := []byte{0, 1, 0, 0, 0, 2}
	data = append(data, struct {
		name  string
		bytes []byte
	}{"notice-budget", sfnt.Build(map[string][]byte{"name": nameTable, "maxp": maxpTable}, false)})
	// Six faces with 65,535 glyphs exercise the automatic glyph limit.
	n := 6
	many := make([]byte, 12+4*n+28*n+6)
	copy(many, "ttcf")
	binary.BigEndian.PutUint32(many[4:], 0x00010000)
	binary.BigEndian.PutUint32(many[8:], uint32(n))
	maxp := len(many) - 6
	binary.BigEndian.PutUint32(many[maxp:], 0x00010000)
	binary.BigEndian.PutUint16(many[maxp+4:], 65535)
	for i := 0; i < n; i++ {
		off := 12 + 4*n + 28*i
		binary.BigEndian.PutUint32(many[12+4*i:], uint32(off))
		binary.BigEndian.PutUint32(many[off:], 0x00010000)
		binary.BigEndian.PutUint16(many[off+4:], 1)
		copy(many[off+12:], "maxp")
		binary.BigEndian.PutUint32(many[off+20:], uint32(maxp))
		binary.BigEndian.PutUint32(many[off+24:], 6)
	}
	data = append(data, struct {
		name  string
		bytes []byte
	}{"large-collection", many})
	selections := []string{"", "all", "1", "2", "1,1", "  +1  , 2", "0", "-1", "3", "all,1", "1,", " ", "１２", "9223372036854775808", "-9223372036854775808", "01", "+0", "-0", "1_0", "0x1", "--1", "\t1\u00a0", " 2 ", "1,,2", "1\n2", "\""}
	results := []any{}
	for _, d := range data {
		fl, err := load(d.bytes)
		record := map[string]any{"name": d.name, "input": compressFixture(d.bytes), "detect": detect(d.bytes), "error": ""}
		if err != nil {
			record["error"] = err.Error()
			results = append(results, record)
			continue
		}
		record["container"], record["collection"], record["size"] = fl.container, fl.collection, fl.size
		faces := []any{}
		for _, face := range fl.faces {
			faces = append(faces, map[string]any{"index": face.index, "size": face.size, "glyphs": face.f.NumGlyphs})
		}
		record["faces"] = faces
		choices := []any{}
		for _, spec := range selections {
			warnings := []string{}
			c := &converter{fl: fl, warn: func(s string) { warnings = append(warnings, s) }}
			selected, err := c.selectFaces(spec)
			indexes := []int{}
			for _, face := range selected {
				indexes = append(indexes, face.index)
			}
			msg := ""
			if err != nil {
				msg = err.Error()
			}
			choices = append(choices, map[string]any{"spec": spec, "indexes": indexes, "warnings": warnings, "error": msg})
		}
		record["choices"] = choices
		results = append(results, record)
	}
	detects := []any{}
	rng := rand.New(rand.NewSource(503))
	for i := 0; i < 600; i++ {
		source := data[i%4].bytes
		size := rng.Intn(160)
		if size > len(source) {
			size = len(source)
		}
		b := append([]byte(nil), source[:size]...)
		for j := 0; j < rng.Intn(4) && len(b) > 0; j++ {
			p := rng.Intn(len(b))
			b[p] ^= byte(1 + rng.Intn(255))
		}
		detects = append(detects, map[string]any{"input": b, "result": detect(b)})
	}
	encoded, e := json.Marshal(map[string]any{"files": results, "detect": detects})
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/fontinput/upstream.json"), append(encoded, '\n'), 0644); e != nil {
		t.Fatal(e)
	}
	fmt.Println("generated", len(results), "files and", len(detects), "detection cases")
}
