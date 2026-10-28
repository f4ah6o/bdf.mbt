//go:build ignore

// Generate text extraction fixtures using shibukawa/bdf v0.2.1.
package main

import (
	bdf "github.com/shibukawa/bdf"
	"os"
	"path/filepath"
)

func main() {
	dir := os.Args[1]
	d := bdf.NewDocument()
	child := bdf.NewObject().SetBBox(2, 3, 20, 10).FillText("child", 5, 7, 12)
	h, box := d.AddObject(child)
	o := bdf.NewObject()
	font := o.AddFont(bdf.SystemFont("serif", 400, bdf.StyleNormal))
	p := o.AddPath((&bdf.Path{}).Rect(0, 0, 10, 10))
	ref := o.AddObject(h, box)
	o.Font(font, 10).Mark(bdf.MarkParagraph, "").FillText("Hello", 0, 0, 30).FillText("World", 35, 0, 30)
	o.Mark(bdf.MarkLine, "").FillText("second", 0, 15, 40).Mark(bdf.MarkWrap, "").FillText("wrapped", 0, 30, 40)
	o.Mark(bdf.MarkLang, "ja").Mark(bdf.MarkAltText, "outlined").FillPathAt(p, bdf.NonZero, 5, 45)
	o.Save().Translate(100, 100).Use(ref).Restore()
	o.Mark(bdf.MarkAltText, "drawn by a child").UseAt(ref, 50, 150)
	o.Save().Transform(0, 1, -1, 0, 20, 30).Link(1, 2, 3, 4, "https://example.org/").Restore()
	o.MaskBegin(bdf.MaskAlpha, 0, nil).FillText("hidden", 0, 0, 10).Mark(bdf.MarkAltText, "hidden-alt").MaskEnd()
	o.Mark(bdf.MarkAltText, "orphan")
	if err := os.MkdirAll(dir, 0755); err != nil {
		panic(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "parent.bobj"), o.Encode(), 0644); err != nil {
		panic(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "child.bobj"), child.Encode(), 0644); err != nil {
		panic(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "child.hash"), []byte(h.String()), 0644); err != nil {
		panic(err)
	}
}
