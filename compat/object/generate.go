// Run from the pinned shibukawa/bdf checkout to generate the fixture.
package main

import (
	"encoding/base64"
	"encoding/json"
	bdf "github.com/shibukawa/bdf"
	"os"
)

func main() {
	hash, err := bdf.ParseHash("0123456789abcdef0123456789abcdef")
	if err != nil {
		panic(err)
	}
	path := new(bdf.Path).MoveTo(1, 2).LineTo(3, 4).QuadTo(5, 6, 7, 8).
		CubicTo(1, 2, 3, 4, 5, 6).Close().Rect(-1, -2, 3, 4).
		Ellipse(2, 3, 4, 5, 6, 7, 8, true).ArcTo(1, 2, 3, 4, 5).RoundRect(1, 2, 3, 4, 5)
	object := bdf.NewObject().SetBBox(-20, -10, 300, 200)
	p := object.AddPath(path)
	ext := object.AddExtPath(hash, 128)
	linear := object.AddPaint(bdf.LinearGradient(1, 2, 3, 4,
		bdf.Stop{Offset: 0, Color: 0xff0000ff}, bdf.Stop{Offset: 1, Color: 0x00123456}))
	object.AddPaint(bdf.RadialGradient(1, 2, 3, 4, 5, 6))
	object.AddPaint(bdf.ConicGradient(1, 2, 3))
	object.AddPaint(bdf.Pattern(0, bdf.RepeatY))
	font := object.AddFont(bdf.SystemFont("\ufeffExample sans", 700, bdf.StyleItalic))
	object.AddFont(bdf.EmbeddedFont(hash, 400, bdf.StyleNormal))
	image := object.AddImage(hash)
	child := object.AddObject(hash, bdf.Rect{X: 1, Y: 2, W: 3, H: 4})
	object.Save().Transform(1, 2, 3, 4, 5, 6).Translate(10, 11).Scale(2, 3).
		ClipPath(p, bdf.EvenOdd).ClipRect(1, 2, 3, 4).
		FillColor(0x12345678).FillPaint(linear).StrokeColor(0xabcdefff).StrokePaint(linear).
		Line(2, bdf.CapRound, bdf.JoinBevel, 4).Dash([]float32{1, 2, 3}, .5).
		Alpha(.5).Blend(2).Shadow(0xff0000ff, 1, 2, 3).Filter("blur(2px)").
		Font(font, 12).TextStyle(0, 0, 1, 0).FillRect(1, 2, 3, 4).StrokeRect(2, 3, 4, 5).
		FillPath(p, bdf.NonZero).StrokePath(ext).FillPathAt(p, bdf.EvenOdd, 2, 3).
		FillPathRun(0, []bdf.Glyph{{Path: p, X: 1, Y: 2}, {Path: ext, X: 3, Y: 4}}).
		ClearRect(1, 2, 3, 4).FillText("\ufeff日本語", 10, 20, 30).StrokeText("ABC", 4, 5, 6).
		Image(image, 1, 2, 3, 4).ImageSub(image, 1, 2, 3, 4, 5, 6, 7, 8).Smoothing(true, 2).
		Use(child).UseAt(child, 10, 20).GroupBegin(.8, 1, 1, 2, 3, 4).MaskBegin(0, 0xff, []byte{0, 1, 2}).
		MaskEnd().GroupEnd().Link(1, 2, 3, 4, "https://example.com").Mark(1, "x").
		Ext([]byte{1, 2, 3}).Restore()
	built := bdf.NewObject()
	builtFont := built.AddFont(bdf.SystemFont("\ufeffExample", 700, bdf.StyleItalic))
	builtImage := built.AddImage(hash)
	built.Save().Translate(2, 3).ClipRect(1, 2, 3, 4).FillColor(0x12345678).
		Font(builtFont, 11).TextStyle(0, 0, 1, .5).Mark(1, "\ufeffcell").
		FillText("\ufeffhello", 10, 20, 30).StrokeText("hello", -5, 4, -2).
		FillRect(2, 3, -4, 6).StrokeRect(1, 2, 3, 4).ClearRect(-100, -100, 1, 1).
		Image(builtImage, 5, 6, 7, 8).Restore()
	auto := bdf.NewObject()
	autoPath := auto.AddPath(new(bdf.Path).MoveTo(-4, 2).CubicTo(5, 6, 8, -10, 12, 15).Ellipse(3, 4, 2, 6, 0, 0, 1, false))
	empty := auto.AddPath(new(bdf.Path))
	external := auto.AddExtPath(hash, 0)
	auto.FillPath(autoPath, 0).FillPathAt(empty, 0, 50, 60).StrokePath(external).
		FillPathRun(0, []bdf.Glyph{{Path: autoPath, X: -20, Y: 10}})
	childAuto := auto.AddObject(hash, bdf.Rect{X: -1, Y: -2, W: 5, H: 10})
	auto.UseAt(childAuto, 100, -10)
	result := map[string]string{
		"object": base64.StdEncoding.EncodeToString(object.Encode()),
		"paths":  base64.StdEncoding.EncodeToString(bdf.EncodePathCollection([]*bdf.Path{path, new(bdf.Path)})),
		"built":  base64.StdEncoding.EncodeToString(built.Encode()),
		"auto":   base64.StdEncoding.EncodeToString(auto.Encode()),
	}
	if err := json.NewEncoder(os.Stdout).Encode(result); err != nil {
		panic(err)
	}
}
