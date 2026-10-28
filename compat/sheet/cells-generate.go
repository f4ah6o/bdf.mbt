//go:build ignore

// Generate the multi-tile cell fixture with shibukawa/bdf v0.2.1.
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
	v.Cols = []bdf.Run{{2, 72}, {1, 0}, {7, 72}}
	v.Rows = []bdf.Run{{2, 36}, {1, 0}, {12, 36}}
	v.Gridlines = true
	v.Freeze = &bdf.Freeze{Rows: 1, Cols: 1}
	v.Tiles = map[string]string{}
	for y := 0; y < 2; y++ {
		for x := 0; x < 3; x++ {
			o := bdf.NewObject().SetBBox(0, 0, 256, 256)
			f := o.AddFont(bdf.SystemFont("sans-serif", 400, bdf.StyleNormal))
			o.Font(f, 16).FillColor(0x18304aff)
			if y == 0 && x == 0 {
				o.Mark(bdf.MarkCell, "A1 col").FillText("Header", 24, 32, 52)
				o.Mark(bdf.MarkCell, "B1:C1 col").FillText("Merged", 100, 32, 62)
				o.Mark(bdf.MarkCell, "A2").FillText("Apple", 24, 68, 48)
				o.Mark(bdf.MarkCell, "B2").FillText("12", 100, 68, 20)
				o.Mark(bdf.MarkCell, "A4").FillText("South", 24, 94, 50)
				o.Mark(bdf.MarkCell, "B4:B5").FillText("Long", 100, 94, 40)
				o.Mark(bdf.MarkCell, "A6:B6").FillText("Wide", 24, 130, 45)
			}
			if y == 0 && x == 1 {
				o.Mark(bdf.MarkCell, "A1 col").FillText("duplicate", -20, 32, 50)
				o.Mark(bdf.MarkCell, "E1").FillText("East", 32, 32, 42)
				o.Mark(bdf.MarkCell, "E2").FillText("Value", 32, 68, 48)
				o.Mark(bdf.MarkCell, "E4").FillText("End", 32, 94, 30)
			}
			if y == 0 && x == 2 {
				o.Mark(bdf.MarkCell, "G4").FillText("Far", 24, 94, 30)
			}
			if y == 1 && x == 0 {
				o.Mark(bdf.MarkCell, "A10").FillText("Below", 24, 32, 48)
			}
			hash, _ := d.AddObject(o)
			v.Tiles[fmt.Sprintf("%d,%d", x, y)] = hash.String()
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
