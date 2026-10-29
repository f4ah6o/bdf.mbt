//go:build ignore

// Copy into the upstream converter/font package with generate_test.go.
package font

import (
	"bytes"
	"encoding/binary"
	"encoding/json"
	"github.com/shibukawa/bdf/internal/sfnt"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

type codexName struct {
	platform, encoding, language, id uint16
	text                             []byte
}

func codexNameTable(records []codexName, tags ...[]byte) []byte {
	header := 6 + 12*len(records)
	if tags != nil {
		header += 2 + 4*len(tags)
	}
	if header > 65535 {
		panic("name table header too large")
	}
	b := make([]byte, header)
	if tags != nil {
		binary.BigEndian.PutUint16(b, 1)
	}
	binary.BigEndian.PutUint16(b[2:], uint16(len(records)))
	binary.BigEndian.PutUint16(b[4:], uint16(header))
	put := func(rec int, text []byte) {
		if len(b)-header > 65535 || len(text) > 65535 {
			panic("string data too large")
		}
		binary.BigEndian.PutUint16(b[rec:], uint16(len(text)))
		binary.BigEndian.PutUint16(b[rec+2:], uint16(len(b)-header))
		b = append(b, text...)
	}
	for i, r := range records {
		p := 6 + i*12
		binary.BigEndian.PutUint16(b[p:], r.platform)
		binary.BigEndian.PutUint16(b[p+2:], r.encoding)
		binary.BigEndian.PutUint16(b[p+4:], r.language)
		binary.BigEndian.PutUint16(b[p+6:], r.id)
		put(p+8, r.text)
	}
	if tags != nil {
		p := 6 + len(records)*12
		binary.BigEndian.PutUint16(b[p:], uint16(len(tags)))
		for i, tag := range tags {
			put(p+2+i*4, tag)
		}
	}
	return b
}
func TestCodexNameRecords(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	results := []any{}
	add := func(name string, data []byte) {
		rs, cut := parseNames(data)
		fc := face{names: rs}
		out := []any{}
		for _, r := range rs {
			out = append(out, map[string]any{"id": r.id, "lang": r.lang, "english": r.en, "text": r.text, "rank": r.rank})
		}
		best := []string{}
		locals := []any{}
		for i := uint16(0); i < 30; i++ {
			best = append(best, fc.name(i))
			list := []any{}
			for _, r := range fc.localNames(i) {
				list = append(list, map[string]any{"id": r.id, "lang": r.lang, "english": r.en, "text": r.text, "rank": r.rank})
			}
			locals = append(locals, list)
		}
		results = append(results, map[string]any{"name": name, "input": data, "records": out, "cut": cut, "best": best, "locals": locals, "family": fc.family(), "full": fc.fullName()})
	}
	for _, name := range []string{"stix.ttf", "stix.otf", "features.ttf", "variable.ttf", "color.ttf"} {
		b, e := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if e != nil {
			t.Fatal(e)
		}
		f, e := sfnt.Parse(b)
		if e != nil {
			t.Fatal(e)
		}
		add(name, f.Tables["name"])
	}
	add("format1", codexNameTable([]codexName{{3, 1, 0x409, 1, []byte{0, 'A', 0, 'B'}}, {0, 0, 0x8000, 1, []byte{0, 'X'}}, {3, 1, 0x8001, 1, []byte{0, 'Y'}}, {1, 0, 0, 2, []byte("Regular")}, {0, 0, 7, 4, []byte{0, 'T', 0, '\x00'}}, {3, 1, 0x411, 1, []byte{0, 'X'}}, {3, 1, 0x411, 1, []byte{0, 'X'}}}, []byte{0, 'j', 0, 'a'}, []byte{0, 'f', 0, 'r'}))
	add("malformed-surrogates", codexNameTable([]codexName{{3, 1, 0x409, 1, []byte{0xd8, 0, 0, 'a', 0xdc, 0, 0}}, {0, 0, 0xffff, 9, []byte{0, 'A'}}, {9, 1, 0x409, 1, []byte("bad")}, {3, 6, 0x409, 1, []byte{0, 'a'}}}))
	rng := rand.New(rand.NewSource(7821))
	for _, p := range []struct {
		pid, eid uint16
		name     string
		wide     bool
	}{{1, 0, "mac", false}, {1, 1, "mac-japanese", false}, {1, 2, "mac-chinese", false}, {1, 3, "mac-korean", false}, {1, 25, "mac-gbk", false}, {3, 2, "win-japanese", true}, {3, 3, "win-gbk", true}, {3, 4, "win-big5", true}, {3, 5, "win-korean", true}} {
		records := []codexName{}
		for i := 0; i < 1000; i++ {
			n := 1 + rng.Intn(5)
			raw := make([]byte, n)
			rng.Read(raw)
			if p.wide {
				wide := []byte{}
				for _, c := range raw {
					wide = append(wide, 0, c)
				}
				raw = wide
			}
			records = append(records, codexName{p.pid, p.eid, uint16(0x400 + rng.Intn(50)), uint16(i % 30), raw})
		}
		add(p.name, codexNameTable(records))
	}
	repeated := codexNameTable([]codexName{{3, 1, 0x409, 1, bytes.Repeat([]byte{0, 'A'}, 32767)}})
	// Repeat valid references to the same long string to cross the 4 MiB limit.
	long := make([]byte, 6+100*12)
	binary.BigEndian.PutUint16(long[2:], 100)
	binary.BigEndian.PutUint16(long[4:], uint16(len(long)))
	for i := 0; i < 100; i++ {
		copy(long[6+i*12:], repeated[6:18])
	}
	long = append(long, repeated[18:]...)
	add("limit", long)
	encoded, e := json.Marshal(results)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/specimen/names.json.gz"), packFixture(encoded), 0644); e != nil {
		t.Fatal(e)
	}
}
