//go:build ignore

// Copy into upstream font/woff2 and run TestCodexWOFF2EncodeInputs.
package woff2

import (
	"bytes"
	"compress/gzip"
	"crypto/sha256"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"sort"
	"testing"
)

func TestCodexWOFF2EncodeInputs(t *testing.T) {
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
		inputs[name] = data
	}
	for name, data := range testFonts(t) {
		inputs[name] = data
	}
	base := inputs["stix.ttf"]
	type bounds struct{ offset, size int }
	ranges := []bounds{}
	for i := 0; i < int(binary.BigEndian.Uint16(base[4:])); i++ {
		rec := 12 + i*16
		tag := string(base[rec : rec+4])
		if tag == "glyf" || tag == "loca" || tag == "head" {
			ranges = append(ranges, bounds{int(binary.BigEndian.Uint32(base[rec+8:])), int(binary.BigEndian.Uint32(base[rec+12:]))})
		}
	}
	patches := map[string][][2]int{}
	rng := rand.New(rand.NewSource(918274))
	for i := 0; i < 96; i++ {
		data := append([]byte(nil), base...)
		name := fmt.Sprintf("mutation-%03d", i)
		for j := 0; j < 1+rng.Intn(4); j++ {
			r := ranges[rng.Intn(len(ranges))]
			pos, value := r.offset+rng.Intn(r.size), 1+rng.Intn(255)
			data[pos] ^= byte(value)
			patches[name] = append(patches[name], [2]int{pos, value})
		}
		inputs[name] = data
	}
	head := make([]byte, 54)
	binary.BigEndian.PutUint16(head[50:], 1)
	maxp := make([]byte, 6)
	loca := []byte{0xff, 0xff, 0xff, 0xff}
	inputs["zero-glyph-offset"] = buildSFNT(0x00010000, map[string][]byte{"head": head, "maxp": maxp, "glyf": {}, "loca": loca})
	inputs["short"] = []byte("hello")
	inputs["invalid"] = make([]byte, 20)
	inputs["truncated"] = append([]byte{0, 1, 0, 0, 0, 1}, make([]byte, 6)...)
	badTable := make([]byte, 28)
	copy(badTable, []byte{0, 1, 0, 0, 0, 1})
	copy(badTable[12:], "head")
	binary.BigEndian.PutUint32(badTable[20:], 29)
	inputs["bad-table"] = badTable
	keys := []string{}
	for name := range inputs {
		keys = append(keys, name)
	}
	sort.Strings(keys)
	cases := []any{}
	for _, name := range keys {
		input := inputs[name]
		encoded, err := Encode(input)
		message := ""
		var expected []byte
		if err != nil {
			message = err.Error()
		} else {
			expected, err = Decode(encoded)
			if err != nil {
				t.Fatal(name, err)
			}
		}
		if patch, ok := patches[name]; ok {
			hash := sha256.Sum256(expected)
			cases = append(cases, map[string]any{"name": name, "base": "stix.ttf", "patches": patch, "error": message, "decodedHash": fmt.Sprintf("%x", hash)})
		} else {
			cases = append(cases, map[string]any{"name": name, "input": input, "error": message, "encoded": encoded, "decoded": expected})
		}
	}
	data, err := json.Marshal(cases)
	if err != nil {
		t.Fatal(err)
	}
	var out bytes.Buffer
	z := gzip.NewWriter(&out)
	if _, err = z.Write(data); err != nil {
		t.Fatal(err)
	}
	if err = z.Close(); err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/woff2/encode.json.gz"), out.Bytes(), 0644); err != nil {
		t.Fatal(err)
	}
}
