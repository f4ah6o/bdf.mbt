//go:build ignore

// Generate an SVG image, source-rectangle and pattern fixture with upstream bdf.
package main

import (
	bdf "github.com/shibukawa/bdf"
	"os"
)

func main() {
	doc := bdf.NewDocument()
	svg := `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 20"><rect width="40" height="20" fill="#f4b942"/><circle cx="15" cy="10" r="8" fill="#1463c3"/><path d="M25 2L38 18" stroke="#111" stroke-width="2"/></svg>`
	hash := doc.AddImage([]byte(svg))
	o := bdf.NewObject().SetBBox(0, 0, 240, 180)
	image := o.AddImage(hash)
	pattern := bdf.Pattern(image, bdf.RepeatBoth)
	pattern.Matrix = [6]float32{0.8, 0.2, -0.1, 1.1, 4, 3}
	paint := o.AddPaint(pattern)
	o.FillColor(0xffffffff).FillRect(0, 0, 240, 180)
	o.Image(image, 10, 10, 80, 40)
	o.ImageSub(image, 5, 2, 20, 16, 110, 10, 100, 65)
	o.Save().Translate(10, 85).Scale(1.15, 0.9).FillPaint(paint).FillRect(0, 0, 160, 75).Restore()
	object, _ := doc.AddObject(o)
	doc.NewView("svg", bdf.ViewFixed, "").AddPage(240, 180, bdf.Layer{Role: bdf.RoleBody, Obj: object})
	f, err := os.Create(os.Args[1])
	if err != nil {
		panic(err)
	}
	defer f.Close()
	if err := doc.WriteSingle(f); err != nil {
		panic(err)
	}
}
