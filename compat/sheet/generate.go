//go:build ignore

// Generate a sheet fixture with shibukawa/bdf v0.2.1.
package main

import (
	"bytes"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"os"

	bdf "github.com/shibukawa/bdf"
)

func main() {
	d := bdf.NewDocument()
	fontBytes, err := os.ReadFile(os.Args[3])
	if err != nil {
		panic(err)
	}
	fontHash := d.AddFont(fontBytes)
	v := d.NewView("sheet", bdf.ViewSheet, "Sheet")
	v.Tile = 256
	v.Cols = []bdf.Run{{2, 72}, {5, 0}, {7, 72}}
	v.Rows = []bdf.Run{{2, 36}, {3, 0}, {12, 36}}
	v.Gridlines = true
	v.Freeze = &bdf.Freeze{Cols: 1, Rows: 1}
	v.Tiles = map[string]string{}
	for y := 0; y < 2; y++ {
		for x := 0; x < 3; x++ {
			o := bdf.NewObject().SetBBox(0, 0, 256, 256)
			font := o.AddFont(bdf.SystemFont("sans-serif", 400, bdf.StyleNormal))
			colors := []bdf.Color{0xe8f4ffff, 0xfff1d6ff, 0xe6f8e7ff, 0xf8e8f5ff, 0xe8eaf8ff, 0xfbe8e4ff}
			o.FillColor(colors[y*3+x]).FillRect(12, 12, 150, 85)
			o.FillColor(0x18304aff).Font(font, 20).Mark(bdf.MarkCell, "A1").FillText(fmt.Sprintf("Tile %d,%d", x, y), 24, 54, 92)
			// The overshooting rectangle must be clipped at the tile boundary.
			o.FillColor(0x285ac080).FillRect(220, 180, 70, 70)
			if x == 1 && y == 0 {
				embedded := o.AddFont(bdf.EmbeddedFont(fontHash, 400, bdf.StyleNormal))
				o.Font(embedded, 28).FillText("AAA", 24, 86, 84)
				img := image.NewRGBA(image.Rect(0, 0, 2, 2))
				img.Set(0, 0, color.RGBA{R: 255, A: 255})
				img.Set(1, 0, color.RGBA{G: 255, A: 255})
				img.Set(0, 1, color.RGBA{B: 255, A: 255})
				img.Set(1, 1, color.RGBA{R: 255, G: 255, A: 255})
				var data bytes.Buffer
				if err := png.Encode(&data, img); err != nil {
					panic(err)
				}
				o.Image(o.AddImage(d.AddImage(data.Bytes())), 170, 25, 48, 48)
			}
			hash, _ := d.AddObject(o)
			v.Tiles[fmt.Sprintf("%d,%d", x, y)] = hash.String()
		}
	}
	out, err := os.Create(os.Args[1])
	if err != nil {
		panic(err)
	}
	defer out.Close()
	if err := d.WriteSingle(out); err != nil {
		panic(err)
	}
	if err := d.WriteSplit(os.Args[2]); err != nil {
		panic(err)
	}
	if len(os.Args) > 5 {
		lock, err := bdf.NewPasswordLock("pass", 1000)
		if err != nil {
			panic(err)
		}
		d.Lock = lock
		encrypted, err := os.Create(os.Args[4])
		if err != nil {
			panic(err)
		}
		if err := d.WriteSingle(encrypted); err != nil {
			panic(err)
		}
		if err := encrypted.Close(); err != nil {
			panic(err)
		}
		if err := d.WriteSplit(os.Args[5]); err != nil {
			panic(err)
		}
	}
}
