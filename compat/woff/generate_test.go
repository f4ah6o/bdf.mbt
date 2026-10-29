//go:build ignore

// Copy into the upstream converter/font package and run TestCodexWOFFFixtures.
package font

import (
	"bytes"
	"compress/gzip"
	"compress/zlib"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"sort"
	"testing"

	"github.com/shibukawa/bdf/internal/sfnt"
)

func zipped(b []byte) []byte {
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

func makeWOFF(input []byte, mixed bool) []byte {
	font, err := sfnt.Parse(input)
	if err != nil {
		panic(err)
	}
	tags := make([]string, 0, len(font.Tables))
	for tag := range font.Tables {
		tags = append(tags, tag)
	}
	sort.Strings(tags)
	out := make([]byte, 44+20*len(tags))
	copy(out, "wOFF")
	copy(out[4:8], input[:4])
	binary.BigEndian.PutUint16(out[12:], uint16(len(tags)))
	for i, tag := range tags {
		raw := font.Tables[tag]
		var z bytes.Buffer
		w := zlib.NewWriter(&z)
		if _, err := w.Write(raw); err != nil {
			panic(err)
		}
		if err := w.Close(); err != nil {
			panic(err)
		}
		compressed := z.Bytes()
		if len(compressed) >= len(raw) || mixed && i%2 == 0 {
			compressed = raw
		}
		rec := 44 + 20*i
		copy(out[rec:], tag)
		binary.BigEndian.PutUint32(out[rec+4:], uint32(len(out)))
		binary.BigEndian.PutUint32(out[rec+8:], uint32(len(compressed)))
		binary.BigEndian.PutUint32(out[rec+12:], uint32(len(raw)))
		out = append(out, compressed...)
		for len(out)%4 != 0 {
			out = append(out, 0)
		}
	}
	binary.BigEndian.PutUint32(out[8:], uint32(len(out)))
	binary.BigEndian.PutUint32(out[16:], uint32(len(input)))
	return out
}

func TestCodexWOFFFixtures(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	var samples []map[string]any
	add := func(name string, data []byte) {
		out, err := unWOFF(data)
		msg := ""
		if err != nil {
			msg = err.Error()
		}
		samples = append(samples, map[string]any{"name": name, "input": zipped(data), "output": zipped(out), "error": msg})
	}
	for _, file := range []string{"stix.ttf", "stix.otf", "features.ttf", "restricted.ttf"} {
		input, err := os.ReadFile(filepath.Join(root, "compat/font/fixtures", file))
		if err != nil {
			t.Fatal(err)
		}
		add(file+"-compressed", makeWOFF(input, false))
		add(file+"-mixed", makeWOFF(input, true))
	}
	for _, n := range []int{0, 1, 11, 43} {
		add("short", make([]byte, n))
	}
	empty := make([]byte, 44)
	copy(empty, "wOFF")
	add("no-tables", empty)
	raw := bytes.Repeat([]byte("ABCDEF"), 128)
	var packed bytes.Buffer
	zw := zlib.NewWriter(&packed)
	if _, err := zw.Write(raw); err != nil {
		t.Fatal(err)
	}
	if err := zw.Close(); err != nil {
		t.Fatal(err)
	}
	small := make([]byte, 64)
	copy(small, "wOFF")
	binary.BigEndian.PutUint32(small[4:], 0x00010000)
	binary.BigEndian.PutUint16(small[12:], 1)
	copy(small[44:], "test")
	binary.BigEndian.PutUint32(small[48:], 64)
	binary.BigEndian.PutUint32(small[52:], uint32(packed.Len()))
	binary.BigEndian.PutUint32(small[56:], uint32(len(raw)))
	small = append(small, packed.Bytes()...)
	rng := rand.New(rand.NewSource(81279))
	for i := 0; i < 500; i++ {
		mutated := append([]byte(nil), small...)
		for j := 0; j < 1+rng.Intn(3); j++ {
			position := rng.Intn(len(mutated))
			if position >= 44 && position < 48 {
				continue
			}
			mutated[position] ^= byte(1 + rng.Intn(255))
		}
		add(fmt.Sprintf("mutation-%d", i), mutated)
	}
	many := make([]byte, 44+5000*20)
	copy(many, "wOFF")
	binary.BigEndian.PutUint16(many[12:], 5000)
	for i := 0; i < 5000; i++ {
		rec := 44 + 20*i
		binary.BigEndian.PutUint32(many[rec:], uint32(i))
		binary.BigEndian.PutUint32(many[rec+4:], uint32(len(many)))
	}
	add("many-tables", many)
	basic := make([]byte, 64)
	copy(basic, "wOFF")
	binary.BigEndian.PutUint16(basic[12:], 1)
	copy(basic[44:], "name")
	binary.BigEndian.PutUint32(basic[48:], 64)
	broken := append([]byte(nil), basic...)
	copy(broken[4:], "ttcf")
	add("collection", broken)
	broken = append([]byte(nil), basic[:44]...)
	add("directory", broken)
	for _, header := range [][]byte{{}, {0x78}, {0, 0}, {0x78, 0x20}, {0x78, 0x20, 0, 0, 0, 0}, {0x78, 0x20, 0, 0, 0, 1}} {
		bad := append([]byte(nil), basic...)
		binary.BigEndian.PutUint32(bad[52:], uint32(len(header)))
		binary.BigEndian.PutUint32(bad[56:], 64)
		bad = append(bad, header...)
		add("zlib-dictionary-header", bad)
	}
	withDict := append([]byte{0x78, 0x20, 0, 0, 0, 1}, packed.Bytes()[2:]...)
	dictFont := append([]byte(nil), small[:64]...)
	binary.BigEndian.PutUint32(dictFont[52:], uint32(len(withDict)))
	dictFont = append(dictFont, withDict...)
	add("zlib-empty-dictionary", dictFont)
	for _, tag := range [][]byte{{'n', '"', '\\', '\n'}, {0xff, 0, 0x7f, 'x'}, {0xc3, 0xa9, 'x', 'y'}, {0xc2, 0x85, 'x', 'y'}, {0xf0, 0x9f, 0x98, 0x80}} {
		bad := append([]byte(nil), basic...)
		copy(bad[44:], tag)
		binary.BigEndian.PutUint32(bad[48:], 65)
		add("quoted-tag", bad)
	}
	broken = append([]byte(nil), basic...)
	binary.BigEndian.PutUint32(broken[48:], 65)
	add("offset", broken)
	broken = append([]byte(nil), basic...)
	binary.BigEndian.PutUint32(broken[56:], 268435457)
	add("total", broken)
	broken = append([]byte(nil), basic...)
	binary.BigEndian.PutUint32(broken[52:], 1)
	binary.BigEndian.PutUint32(broken[56:], 4)
	broken = append(broken, 1)
	add("zlib-header", broken)
	source, err := os.ReadFile(filepath.Join(root, "compat/font/fixtures/stix.ttf"))
	if err != nil {
		t.Fatal(err)
	}
	original := makeWOFF(source, false)
	for i := 0; i < int(binary.BigEndian.Uint16(original[12:])); i++ {
		rec := 44 + i*20
		comp := int(binary.BigEndian.Uint32(original[rec+8:]))
		orig := int(binary.BigEndian.Uint32(original[rec+12:]))
		off := int(binary.BigEndian.Uint32(original[rec+4:]))
		if comp < orig && comp > 6 {
			broken = append([]byte(nil), original...)
			broken[off+comp-1] ^= 1
			add("checksum", broken)
			broken = append([]byte(nil), original...)
			binary.BigEndian.PutUint32(broken[rec+8:], uint32(comp-1))
			add("truncated-zlib", broken)
			break
		}
	}
	encoded, err := json.Marshal(samples)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/woff/upstream.json"), append(encoded, '\n'), 0644); err != nil {
		t.Fatal(err)
	}
}
