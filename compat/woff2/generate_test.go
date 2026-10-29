//go:build ignore

// Copy into upstream font/woff2 and run TestCodexWOFF2Decode.
package woff2

import (
	"bytes"
	"compress/gzip"
	"encoding/binary"
	"encoding/json"
	"io"
	"math/rand"
	"os"
	"path/filepath"
	"sort"
	"testing"
)

func TestCodexWOFF2Decode(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	inputs := map[string][]byte{}
	for _, name := range []string{"stix.ttf", "stix.otf", "features.ttf", "restricted.ttf", "variable.ttf", "color.ttf"} {
		data, err := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if err != nil {
			t.Fatal(err)
		}
		w, err := Encode(data)
		if err != nil {
			t.Fatal(name, err)
		}
		inputs[name] = w
	}
	for name, data := range testFonts(t) {
		w, err := Encode(data)
		if err != nil {
			t.Fatal(err)
		}
		inputs[name] = w
	}
	// A transformed hmtx table takes both bearings from rebuilt glyph xMin.
	hhea := make([]byte, 36)
	binary.BigEndian.PutUint16(hhea[34:], 1)
	maxp := make([]byte, 6)
	binary.BigEndian.PutUint16(maxp[4:], 2)
	glyf := make([]byte, 24)
	binary.BigEndian.PutUint16(glyf[2:], uint16(65536-40))
	binary.BigEndian.PutUint16(glyf[14:], 80)
	loca := make([]byte, 12)
	binary.BigEndian.PutUint32(loca[4:], 12)
	binary.BigEndian.PutUint32(loca[8:], 24)
	hmtx := []byte{3, 1, 244}
	var dir []byte
	for _, e := range []struct {
		flags       byte
		orig, trans int
		data        []byte
	}{{2, 36, 0, hhea}, {4, 6, 0, maxp}, {0xca, 24, 0, glyf}, {0xcb, 12, 0, loca}, {0x43, 6, 3, hmtx}} {
		dir = appendBase128(append(dir, e.flags), uint32(e.orig))
		if e.trans != 0 {
			dir = appendBase128(dir, uint32(e.trans))
		}
	}
	inputs["transformed-hmtx"] = packed(t, 5, dir, func(w io.Writer) { w.Write(hhea); w.Write(maxp); w.Write(glyf); w.Write(loca); w.Write(hmtx) })
	// Read at most the directory-declared table size, even if the stream is longer.
	inputs["long-stream"] = packed(t, 1, appendBase128([]byte{1}, 54), func(w io.Writer) { w.Write(bytes.Repeat([]byte{7}, 4096)) })
	inputs["empty-stream"] = packed(t, 0, nil, func(w io.Writer) {})
	extra := append([]byte(nil), inputs["stix.ttf"]...)
	extra = append(extra, 1, 2, 3)
	binary.BigEndian.PutUint32(extra[20:], binary.BigEndian.Uint32(extra[20:])+3)
	inputs["trailing-stream"] = extra
	cases := []any{}
	add := func(name string, data []byte) {
		out, err := Decode(data)
		cases = append(cases, map[string]any{"name": name, "input": data, "valid": err == nil, "output": out})
	}
	keys := []string{"stix.ttf", "stix.otf", "features.ttf", "restricted.ttf", "variable.ttf", "color.ttf", "transformed-hmtx", "long-stream", "empty-stream", "trailing-stream"}
	for _, name := range keys {
		add(name, inputs[name])
	}
	seen := map[string]bool{}
	for _, name := range keys {
		seen[name] = true
	}
	extraNames := []string{}
	for name := range inputs {
		if !seen[name] {
			extraNames = append(extraNames, name)
		}
	}
	sort.Strings(extraNames)
	for _, name := range extraNames {
		add(name, inputs[name])
	}
	rng := rand.New(rand.NewSource(651245))
	for i := 0; i < 180; i++ {
		base := inputs[keys[i%len(keys)]]
		data := append([]byte(nil), base...)
		if i%3 == 0 {
			data = data[:rng.Intn(len(data)+1)]
		} else {
			for j := 0; j < 1+rng.Intn(4); j++ {
				data[rng.Intn(len(data))] = byte(rng.Intn(256))
			}
		}
		add("mutation", data)
	}
	for _, data := range [][]byte{nil, []byte("wOF2"), make([]byte, 48), append([]byte("wOF2ttcf"), make([]byte, 40)...)} {
		add("invalid", data)
	}
	encoded, err := json.Marshal(cases)
	if err != nil {
		t.Fatal(err)
	}
	var out bytes.Buffer
	z := gzip.NewWriter(&out)
	if _, err = z.Write(encoded); err != nil {
		t.Fatal(err)
	}
	if err = z.Close(); err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/woff2/upstream.json.gz"), out.Bytes(), 0644); err != nil {
		t.Fatal(err)
	}
}
