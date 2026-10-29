//go:build ignore

// Generate row heights with the pinned upstream sheet converter.
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
		{HeaderRows: 1, Rows: [][]xlsx.GridCell{{c("a", false), c("b", false)}, {c("one\ntwo", false), c("x", false)}, {c("ordinary", false)}}},
		{HeaderRows: 1, Rows: [][]xlsx.GridCell{{c("header\nlabel", false)}, {c(strings.Repeat("wide words ", 30)+"\nlast", false)}, {c("after", false)}}},
		{Rows: [][]xlsx.GridCell{{c("1\n"+strings.Repeat("234567890", 30), true)}, {c("日本語、漢字\n１２３", false)}, {c("", false)}, {}}},
		{Rows: [][]xlsx.GridCell{{c(strings.Repeat("a\n", 40), false)}, {c("one\r\ntwo\rthree", false)}}},
	}
	result := [][]float32{}
	for _, grid := range grids {
		out, err := xlsx.ConvertGrid(grid, &xlsx.Options{NoSystemFonts: true, NoTextIndex: true})
		if err != nil {
			panic(err)
		}
		heights := []float32{}
		for _, run := range out.Doc.Views[0].Rows {
			for i := 0; i < int(run[0]) && len(heights) < len(grid.Rows); i++ {
				heights = append(heights, run[1])
			}
		}
		result = append(result, heights)
	}
	if err := json.NewEncoder(os.Stdout).Encode(result); err != nil {
		panic(err)
	}
}
