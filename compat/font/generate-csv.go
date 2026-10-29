//go:build ignore

// Generate CSV documents using one upstream font and whole-font embedding.
package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"github.com/shibukawa/bdf/converter/csv"
	"github.com/shibukawa/bdf/internal/sfnt"
	"os"
	"path/filepath"
)

func main() {
	root := os.Args[1]
	paths := []string{"compat/visual/synthetic.ttf", "compat/font/fixtures/stix.ttf", "compat/font/fixtures/stix.otf", "compat/font/fixtures/features.ttf", "compat/font/fixtures/restricted.ttf", "compat/font/fixtures/variable.ttf", "compat/font/fixtures/color.ttf"}
	inputs := []string{"name,amount,note\nAlice,1,hello\nBob,2,\"one\ntwo\"\n", "A,B\nC,200\n漢字カナ,7\n", "name,value\nalpha,22\nbeta,333\n", "", "name,value\n'Ann',1\n'Bob',2\n", "name,amount,note\nAlice,1,hello\nBob,2,\"one\ntwo\"\n", "name,amount,note\nAlice,1,hello\nBob,2,\"one\ntwo\"\n"}
	out := []any{}
	type spec struct {
		path            string
		index           int
		noSubsetLicense bool
		oversized       bool
	}
	specs := []spec{}
	for _, path := range paths {
		specs = append(specs, spec{path, 0, false, false})
	}
	specs = append(specs, spec{"compat/font/fixtures/bold.ttc", 0, false, false}, spec{"compat/font/fixtures/bold.ttc", 1, false, false}, spec{"compat/font/fixtures/stix.ttf", 0, true, false}, spec{"compat/font/fixtures/stix.ttf", 0, true, true}, spec{"compat/font/fixtures/restricted.ttf", 0, false, true})
	for _, item := range specs {
		path := item.path
		data, err := os.ReadFile(filepath.Join(root, path))
		if err != nil {
			panic(err)
		}
		if filepath.Ext(path) == ".ttc" {
			data = append([]byte(nil), data...)
			faceOffset := binary.BigEndian.Uint32(data[12+4*item.index:])
			binary.BigEndian.PutUint32(data[8:], 1)
			binary.BigEndian.PutUint32(data[12:], faceOffset)
		}
		if item.noSubsetLicense {
			data = append([]byte(nil), data...)
			parsed, err := sfnt.Parse(data)
			if err != nil {
				panic(err)
			}
			binary.BigEndian.PutUint16(parsed.Tables["OS/2"][8:], 0x100)
		}
		if item.oversized {
			data = append(data, make([]byte, 2*1024*1024)...)
		}
		dir, err := os.MkdirTemp("", "bdf-csv-font-")
		if err != nil {
			panic(err)
		}
		if err := os.WriteFile(filepath.Join(dir, filepath.Base(path)), data, 0600); err != nil {
			panic(err)
		}
		for scenario := 0; scenario < 14; scenario++ {
			kind := scenario % 7
			input := inputs[kind]
			opt := &csv.Options{FontDirs: []string{dir}, NoSystemFonts: true, NoSubset: scenario < 7, NoWOFF2: true, Header: csv.HeaderYes, Name: "People", Title: "Report"}
			if kind == 2 {
				opt.TableStyle = "Medium2"
			}
			if kind == 3 {
				opt.Header = csv.HeaderNo
				opt.Data = "none"
			}
			if kind == 6 {
				opt.IgnoreFSType = true
			}
			if kind == 5 {
				opt.SystemFonts = true
			}
			if kind == 4 {
				opt.Quote = -1
			}
			res, err := csv.Convert(bytes.NewReader([]byte(input)), int64(len(input)), opt)
			if err != nil {
				panic(err)
			}
			parts := []any{}
			fontHash := ""
			fontTables := map[string]string{}
			for _, p := range res.Doc.Parts() {
				if p.Type == "font" {
					fontHash = p.Hash.String()
					font, err := sfnt.Parse(p.Data)
					if err != nil {
						panic(err)
					}
					for _, tag := range []string{"glyf", "loca", "head", "hhea", "hmtx", "maxp", "cvt ", "fpgm", "prep", "CFF ", "gasp", "OS/2", "post"} {
						if data, ok := font.Tables[tag]; ok {
							data = append([]byte(nil), data...)
							if tag == "head" && len(data) >= 12 {
								clear(data[8:12])
							}
							digest := sha256.Sum256(data)
							fontTables[tag] = hex.EncodeToString(digest[:])
						}
					}
				} else {
					parts = append(parts, map[string]any{"hash": p.Hash.String(), "type": p.Type, "data": p.Data})
				}
			}
			entry := map[string]any{"file": path, "index": item.index, "noSubsetLicense": item.noSubsetLicense, "oversized": item.oversized, "scenario": scenario, "input": input, "views": res.Doc.Views, "tables": res.Doc.Tables, "warnings": res.Warnings, "fontHash": fontHash, "fontTables": fontTables, "parts": parts}
			if !item.noSubsetLicense && !item.oversized && (((path == "compat/font/fixtures/stix.ttf" || path == "compat/font/fixtures/stix.otf") && (scenario == 0 || scenario == 2)) || (path == "compat/font/fixtures/bold.ttc" && scenario == 0) || (path == "compat/font/fixtures/stix.ttf" && scenario == 7) || (path == "compat/font/fixtures/stix.otf" && scenario == 7) || (path == "compat/font/fixtures/bold.ttc" && item.index == 1 && scenario == 7)) {
				var encoded bytes.Buffer
				if err := res.Doc.WriteSingle(&encoded); err != nil {
					panic(err)
				}
				entry["bdf"] = encoded.Bytes()
			}
			out = append(out, entry)
		}
		if err := os.RemoveAll(dir); err != nil {
			panic(err)
		}
	}
	if err := json.NewEncoder(os.Stdout).Encode(out); err != nil {
		panic(err)
	}
}
