//go:build ignore

// Generate unstyled sheet drawing objects without installed fonts.
package main

import (
	"encoding/json"
	"github.com/shibukawa/bdf/converter/xlsx"
	"os"
	"strings"
)

func main() {
	c := func(s string, n bool) xlsx.GridCell { return xlsx.GridCell{Text: s, Number: n} }
	grids := []*xlsx.Grid{
		{},
		{Rows: [][]xlsx.GridCell{{c("hello", false)}}, HeaderRows: 1},
		{Rows: [][]xlsx.GridCell{{c("name", false), c("value", false)}, {c("Alice", false), c("12", true)}}, HeaderRows: 1},
		{Rows: [][]xlsx.GridCell{{c("a\nb", false), c("  ", false)}}, HeaderRows: 1},
		{Rows: [][]xlsx.GridCell{{c("日本語ABC 漢字", false), c("123", true)}, {c("漢字", false), c("カナ 한글", false)}}, HeaderRows: 1, Lang: "ja"},
		{Rows: [][]xlsx.GridCell{{c(strings.Repeat("long text ", 200), false), c("", false), c("stop", false)}}},
		{},
		{Rows: [][]xlsx.GridCell{{c("   ", false)}}},
		{},
		{Rows: [][]xlsx.GridCell{{c(strings.Repeat("a\n", 40), false)}, {c("next", false)}}},
		{Rows: [][]xlsx.GridCell{{c("\ufeffHello", false), c("\t  x  ", false)}, {c("\x01", false), c("done", false)}}},
		{Rows: [][]xlsx.GridCell{{c("Header", false)}, {c("Subheader", false)}, {c("Value", false)}}, HeaderRows: 2, SubHeader: true},
		{Rows: [][]xlsx.GridCell{{c("漢字", false), c("English", false)}, {c("かな", false), c("한글", false)}}, Lang: "zh-TW"},
	}
	for i := 0; i < 160; i++ {
		grids[6].Rows = append(grids[6].Rows, []xlsx.GridCell{c("row", false), c("7", true)})
	}
	row := make([]xlsx.GridCell, 65)
	for i := range row {
		row[i] = c("xx", false)
	}
	grids[8].Rows = [][]xlsx.GridCell{row}
	texts := []string{"English \t text", "カナ abc 漢字", "한글 ab", "漢字", "abc\n def", "  ", "", "abc-def xyz"}
	langs := []string{"", "ja", "ko", "zh-CN", "zh-TW"}
	for i := 0; i < 40; i++ {
		rows := make([][]xlsx.GridCell, 3)
		for r := 0; r < 3; r++ {
			for col := 0; col < 3; col++ {
				text := texts[(i*3+r*5+col*7)%len(texts)]
				if (i+r+col)%11 == 0 {
					text += strings.Repeat("xy", 300)
				}
				rows[r] = append(rows[r], c(text, (i+r+col)%4 == 0))
			}
		}
		grids = append(grids, &xlsx.Grid{Rows: rows, HeaderRows: i % 3, Lang: langs[i%len(langs)]})
	}
	result := []any{}
	for _, grid := range grids {
		out, err := xlsx.ConvertGrid(grid, &xlsx.Options{NoSystemFonts: true, NoTextIndex: true})
		if err != nil {
			panic(err)
		}
		parts := []any{}
		for _, part := range out.Doc.Parts() {
			parts = append(parts, map[string]any{"hash": part.Hash.String(), "data": part.Data})
		}
		result = append(result, map[string]any{"parts": parts, "tiles": out.Doc.Views[0].Tiles})
	}
	if err := json.NewEncoder(os.Stdout).Encode(result); err != nil {
		panic(err)
	}
}
