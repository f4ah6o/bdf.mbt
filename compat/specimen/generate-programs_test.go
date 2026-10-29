//go:build ignore

// Copy into upstream converter/font alongside generate_test.go.
package font

import (
	"crypto/sha256"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/shibukawa/bdf"
	conv "github.com/shibukawa/bdf/converter"
	"github.com/shibukawa/bdf/internal/sfnt"
)

func TestCodexSpecimenPrograms(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	results := []any{}
	inputs := map[string][]byte{}
	add := func(name string, raw []byte, selection, text string, ignore bool) {
		fl, err := load(raw)
		if err != nil {
			t.Fatal(name, err)
		}
		warnings := []string{}
		doc := bdf.NewDocument()
		c := &converter{o: &conv.Options{NoWOFF2: true, IgnoreFSType: ignore}, doc: doc, fl: fl, warn: func(s string) { warnings = append(warnings, s) }}
		faces, err := c.selectFaces(selection)
		if err != nil {
			t.Fatal(err)
		}
		out := []any{}
		for _, fc := range faces {
			fc.prepare()
			c.plan = fc.plan(text)
			p := c.painterFor(fc)
			var glyph, sample any
			if p.glyphFont != nil {
				glyph = p.glyphFont.Hash.String()
			}
			if p.sampleFont != nil {
				sample = p.sampleFont.Hash.String()
			}
			out = append(out, map[string]any{"index": fc.index, "glyph": glyph, "sample": sample, "outlined": p.glyphFont == nil})
		}
		key := fmt.Sprintf("%x", sha256.Sum256(raw))
		if _, ok := inputs[key]; !ok {
			inputs[key] = packFixture(raw)
		}
		results = append(results, map[string]any{"name": name, "input": key, "selection": selection, "text": text, "ignore": ignore, "faces": out, "warnings": warnings, "fontParts": c.fontParts, "outlined": c.outlined})
	}
	for _, name := range []string{"stix.ttf", "stix.otf", "features.ttf", "restricted.ttf", "variable.ttf", "color.ttf", "bold.ttc"} {
		raw, err := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if err != nil {
			t.Fatal(err)
		}
		for _, ignore := range []bool{false, true} {
			for _, text := range []string{"", "Hello ffi", "漢字"} {
				add(name, raw, "", text, ignore)
			}
		}
		if name == "bold.ttc" {
			for _, selection := range []string{"all", "1,1", "2,1,2"} {
				add(name, raw, selection, "Hello", false)
			}
		}
	}
	raw, err := os.ReadFile(filepath.Join(root, "compat/font/fixtures/stix.ttf"))
	if err != nil {
		t.Fatal(err)
	}
	f, err := sfnt.Parse(raw)
	if err != nil {
		t.Fatal(err)
	}
	for _, flags := range []uint16{0, 2, 4, 0x100, 0x200, 0x102, 0x104, 0x300} {
		tables := map[string][]byte{}
		for k, v := range f.Tables {
			tables[k] = v
		}
		os2 := append([]byte(nil), tables["OS/2"]...)
		binary.BigEndian.PutUint16(os2[8:], flags)
		tables["OS/2"] = os2
		data := sfnt.Build(tables, false)
		for _, ignore := range []bool{false, true} {
			add("fstype", data, "", "Hello", ignore)
		}
	}
	// A collection of repeated offsets shares the glyph program, but still creates
	// one sample program for each selected face, matching upstream accounting.
	shared := collection(raw, 2)
	add("shared-collection", shared, "all", "Hi", false)
	add("shared-collection", shared, "1,1,2", "Hi", false)
	data, err := json.Marshal(map[string]any{"inputs": inputs, "cases": results})
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/specimen/programs.json.gz"), packFixture(data), 0644); err != nil {
		t.Fatal(err)
	}
}
