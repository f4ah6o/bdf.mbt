//go:build ignore

// Generate single-font grid geometry with the upstream XLSX converter.
package main

import (
	"encoding/json"
	"github.com/shibukawa/bdf/converter/xlsx"
	"os"
	"path/filepath"
	"strings"
)

func main() {
	root := os.Args[1]
	paths := []string{"compat/visual/synthetic.ttf", "compat/font/fixtures/stix.ttf", "compat/font/fixtures/stix.otf", "compat/font/fixtures/features.ttf", "compat/font/fixtures/restricted.ttf", "compat/font/fixtures/variable.ttf", "compat/font/fixtures/color.ttf"}
	cell := func(s string, n bool) xlsx.GridCell { return xlsx.GridCell{Text: s, Number: n} }
	grids := []*xlsx.Grid{
		{Rows: [][]xlsx.GridCell{{cell("Name", false), cell("Amount", false), cell("Notes", false)}, {cell("Alice", false), cell("123.45", true), cell("line\nwrap", false)}, {cell("Bob", false), cell("-12", true), cell("small text", false)}}, HeaderRows: 1},
		{Rows: [][]xlsx.GridCell{{cell("A", false), cell("B", false)}, {cell("C", false), cell("200", true)}, {cell("漢字カナ", false), cell("7", true)}}, Lang: "ja"},
		{Rows: [][]xlsx.GridCell{{cell(strings.Repeat("wide text ", 120), false), cell("", false), cell("end", false)}, {cell("a\nb\nc", false), cell("0123", false)}}, HeaderRows: 1},
		{Rows: [][]xlsx.GridCell{{cell("name", false), cell("value", false)}, {cell("alpha", false), cell("22", true)}, {cell("beta", false), cell("333", true)}}, HeaderRows: 1, TableStyle: "Medium2"},
		{Rows: [][]xlsx.GridCell{{cell("head", false), cell("summary", false)}, {cell("sub", false), cell("", false)}, {cell("x\n日本語", false), cell("3", true)}}, HeaderRows: 2, SubHeader: true},
		{Rows: [][]xlsx.GridCell{{cell("漢字", false), cell("A", false)}, {cell("한글", false), cell("1", true)}, {cell("中文字", false), cell("2", true)}}, Lang: "ko"},
		{Rows: [][]xlsx.GridCell{{cell("漢字", false), cell("A", false)}, {cell("한글", false), cell("1", true)}, {cell("中文字", false), cell("2", true)}}, Lang: "zh-CN"},
		{Rows: [][]xlsx.GridCell{{cell("漢字", false), cell("A", false)}, {cell("한글", false), cell("1", true)}, {cell("中文字", false), cell("2", true)}}, Lang: "zh-TW"},
	}
	out := []any{}
	for _, path := range paths {
		data, err := os.ReadFile(filepath.Join(root, path))
		if err != nil {
			panic(err)
		}
		dir, err := os.MkdirTemp("", "bdf-font-geometry-")
		if err != nil {
			panic(err)
		}
		if err := os.WriteFile(filepath.Join(dir, filepath.Base(path)), data, 0600); err != nil {
			panic(err)
		}
		for scenario, grid := range grids {
			res, err := xlsx.ConvertGrid(grid, &xlsx.Options{FontDirs: []string{dir}, NoSystemFonts: true, NoSubset: true, NoWOFF2: true, NoTextIndex: true})
			if err != nil {
				panic(err)
			}
			view := res.Doc.Views[0]
			out = append(out, map[string]any{"file": path, "scenario": scenario, "cols": view.Cols, "rows": view.Rows, "freeze": view.Freeze})
		}
		if err := os.RemoveAll(dir); err != nil {
			panic(err)
		}
	}
	if err := json.NewEncoder(os.Stdout).Encode(out); err != nil {
		panic(err)
	}
}
