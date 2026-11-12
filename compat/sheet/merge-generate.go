//go:build ignore

// Generate the merged span fixture with shibukawa/bdf v0.2.1. The sheet
// advances more than one tile per merged cell span: a 26-column merge
// A1:Z1 crosses 8 tile columns and a 38-row merge B3:B40 crosses 7 tile
// rows, both anchored in tile (0,0) while the sheet has 8x7 tiles.
// Column C is a hidden width-0 run, so the 25 visible columns span
// 1800pt, not the 1872pt of the raw run widths.
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
	// Columns A,B are 72pt, column C is a hidden width-0 run, and columns
	// D..Z are 72pt: 1800pt of visible width, 8 tiles of 256pt.
	v.Cols = []bdf.Run{{2, 72}, {1, 0}, {23, 72}}
	// Rows 1..3 are 36pt and rows 4..43 are 36pt: 1548pt, 7 tile rows.
	// Column C hides inside the A1:Z1 merge and row coverage is all visible.
	v.Rows = []bdf.Run{{3, 36}, {40, 36}}
	v.Gridlines = true
	v.Tiles = map[string]string{}

	// Every tile without content shares one empty object part.
	empty := bdf.NewObject().SetBBox(0, 0, 256, 256)
	emptyHash, _ := d.AddObject(empty)
	tile := func(x, y int, o *bdf.Object) {
		if o == nil {
			v.Tiles[fmt.Sprintf("%d,%d", x, y)] = emptyHash.String()
			return
		}
		hash, _ := d.AddObject(o)
		v.Tiles[fmt.Sprintf("%d,%d", x, y)] = hash.String()
	}

	// Tile (0,0) anchors both merges: the text of a merged cell lives in
	// the tile holding its anchor, far from the tiles its span crosses.
	o := bdf.NewObject().SetBBox(0, 0, 256, 256)
	f := o.AddFont(bdf.SystemFont("sans-serif", 400, bdf.StyleNormal))
	o.Font(f, 16).FillColor(0x18304aff)
	o.Mark(bdf.MarkCell, "A1:Z1").FillText("Long merged", 24, 32, 100)
	o.Mark(bdf.MarkCell, "B3:B40").FillText("Tall", 100, 96, 40)
	tile(0, 0, o)

	// Tile (3,1): a plain cell at N10, six tiles right of the anchor.
	o = bdf.NewObject().SetBBox(0, 0, 256, 256)
	f = o.AddFont(bdf.SystemFont("sans-serif", 400, bdf.StyleNormal))
	o.Font(f, 16).FillColor(0x18304aff)
	o.Mark(bdf.MarkCell, "N10").FillText("Plain", 176, 100, 44)
	tile(3, 1, o)

	// Tile (1,5): a plain cell at E40, five tile rows below the anchor.
	o = bdf.NewObject().SetBBox(0, 0, 256, 256)
	f = o.AddFont(bdf.SystemFont("sans-serif", 400, bdf.StyleNormal))
	o.Font(f, 16).FillColor(0x18304aff)
	o.Mark(bdf.MarkCell, "E40").FillText("Edge", 48, 156, 44)
	tile(1, 5, o)

	for y := 0; y < 7; y++ {
		for x := 0; x < 8; x++ {
			key := fmt.Sprintf("%d,%d", x, y)
			if _, ok := v.Tiles[key]; !ok {
				tile(x, y, nil)
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
	// Password-encrypted single and split mirrors (password "pass").
	lock, err := bdf.NewPasswordLock("pass", 1000)
	if err != nil {
		panic(err)
	}
	d.Lock = lock
	out, err = os.Create(os.Args[3])
	if err != nil {
		panic(err)
	}
	if err = d.WriteSingle(out); err != nil {
		panic(err)
	}
	if err = out.Close(); err != nil {
		panic(err)
	}
	if err = d.WriteSplit(os.Args[4]); err != nil {
		panic(err)
	}
}
