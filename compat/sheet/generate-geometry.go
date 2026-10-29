//go:build ignore

// Generate sheet geometry with the pinned upstream converter.
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
	c := func(s string, n bool) xlsx.GridCell { return xlsx.GridCell{Text: s, Number: n} }
	blank := make([][]xlsx.GridCell, 40)
	blank[0] = []xlsx.GridCell{c("head", false)}
	grids := []*xlsx.Grid{
		{},
		{Rows: [][]xlsx.GridCell{{c("name", false), c("value", false)}, {c("Alice", false), c("12", true)}}, HeaderRows: 1},
		{Rows: [][]xlsx.GridCell{{c(strings.Repeat("long text ", 200), false)}}},
		{Rows: [][]xlsx.GridCell{{c(strings.Repeat("long text ", 200), false), c("", false), c("stop", false)}}},
		{Rows: blank, HeaderRows: 32},
		{Rows: [][]xlsx.GridCell{{c("a\nb\nc", false), c(strings.Repeat("123456", 50), true)}, {c("last", false)}}},
	}
	for i := 0; i < 40; i++ {
		rows := make([][]xlsx.GridCell, 3)
		for r := 0; r < 3; r++ {
			for col := 0; col < 3; col++ {
				n := (i*37 + r*53 + col*97) % 1100
				text := strings.Repeat("x", n)
				if (i+r+col)%5 == 0 {
					text += "\nend"
				}
				rows[r] = append(rows[r], c(text, (i+r+col)%3 == 0))
			}
		}
		grids = append(grids, &xlsx.Grid{Rows: rows, HeaderRows: i % 3})
	}
	result := []any{}
	for _, grid := range grids {
		out, err := xlsx.ConvertGrid(grid, &xlsx.Options{NoSystemFonts: true, NoTextIndex: true})
		if err != nil {
			panic(err)
		}
		view := out.Doc.Views[0]
		frozen := 0
		if view.Freeze != nil {
			frozen = view.Freeze.Rows
		}
		result = append(result, map[string]any{"cols": view.Cols, "rows": view.Rows, "frozen": frozen})
	}
	input := []byte("name,amount,note\nAnn,1,abc\nBob,2.5,\"very long\nnote here\"\n")
	converted, err := csv.Convert(bytes.NewReader(input), int64(len(input)), &csv.Options{
		NoSystemFonts: true, NoTextIndex: true, Header: csv.HeaderYes, Data: "none",
	})
	if err != nil {
		panic(err)
	}
	view := converted.Doc.Views[0]
	frozen := 0
	if view.Freeze != nil {
		frozen = view.Freeze.Rows
	}
	result = append(result, map[string]any{"cols": view.Cols, "rows": view.Rows, "frozen": frozen})
	if err := json.NewEncoder(os.Stdout).Encode(result); err != nil {
		panic(err)
	}
}
