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

func TestCodexSamplePlans(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	results := []any{}
	add := func(name string, data []byte) {
		fl, err := load(data)
		if err != nil {
			t.Fatal(name, err)
		}
		for _, fc := range fl.faces {
			fc.prepare()
			for _, text := range []string{"", "Custom Δ 漢字"} {
				p := fc.plan(text)
				primary := ""
				if p.primary != nil {
					primary = p.primary.code
				}
				codes := []string{}
				for _, sc := range p.scripts {
					codes = append(codes, sc.code)
				}
				charset := append([]string{}, p.charset...)
				results = append(results, map[string]any{"name": name, "input": packFixture(data), "index": fc.index, "text": text, "primary": primary, "scripts": codes, "specimen": p.specimen, "charset": charset, "waterfall": p.waterfall, "rtl": p.rtl, "lang": p.lang, "all": p.all()})
			}
		}
	}
	for _, name := range []string{"stix.ttf", "stix.otf", "features.ttf", "variable.ttf", "color.ttf", "bold.ttc"} {
		b, err := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if err != nil {
			t.Fatal(err)
		}
		add(name, b)
	}
	makeFont := func(chars, design string) []byte {
		cm := map[uint32]uint16{}
		for _, c := range chars {
			cm[uint32(c)] = 1
		}
		// Include an invalid glyph mapping to ensure it does not become a sample.
		cm[uint32('🜁')] = 5
		tables := map[string][]byte{"maxp": {0, 1, 0, 0, 0, 2}, "cmap": sfnt.BuildCmap(cm)}
		if design != "" {
			b := make([]byte, 28+len(design))
			binary.BigEndian.PutUint32(b, 1)
			binary.BigEndian.PutUint32(b[12:], 1)
			copy(b[16:], "dlng")
			binary.BigEndian.PutUint32(b[20:], 28)
			binary.BigEndian.PutUint32(b[24:], uint32(len(design)))
			copy(b[28:], design)
			tables["meta"] = b
		}
		return sfnt.Build(tables, false)
	}
	chars := func(sc script) string {
		s := sc.text + sc.specimen
		for _, l := range sc.charset {
			s += l
		}
		return s
	}
	for _, sc := range scripts {
		add("script-"+sc.code, makeFont(chars(sc), ""))
	}
	latin, greek, jap, simp, arab := scripts[0], scripts[6], scripts[1], scripts[2], scripts[7]
	combo := chars(latin) + chars(greek) + chars(jap) + chars(simp) + chars(arab)
	for _, design := range []string{"", "el-Grek", "en-Latn,ar-Arab", "ja-Jpan", "unknown,zh-Hans", "zz-Zzzz", "EL-gReK", "unknown,ar-Arab"} {
		add("combo-"+design, makeFont(combo, design))
	}
	add("fold-hans", makeFont(chars(latin)+chars(simp), "zh-Hanſ"))
	add("fallback", makeFont("\u0301 ☃♥⚽AB١⭐♜", ""))
	add("empty", makeFont("", ""))
	add("fallback-48", makeFont("!#$%&()*+,-./0123456789:;<=>?@[\\]^_`{|}~☃♥♣♦⚽♜♞♟♠♬☂☄★♆♇☯☮✈✉✎✏✒✓✔✕✖✗✘✙✚✛✜✝✞", ""))
	encoded, err := json.Marshal(results)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/specimen/plan.json.gz"), packFixture(encoded), 0644); err != nil {
		t.Fatal(err)
	}
}
