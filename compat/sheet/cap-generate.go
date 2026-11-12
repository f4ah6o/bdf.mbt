//go:build ignore

// Generate the tile cap fixture with shibukawa/bdf v0.2.1. The sheet's tile
// table declares 4,097 tiles over a 17x241 tile grid (61 visible columns of
// 72pt and 1714 rows of 36pt), one tile above the worker clipboard cap, with
// every tile sharing one empty object part except the anchor tile.
package main

import (
	"fmt"
	bdf "github.com/shibukawa/bdf"
	"os"
)

func main() {
	d := bdf.NewDocument()
	v := d.NewView("cells", bdf.ViewSheet, "Cells")
	v.Tile = 256
	v.Cols = []bdf.Run{{61, 72}}
	v.Rows = []bdf.Run{{1714, 36}}
	v.Gridlines = true
	v.Tiles = map[string]string{}

	empty := bdf.NewObject().SetBBox(0, 0, 256, 256)
	emptyHash, _ := d.AddObject(empty)
	hashFor := func(o *bdf.Object) string {
		if o == nil {
			return emptyHash.String()
		}
		hash, _ := d.AddObject(o)
		return hash.String()
	}

	// Tile (0,0): a plain anchored cell, so the sheet is otherwise a valid
	// clipboard target and only the tile count can reject the request.
	o := bdf.NewObject().SetBBox(0, 0, 256, 256)
	f := o.AddFont(bdf.SystemFont("sans-serif", 400, bdf.StyleNormal))
	o.Font(f, 16).FillColor(0x18304aff)
	o.Mark(bdf.MarkCell, "A1").FillText("Anchor", 24, 32, 56)
	anchorHash := hashFor(o)

	for y := 0; y < 241; y++ {
		for x := 0; x < 17; x++ {
			if x == 0 && y == 0 {
				v.Tiles["0,0"] = anchorHash
			} else {
				v.Tiles[fmt.Sprintf("%d,%d", x, y)] = emptyHash.String()
			}
		}
	}
	out, err := os.Create(os.Args[1])
	if err != nil {
		panic(err)
	}
	if err = d.WriteSingle(out); err != nil {
		panic(err)
	}
	if err = out.Close(); err != nil {
		panic(err)
	}
	if err = d.WriteSplit(os.Args[2]); err != nil {
		panic(err)
	}
}
