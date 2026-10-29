//go:build ignore

// Generate styled grid fixtures with the upstream no-font renderer.
package main

import (
	"encoding/json"
	"github.com/shibukawa/bdf/converter/xlsx"
	"os"
	"sort"
)

func main() {
	data, err := os.ReadFile(os.Args[1])
	if err != nil {
		panic(err)
	}
	styles := map[string]any{}
	if err := json.Unmarshal(data, &styles); err != nil {
		panic(err)
	}
	names := make([]string, 0, len(styles))
	for name := range styles {
		names = append(names, name)
	}
	sort.Strings(names)
	cell := func(text string, number bool) xlsx.GridCell { return xlsx.GridCell{Text: text, Number: number} }
	grids := []*xlsx.Grid{
		{Rows: [][]xlsx.GridCell{{cell("Name", false), cell("Total", false), cell("Note", false)}, {cell("Alice", false), cell("12", true), cell("", false)}, {cell("Bob", false), cell("3", true), cell("one\ntwo", false)}, {cell("", false), cell("", false), cell("", false)}}, HeaderRows: 1},
		{Rows: [][]xlsx.GridCell{{cell("漢字", false), cell("A", false)}, {cell("かな", false), cell("1", true)}, {cell("B", false), cell("2", true)}}, Lang: "ja"},
		{Rows: [][]xlsx.GridCell{{cell("Header", false), cell("Value", false)}, {cell("Sub", false), cell("", false)}, {cell("First", false), cell("7", true)}, {cell("Second", false), cell("8", true)}}, HeaderRows: 2, SubHeader: true},
	}
	wide := &xlsx.Grid{HeaderRows: 1}
	for r := 0; r < 140; r++ {
		row := []xlsx.GridCell{}
		for col := 0; col < 45; col++ {
			text := "x"
			if (r+col)%7 == 0 {
				text = ""
			}
			row = append(row, cell(text, false))
		}
		wide.Rows = append(wide.Rows, row)
	}
	grids = append(grids, wide)
	sparse := &xlsx.Grid{HeaderRows: 1, Rows: [][]xlsx.GridCell{{cell("only", false)}}}
	for r := 1; r < 45; r++ {
		sparse.Rows = append(sparse.Rows, nil)
	}
	grids = append(grids, sparse, &xlsx.Grid{HeaderRows: 1, Rows: [][]xlsx.GridCell{{cell("", false)}}})
	result := []any{}
	for _, name := range names {
		for index, grid := range grids {
			if index >= 3 && name != "TableStyleLight1" && name != "TableStyleMedium2" && name != "TableStyleDark9" {
				continue
			}
			grid.TableStyle = name
			out, err := xlsx.ConvertGrid(grid, &xlsx.Options{NoSystemFonts: true, NoTextIndex: true})
			if err != nil {
				panic(err)
			}
			parts := []any{}
			for _, part := range out.Doc.Parts() {
				parts = append(parts, map[string]any{"hash": part.Hash.String(), "data": part.Data})
			}
			view := out.Doc.Views[0]
			result = append(result, map[string]any{"style": name, "scenario": index, "parts": parts, "tiles": view.Tiles, "cols": view.Cols, "rows": view.Rows, "freeze": view.Freeze})
		}
	}
	if err := json.NewEncoder(os.Stdout).Encode(result); err != nil {
		panic(err)
	}
}
