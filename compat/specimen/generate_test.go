//go:build ignore

// Copy into the upstream converter/font package and run TestCodexGlyphPrograms.
package font

import (
	"bytes"
	"compress/gzip"
	"crypto/sha256"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"testing"

	"github.com/shibukawa/bdf/internal/sfnt"
)

func packFixture(data []byte) []byte {
	var out bytes.Buffer
	w := gzip.NewWriter(&out)
	if _, e := w.Write(data); e != nil {
		panic(e)
	}
	if e := w.Close(); e != nil {
		panic(e)
	}
	return out.Bytes()
}
func digest(data []byte) string { sum := sha256.Sum256(data); return fmt.Sprintf("%x", sum) }

func sbixFixture(glyphs int, ppems []int, bad bool) []byte {
	data := make([]byte, 8+len(ppems)*4)
	binary.BigEndian.PutUint16(data, 1)
	binary.BigEndian.PutUint32(data[4:], uint32(len(ppems)))
	for i, ppem := range ppems {
		off := len(data)
		binary.BigEndian.PutUint32(data[8+i*4:], uint32(off))
		s := make([]byte, 4+4*(glyphs+1))
		binary.BigEndian.PutUint16(s, uint16(ppem))
		binary.BigEndian.PutUint16(s[2:], 72)
		for j := 0; j <= glyphs; j++ {
			binary.BigEndian.PutUint32(s[4+4*j:], uint32(len(s)))
		}
		data = append(data, s...)
	}
	if bad && len(ppems) > 1 {
		binary.BigEndian.PutUint32(data[12:], uint32(len(data)+4))
	}
	return data
}
func TestCodexGlyphPrograms(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	results := []any{}
	add := func(name string, data []byte, index int) {
		fl, e := load(data)
		if e != nil {
			t.Fatal(name, e)
		}
		for _, fc := range fl.faces {
			if fc.index == index {
				out := glyphProgram(fc)
				sample, ok := sampleProgram(fc, "", false)
				pruned := []any{}
				if fc.f.Tables["glyf"] != nil {
					fc.prepare()
					for _, text := range []string{"", "Hello", "ffi", "漢字", "ABC ◌ -"} {
						reached := fc.reach(text)
						keep := []int{}
						for g := range reached {
							keep = append(keep, int(g))
						}
						sort.Ints(keep)
						out, ok := sampleProgram(fc, text, true)
						entry := map[string]any{"text": text, "keep": keep, "hash": digest(out), "size": len(out), "ok": ok}
						if text == "ffi" && (name == "stix.ttf" || name == "features.ttf") {
							entry["visual"] = packFixture(out)
						}
						pruned = append(pruned, entry)
					}
				}
				record := map[string]any{"name": name, "index": index, "input": packFixture(data), "outputHash": digest(out), "outputSize": len(out), "sampleHash": digest(sample), "sampleSize": len(sample), "sampleOK": ok, "pruned": pruned}
				if name == "stix.ttf" || name == "stix.otf" || name == "features.ttf" || name == "color.ttf" {
					record["visual"] = packFixture(out)
				}
				results = append(results, record)
				return
			}
		}
		t.Fatal(name, "face missing")
	}
	for _, name := range []string{"stix.ttf", "stix.otf", "features.ttf", "restricted.ttf", "variable.ttf", "color.ttf"} {
		data, e := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if e != nil {
			t.Fatal(e)
		}
		add(name, data, 0)
	}
	ttc, e := os.ReadFile(filepath.Join(root, "compat/font/fixtures/bold.ttc"))
	if e != nil {
		t.Fatal(e)
	}
	add("regular-ttc", ttc, 0)
	add("bold-ttc", ttc, 1)
	cff, e := os.ReadFile(filepath.Join(root, "compat/font/fixtures/stix.otf"))
	if e != nil {
		t.Fatal(e)
	}
	cff = append([]byte(nil), cff...)
	binary.BigEndian.PutUint32(cff, 0x00010000)
	add("cff-truetype-flavor", cff, 0)
	fontdata, e := os.ReadFile(filepath.Join(root, "compat/font/fixtures/stix.ttf"))
	if e != nil {
		t.Fatal(e)
	}
	f, e := sfnt.Parse(fontdata)
	if e != nil {
		t.Fatal(e)
	}
	for i, ppems := range [][]int{{32, 96, 128}, {96, 128, 64}, {48, 32, 16}, {64}, {16, 96, 64, 128}} {
		tables := map[string][]byte{}
		for k, v := range f.Tables {
			tables[k] = v
		}
		tables["sbix"] = sbixFixture(f.NumGlyphs, ppems, false)
		add(fmt.Sprintf("sbix-%d", i), sfnt.Build(tables, false), 0)
	}
	for _, keepCFF2 := range []bool{false, true} {
		tables := map[string][]byte{}
		for k, v := range f.Tables {
			tables[k] = v
		}
		for _, tag := range []string{"fvar", "avar", "gvar", "GSUB", "GPOS", "vhea", "STAT"} {
			tables[tag] = []byte{1, 2, 3, 4}
		}
		if keepCFF2 {
			tables["CFF2"] = []byte{1, 2, 3, 4}
		}
		tables["post"] = []byte{1, 2, 3, 4}
		add(fmt.Sprintf("variation-cff2-%v", keepCFF2), sfnt.Build(tables, false), 0)
	}
	var woffs []struct {
		Name  string `json:"name"`
		Input []byte `json:"input"`
	}
	woffFile, e := os.ReadFile(filepath.Join(root, "compat/woff/upstream.json"))
	if e != nil {
		t.Fatal(e)
	}
	if e = json.Unmarshal(woffFile, &woffs); e != nil {
		t.Fatal(e)
	}
	for _, w := range woffs {
		if w.Name == "stix.ttf-compressed" {
			zr, e := gzip.NewReader(bytes.NewReader(w.Input))
			if e != nil {
				t.Fatal(e)
			}
			raw, e := io.ReadAll(zr)
			if e != nil {
				t.Fatal(e)
			}
			if e = zr.Close(); e != nil {
				t.Fatal(e)
			}
			add("woff-input", raw, 0)
			break
		}
	}
	largeMaxp := []byte{0, 1, 0, 0, 0xff, 0xff}
	add("maximum-glyphs", sfnt.Build(map[string][]byte{"maxp": largeMaxp}, false), 0)
	tables := map[string][]byte{}
	for k, v := range f.Tables {
		tables[k] = v
	}
	tables["sbix"] = sbixFixture(f.NumGlyphs, []int{32, 64}, true)
	add("sbix-invalid", sfnt.Build(tables, false), 0)
	aatTables := map[string][]byte{}
	for k, v := range f.Tables {
		aatTables[k] = v
	}
	aatTables["morx"] = []byte{1, 2, 3, 4}
	aatFont := sfnt.Build(aatTables, false)
	add("aat-whole", aatFont, 0)
	add("aat-oversized", append(append([]byte(nil), aatFont...), make([]byte, 4<<20)...), 0)
	large := append(append([]byte(nil), fontdata...), make([]byte, 4<<20)...)
	add("oversized-whole-sample", large, 0)
	bitmapTables := map[string][]byte{}
	for k, v := range f.Tables {
		bitmapTables[k] = v
	}
	bitmapTables["SVG "] = make([]byte, (1<<20)+1)
	add("oversized-bitmap", sfnt.Build(bitmapTables, false), 0)
	encoded, e := json.Marshal(results)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/specimen/upstream.json.gz"), packFixture(encoded), 0644); e != nil {
		t.Fatal(e)
	}
}
