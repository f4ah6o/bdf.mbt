//go:build ignore

// Generate fixture.bdf with shibukawa/bdf v0.2.1 (commit 4f9af52).
// Run this file in a checkout of that module: go run <path>/generate_fixture.go <output> <synthetic.ttf> <split-dir>.
package main

import (
	"bytes"
	"image"
	"image/color"
	"image/png"
	"os"

	bdf "github.com/shibukawa/bdf"
)

func main() {
	d := bdf.NewDocument()
	pixels := image.NewRGBA(image.Rect(0, 0, 2, 2))
	pixels.Set(0, 0, color.RGBA{R: 250, G: 80, B: 30, A: 255})
	pixels.Set(1, 0, color.RGBA{R: 30, G: 160, B: 220, A: 255})
	pixels.Set(0, 1, color.RGBA{R: 240, G: 200, B: 20, A: 255})
	pixels.Set(1, 1, color.RGBA{R: 40, G: 190, B: 100, A: 255})
	var img bytes.Buffer
	if err := png.Encode(&img, pixels); err != nil {
		panic(err)
	}
	fontData, err := os.ReadFile(os.Args[2])
	if err != nil {
		panic(err)
	}
	embeddedHash := d.AddFont(fontData)
	ih := d.AddImage(img.Bytes())
	svg := d.AddImage([]byte(`<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><rect width="16" height="16" fill="#f9d85c"/><circle cx="8" cy="8" r="6" fill="#7824b8"/></svg>`))
	child := bdf.NewObject().SetBBox(0, 0, 60, 60)
	circle := child.AddPath((&bdf.Path{}).Circle(30, 30, 25))
	child.FillColor(0x32a96eff).FillPath(circle, bdf.NonZero).StrokeColor(0x195838ff).Line(3, 0, 0, 10).StrokePath(circle)
	childHash, box := d.AddObject(child)
	o := bdf.NewObject().SetBBox(0, 0, 640, 600)
	font := o.AddFont(bdf.SystemFont("sans-serif", 700, bdf.StyleNormal))
	embedded := o.AddFont(bdf.EmbeddedFont(embeddedHash, 400, bdf.StyleNormal))
	grad := o.AddPaint(bdf.LinearGradient(30, 70, 590, 70, bdf.Stop{Offset: 0, Color: 0x2060c0ff}, bdf.Stop{Offset: 1, Color: 0x6ed6f0ff}))
	pathHash := d.AddPaths([]*bdf.Path{(&bdf.Path{}).MoveTo(65, 180).LineTo(170, 115).QuadTo(215, 160, 170, 220).LineTo(65, 220).Close()})
	path := o.AddExtPath(pathHash, 0)
	imgRef := o.AddImage(ih)
	svgRef := o.AddImage(svg)
	pattern := bdf.Pattern(imgRef, bdf.RepeatBoth)
	pattern.Matrix = [6]float32{8, 0, 0, 8, 0, 0}
	pat := o.AddPaint(pattern)
	childRef := o.AddObject(childHash, box)
	o.FillColor(0xffffffff).FillRect(0, 0, 640, 600)
	o.FillPaint(grad).FillRect(30, 70, 560, 36)
	o.FillColor(0x152538ff).Font(font, 28).TextStyle(bdf.AlignLeft, bdf.BaselineAlphabetic, bdf.DirLTR, 0).FillText("BDF visual parity", 30, 52, 0)
	o.FillColor(0xf07832ff).FillPath(path, bdf.NonZero)
	o.StrokeColor(0x1d2737ff).Line(4, bdf.CapRound, bdf.JoinRound, 10).Dash([]float32{9, 5}, 2).StrokePath(path)
	o.Save().ClipRect(250, 130, 100, 95).Alpha(0.75).FillColor(0x8d51caff).FillRect(230, 110, 150, 150).Restore()
	o.FillPaint(pat).FillRect(385, 130, 100, 90)
	o.Image(imgRef, 510, 130, 80, 80)
	o.Image(svgRef, 500, 270, 80, 80)
	o.UseAt(childRef, 65, 270).UseAt(childRef, 150, 270)
	o.FillColor(0x3b2058ff).Font(embedded, 40).FillText("AAA", 385, 385, 0)
	o.Save().Translate(320, 300).Scale(1.4, 0.8).FillColor(0x185aaaff).FillRect(0, 0, 95, 45).Restore()
	// Group alpha is applied after overlapping shapes and child objects are drawn.
	o.GroupBegin(0.5, bdf.BlendSourceOver, 30, 420, 150, 90)
	o.FillColor(0xe83030ff).FillRect(30, 420, 90, 80).FillColor(0x3050e0ff).FillRect(80, 440, 100, 70)
	o.UseAt(childRef, 105, 435).GroupEnd()
	// Exercise both alpha and luminosity masks, including a transfer function.
	o.GroupBegin(1, bdf.BlendSourceOver, 220, 420, 120, 90).FillColor(0x009a74ff).FillRect(220, 420, 120, 90)
	o.MaskBegin(bdf.MaskAlpha, 0, nil).FillColor(0xffffff80).FillRect(220, 420, 80, 90).MaskEnd().GroupEnd()
	inv := make([]byte, 256)
	for i := range inv {
		inv[i] = byte(255 - i)
	}
	o.GroupBegin(1, bdf.BlendMultiply, 380, 420, 140, 90).FillColor(0xef5d20ff).FillRect(380, 420, 140, 90)
	o.MaskBegin(bdf.MaskLuminosity, 0x000000ff, inv).FillColor(0x808080ff).FillRect(380, 420, 70, 90).FillColor(0xffffffff).FillRect(450, 420, 70, 90).MaskEnd().GroupEnd()
	// Nested groups under a transform check offscreen coordinate handling.
	o.Save().Translate(80, 530).GroupBegin(0.8, bdf.BlendSourceOver, 0, 0, 100, 55)
	o.FillColor(0xc42aaaff).FillRect(0, 0, 100, 55).GroupBegin(0.5, bdf.BlendScreen, 20, 10, 55, 35).FillColor(0x30d050ff).FillRect(20, 10, 55, 35).GroupEnd().GroupEnd().Restore()
	hash, _ := d.AddObject(o)
	d.NewView("p", bdf.ViewFixed, "").AddPage(640, 600, bdf.Layer{Role: bdf.RoleBody, Obj: hash})
	out, err := os.Create(os.Args[1])
	if err != nil {
		panic(err)
	}
	defer out.Close()
	if err = d.WriteSingle(out); err != nil {
		panic(err)
	}
	d.AddImage([]byte("unused split fixture part"))
	if err = d.WriteSplit(os.Args[3]); err != nil {
		panic(err)
	}
}
