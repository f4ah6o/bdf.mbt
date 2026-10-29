//go:build ignore

// Copy into upstream internal/otlayout with generate_test.go.
package otlayout

import (
	"bytes"
	"compress/gzip"
	"encoding/binary"
	"encoding/json"
	"github.com/shibukawa/bdf/internal/sfnt"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexLayoutMetadata(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	results := []any{}
	add := func(name string, data []byte, gpos bool) {
		var table *Table
		var err error
		if gpos {
			table, err = ParseGPOS(data)
		} else {
			table, err = ParseGSUB(data)
		}
		out := map[string]any{"name": name, "data": data, "gpos": gpos, "valid": err == nil}
		if err == nil {
			language := func(l LangSys) any {
				return map[string]any{"tag": l.Tag, "required": l.Required, "features": append([]int{}, l.Features...)}
			}
			scripts := []any{}
			for _, s := range table.Scripts {
				var def any
				if s.Default != nil {
					def = language(*s.Default)
				}
				langs := []any{}
				for _, l := range s.Langs {
					langs = append(langs, language(l))
				}
				scripts = append(scripts, map[string]any{"tag": s.Tag, "default": def, "languages": langs})
			}
			features := []any{}
			for _, f := range table.Features {
				features = append(features, map[string]any{"tag": f.Tag, "lookups": append([]int{}, f.Lookups...), "uiName": f.UIName, "characters": append([]rune{}, f.Chars...)})
			}
			lookups := []any{}
			for _, l := range table.Lookups {
				lookups = append(lookups, map[string]any{"type": l.Type, "flag": l.Flag, "markSet": l.MarkSet})
			}
			sf := [][]string{}
			for _, s := range table.ScriptFeatures() {
				sf = append(sf, append([]string{}, s...))
			}
			out["scripts"] = scripts
			out["features"] = features
			out["lookups"] = lookups
			out["featureVariations"] = table.FeatureVariations
			out["scriptFeatures"] = sf
		}
		results = append(results, out)
	}
	var bases [][]byte
	for _, name := range []string{"stix.ttf", "stix.otf", "features.ttf", "variable.ttf", "color.ttf"} {
		raw, e := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if e != nil {
			t.Fatal(e)
		}
		f, e := sfnt.Parse(raw)
		if e != nil {
			t.Fatal(e)
		}
		for _, tag := range []string{"GSUB", "GPOS"} {
			if b := f.Tables[tag]; b != nil {
				add(name+"-"+tag, b, tag == "GPOS")
				bases = append(bases, b)
			}
		}
	}
	for _, b := range [][]byte{nil, wordsFixture(1, 0, 0, 0, 0), tableFixture(lookupFixture(1, singleFixture([]int{1}, []int{2}, false))), manyElements(true), manyElements(false), manyFeatureChars()} {
		add("synthetic", b, false)
		add("synthetic", b, true)
	}
	// Version 1.1 feature-variation list with a declared count larger than bytes.
	variation := make([]byte, 14+8+2*8)
	binary.BigEndian.PutUint16(variation, 1)
	binary.BigEndian.PutUint16(variation[2:], 1)
	binary.BigEndian.PutUint32(variation[10:], 14)
	binary.BigEndian.PutUint32(variation[18:], 100)
	add("variation", variation, false)
	rng := rand.New(rand.NewSource(548912))
	for i := 0; i < 600; i++ {
		base := bases[i%len(bases)]
		data := append([]byte(nil), base...)
		if i%3 == 0 {
			data = data[:rng.Intn(len(data)+1)]
		} else {
			for j := 0; j < 1+rng.Intn(6); j++ {
				data[rng.Intn(len(data))] = byte(rng.Intn(256))
			}
		}
		add("mutation", data, i%2 == 0)
	}
	raw, e := json.Marshal(results)
	if e != nil {
		t.Fatal(e)
	}
	var b bytes.Buffer
	z := gzip.NewWriter(&b)
	if _, e = z.Write(raw); e != nil {
		t.Fatal(e)
	}
	if e = z.Close(); e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/gsub/layout.json.gz"), b.Bytes(), 0644); e != nil {
		t.Fatal(e)
	}
}
