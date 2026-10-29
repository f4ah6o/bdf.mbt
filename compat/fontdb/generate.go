//go:build ignore

// Generate font resolution and character fallback fixtures from upstream.
package main

import (
	"bytes"
	"compress/gzip"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"github.com/shibukawa/bdf/converter/csv"
	"github.com/shibukawa/bdf/converter/internal/fontset"
	"github.com/shibukawa/bdf/internal/fontdb"
	"github.com/shibukawa/bdf/internal/sfnt"
	"os"
	"path/filepath"
	"testing/fstest"
)

type spec struct {
	family  string
	weight  int
	italic  bool
	mapping string
	math    bool
}

func main() {
	root := os.Args[1]
	original, e := os.ReadFile(filepath.Join(root, "compat/font/fixtures/stix.ttf"))
	if e != nil {
		panic(e)
	}
	base, e := sfnt.Parse(original)
	if e != nil {
		panic(e)
	}
	specs := []spec{{"Carlito", 400, false, "latin", false}, {"Carlito", 700, false, "latin", false}, {"Carlito", 400, true, "latin", false}, {"Liberation Sans", 400, false, "latin", false}, {"Noto Sans CJK JP", 400, false, "cjk", false}, {"Noto Serif CJK JP", 400, false, "cjk", false}, {"Noto Sans CJK SC", 400, false, "cjk", false}, {"Noto Sans CJK KR", 400, false, "cjk", false}, {"DejaVu Sans", 400, false, "symbol", false}, {"STIX Two Math", 400, false, "latin", true}, {"Liberation Mono", 400, false, "latin", false}, {"Alpha Face", 400, false, "latin", false}}
	files := []any{}
	data := map[string][]byte{}
	for i, s := range specs {
		cm := map[uint32]uint16{}
		for r, g := range base.Cmap {
			if s.mapping == "latin" && r < 128 {
				cm[r] = g
			}
		}
		if s.mapping == "cjk" {
			for j, r := range []rune("漢字かな한글") {
				cm[uint32(r)] = base.Cmap[uint32('A'+rune(j))]
			}
		}
		if s.mapping == "symbol" {
			for j, r := range []rune("★☺😀") {
				cm[uint32(r)] = base.Cmap[uint32('A'+rune(j))]
			}
		}
		font := base.Rebuild(cm, sfnt.FontInfo{Family: s.family, Weight: s.weight, Italic: s.italic, FSType: base.FSType, Notices: base.Notices})
		// Give faces distinct metrics so mixed-font line heights are exercised.
		parsed, e := sfnt.Parse(font)
		if e != nil {
			panic(e)
		}
		if os2 := parsed.Tables["OS/2"]; len(os2) >= 72 {
			binary.BigEndian.PutUint16(os2[68:], uint16(800+i*55))
			binary.BigEndian.PutUint16(os2[70:], uint16(160+i*15))
			font = sfnt.Build(parsed.Tables, false)
		}
		if s.math {
			f, e := sfnt.Parse(font)
			if e != nil {
				panic(e)
			}
			tables := f.Tables
			tables["MATH"] = []byte{0, 1, 0, 0, 0, 0, 0, 0, 0, 0}
			font = sfnt.Build(tables, false)
		}
		path := fmt.Sprintf("%02d.ttf", i)
		data[path] = font
		var z bytes.Buffer
		w := gzip.NewWriter(&z)
		if _, e = w.Write(font); e != nil {
			panic(e)
		}
		if e = w.Close(); e != nil {
			panic(e)
		}
		files = append(files, map[string]any{"path": path, "gzip": z.Bytes()})
	}
	groups := [][]int{{}, {0, 1, 2}, {4, 5}, {8, 11}, {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11}, {11}}
	names := []string{"", "Calibri", "Ｃａｌｉｂｒｉ", "Carlito", "Arial", "Arial Black", "Times New Roman", "MS Gothic", "游ゴシック", "宋体", "新細明體", "맑은 고딕", "Courier New", "Foo Sans", "STIX Two Math", "Alpha Face", "Ａｌｐｈａ－Ｆａｃｅ", "unknown"}
	cases := []any{}
	for gi, group := range groups {
		fs := fstest.MapFS{}
		for _, i := range group {
			path := fmt.Sprintf("%02d.ttf", i)
			fs[path] = &fstest.MapFile{Data: data[path]}
		}
		db := fontdb.New(fs, nil, false)
		describe := func(r fontdb.Resolved) map[string]any {
			path := ""
			index := -1
			if r.Face != nil {
				path = r.Face.Path
				index = r.Face.Index
			}
			return map[string]any{"path": path, "index": index, "bold": r.SynthBold, "italic": r.SynthItalic, "exact": r.Exact, "generic": r.Generic}
		}
		for _, name := range names {
			for _, bold := range []bool{false, true} {
				for _, italic := range []bool{false, true} {
					for _, cjk := range []bool{false, true} {
						cases = append(cases, map[string]any{"kind": "resolve", "group": gi, "name": name, "bold": bold, "italic": italic, "cjk": cjk, "result": describe(db.Resolve(name, bold, italic, cjk))})
					}
				}
			}
		}
		for _, generic := range []string{"sans-serif", "serif", "monospace", "other"} {
			for _, bold := range []bool{false, true} {
				for _, italic := range []bool{false, true} {
					list := []any{}
					for _, r := range db.Fallbacks(generic, bold, italic) {
						list = append(list, describe(r))
					}
					cases = append(cases, map[string]any{"kind": "fallbacks", "group": gi, "generic": generic, "bold": bold, "italic": italic, "result": list})
				}
			}
		}
		for _, name := range names {
			face := db.ResolveMath(name)
			path := ""
			if face != nil {
				path = face.Path
			}
			cases = append(cases, map[string]any{"kind": "math", "group": gi, "name": name, "result": path})
		}
		for _, latin := range []string{"Calibri", "Arial", "unknown"} {
			for _, ea := range []string{"", "游ゴシック", "宋体"} {
				for _, ch := range []rune{'A', '漢', 'あ', '★', '😀', '\t', '\n'} {
					for _, bold := range []bool{false, true} {
						choice := fontset.New(db, nil).FaceFor(latin, ea, bold, false, ch)
						path := ""
						if choice.Use.Face != nil {
							path = choice.Use.Face.Path
						}
						cases = append(cases, map[string]any{"kind": "char", "group": gi, "latin": latin, "ea": ea, "code": ch, "bold": bold, "result": map[string]any{"path": path, "requested": choice.Use.Requested, "generic": choice.Use.Generic, "synthBold": choice.Use.SynthBold, "synthItalic": choice.Use.SynthItalic}})
					}
				}
			}
		}
	}
	for _, name := range []string{"Ｃａｌｉｂｒｉ", "Ａｌｐｈａ－Ｆａｃｅ", "ＭＳ　ゴシック", "e\u0301", "Kelvin", "ﬃ_ABC", "İstanbul", "Ｆｏｏ—Ｂａｒ"} {
		cases = append(cases, map[string]any{"kind": "normalize", "name": name, "result": fontdb.Normalize(name)})
	}
	conversions := []any{}
	inputs := []string{
		"Name,Text\nAlice,Hello ★\nBob,漢字かな 😀\n",
		"名前,内容\nあ,漢字かな\nい,ABC★\n",
		"名前,値\n漢字,\"ABC\nかな★\"\nかな,12\n",
		"Name,Amount\nAlpha,123\nBeta,456\n",
	}
	for gi, group := range groups {
		fs := fstest.MapFS{}
		for _, i := range group {
			path := fmt.Sprintf("%02d.ttf", i)
			fs[path] = &fstest.MapFile{Data: data[path]}
		}
		for scenario, input := range inputs {
			for mode := 0; mode < 3; mode++ {
				opt := &csv.Options{FontFS: fs, NoSystemFonts: true, NoWOFF2: true, Header: csv.HeaderYes, Name: "People", Title: "Report", NoSubset: mode == 0, SystemFonts: mode == 2}
				if scenario == 3 {
					opt.TableStyle = "Medium2"
				}
				res, err := csv.Convert(bytes.NewReader([]byte(input)), int64(len(input)), opt)
				if err != nil {
					panic(err)
				}
				parts := []any{}
				for _, p := range res.Doc.Parts() {
					parts = append(parts, map[string]any{"type": p.Type, "hash": p.Hash.String()})
				}
				entry := map[string]any{"group": gi, "scenario": scenario, "mode": mode, "input": input, "views": res.Doc.Views, "tables": res.Doc.Tables, "warnings": res.Warnings, "parts": parts}
				if gi == 4 && scenario == 0 && mode == 1 {
					var encoded, compressed bytes.Buffer
					if err := res.Doc.WriteSingle(&encoded); err != nil {
						panic(err)
					}
					w := gzip.NewWriter(&compressed)
					if _, err := w.Write(encoded.Bytes()); err != nil {
						panic(err)
					}
					if err := w.Close(); err != nil {
						panic(err)
					}
					entry["bdfGzip"] = compressed.Bytes()
				}
				conversions = append(conversions, entry)
			}
		}
	}
	if e := json.NewEncoder(os.Stdout).Encode(map[string]any{"files": files, "groups": groups, "cases": cases, "conversions": conversions}); e != nil {
		panic(e)
	}
}
