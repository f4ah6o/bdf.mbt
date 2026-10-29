//go:build ignore

// Generate the column widths with the pinned upstream sheet converter.
package main

import (
	"bytes"
	"encoding/json"
	"github.com/shibukawa/bdf/converter/csv"
	"github.com/shibukawa/bdf/converter/xlsx"
	"os"
	"strings"
)

func main() {
	c := func(text string, number bool) xlsx.GridCell { return xlsx.GridCell{Text: text, Number: number} }
	grids := []*xlsx.Grid{
		{HeaderRows: 1, Rows: [][]xlsx.GridCell{{c("name", false), c("amount", false), c("note", false)}, {c("Ann", false), c("1,234.50", true), c("two\r\nlines", false)}, {c("Bob", false), c("7", true), c(strings.Repeat("long note ", 20), false)}}},
		{HeaderRows: 1, Rows: [][]xlsx.GridCell{{c(strings.Repeat("X", 300), false), c(strings.Repeat("1234567890", 100), true)}, {c("", false), c("9", true)}}},
		{HeaderRows: 1, Rows: [][]xlsx.GridCell{{c("日本語", false), c("漢字\t  ABC", false), c("one\rshort\nlonger line", false)}, {c(" ", false), c("\U00016fe2\ufeff文字", false), c("abc\u200bxyz", false)}}},
		{HeaderRows: 1, TableStyle: "Medium2", Rows: [][]xlsx.GridCell{{c("Header name", false), c("数字", false), c("x", false)}, {c("a", false), c("1", true)}}},
	}
	result := [][]float32{}
	for _, grid := range grids {
		converted, err := xlsx.ConvertGrid(grid, &xlsx.Options{NoSystemFonts: true, NoTextIndex: true})
		if err != nil {
			panic(err)
		}
		n := 0
		for _, row := range grid.Rows {
			for j, v := range row {
				if v.Text != "" && j+1 > n {
					n = j + 1
				}
			}
		}
		widths := []float32{}
		for _, run := range converted.Doc.Views[0].Cols {
			for i := 0; i < int(run[0]) && len(widths) < n; i++ {
				widths = append(widths, run[1])
			}
		}
		result = append(result, widths)
	}
	input := []byte("name,amount,note\nAnn,1,abc\nBob,2.5,very long note here\n")
	csvResult, err := csv.Convert(bytes.NewReader(input), int64(len(input)), &csv.Options{
		NoSystemFonts: true, NoTextIndex: true, Header: csv.HeaderYes, Data: "none",
	})
	if err != nil {
		panic(err)
	}
	widths := []float32{}
	for _, run := range csvResult.Doc.Views[0].Cols {
		for i := 0; i < int(run[0]) && len(widths) < csvResult.Cols; i++ {
			widths = append(widths, run[1])
		}
	}
	result = append(result, widths)
	if err := json.NewEncoder(os.Stdout).Encode(result); err != nil {
		panic(err)
	}
}
