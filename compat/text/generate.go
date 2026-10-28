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

	structured := bdf.NewObject()
	f := structured.AddFont(bdf.SystemFont("sans-serif", 400, bdf.StyleNormal))
	img := structured.AddImage(bdf.HashOf([]byte("picture")))
	shape := structured.AddPath((&bdf.Path{}).Rect(0, 0, 10, 10))
	childRef := structured.AddObject(h, box)
	structured.Font(f, 10)
	structured.Mark(bdf.MarkHeading, "2").FillText("Title", 0, 0, 25)
	structured.Mark(bdf.MarkList, "").Mark(bdf.MarkListItem, "").FillText("one", 0, 15, 15)
	structured.Mark(bdf.MarkList, "").Mark(bdf.MarkListItem, "").FillText("nested", 10, 30, 30).Mark(bdf.MarkEnd, "")
	structured.Mark(bdf.MarkListItem, "").FillText("two", 0, 45, 15).Link(0, 37, 15, 10, "https://example.com/").Mark(bdf.MarkEnd, "")
	structured.Mark(bdf.MarkTable, "").FillText("caption", 0, 60, 35)
	structured.Mark(bdf.MarkCell, "A1 col").FillText("head", 0, 75, 20).Mark(bdf.MarkCell, "B1:C1").FillText("wide", 30, 75, 20).Mark(bdf.MarkEnd, "")
	structured.Mark(bdf.MarkParagraph, "").FillText("before", 0, 90, 30).Image(img, 0, 100, 50, 50)
	structured.Mark(bdf.MarkFigure, "chart").Mark(bdf.MarkData, "chart-1").Save().ClipRect(0, 160, 30, 30).Image(img, 0, 160, 50, 50).Restore().FillText("label", 0, 220, 25).Mark(bdf.MarkEnd, "")
	structured.Mark(bdf.MarkLang, "ja").Mark(bdf.MarkCell, "B12").FillText("セル", 0, 240, 20)
	structured.Mark(bdf.MarkLang, "").Mark(bdf.MarkBox, "P quote").FillText("said", 0, 255, 20)
	structured.Mark(bdf.MarkParagraph, "code quote quote").FillText("x := 1", 0, 270, 30)
	structured.Mark(bdf.MarkList, "ordered quote").Mark(bdf.MarkListItem, "").FillText("step", 0, 285, 20).Mark(bdf.MarkEnd, "")
	structured.Mark(bdf.MarkFigure, "path figure").Save().Translate(10, 300).FillPathAt(shape, bdf.NonZero, 5, 2).Restore().Mark(bdf.MarkEnd, "")
	structured.Mark(bdf.MarkFigure, "child figure").Mark(bdf.MarkAltText, "child text").UseAt(childRef, 50, 300).Mark(bdf.MarkEnd, "")
	structured.Save().Translate(33, 44).Mark(bdf.MarkFigure, "empty").Mark(bdf.MarkEnd, "").Restore()
	structured.Mark(bdf.MarkFigure, "clipped").Save().Translate(200, 100).ClipPath(shape, bdf.NonZero).FillRect(-5, -5, 30, 30).Restore().Mark(bdf.MarkEnd, "")
	structured.Mark(bdf.MarkFigure, "mask-only").MaskBegin(bdf.MaskAlpha, 0, nil).FillRect(1, 2, 3, 4).MaskEnd().Mark(bdf.MarkEnd, "")
	structured.Mark(bdf.MarkFigure, "outer").Mark(bdf.MarkFigure, "inner").FillRect(11, 12, 13, 14).Mark(bdf.MarkEnd, "").Mark(bdf.MarkEnd, "")
	structured.Mark(bdf.MarkHeading, "0x2").FillText("hex", 0, 0, 0)
	structured.Mark(bdf.MarkHeading, "2e0").FillText("exp", 0, 0, 0)
	structured.Mark(bdf.MarkHeading, "7").FillText("invalid", 0, 0, 0)

	cells := bdf.NewObject()
	cells.Mark(bdf.MarkTable, "").Mark(bdf.MarkCell, "A1").FillText("a", 0, 0, 5).Mark(bdf.MarkLine, "").FillText("b", 0, 10, 5).Mark(bdf.MarkParagraph, "").FillText("c", 0, 20, 5)
	cells.Mark(bdf.MarkCell, "A1").FillText("duplicate", 0, 30, 20)
	cells.Mark(bdf.MarkCell, "B1").Mark(bdf.MarkCell, "C1").FillText("outer", 30, 30, 20)
	cells.Mark(bdf.MarkTable, "").Mark(bdf.MarkCell, "A1").FillText("inner", 30, 40, 20).Mark(bdf.MarkEnd, "").Mark(bdf.MarkEnd, "")
	cells.Mark(bdf.MarkCell, "D4").FillText("sheet", 0, 60, 25)
	if err := os.MkdirAll(dir, 0755); err != nil {
		panic(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "cells.bobj"), cells.Encode(), 0644); err != nil {
		panic(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "structure.bobj"), structured.Encode(), 0644); err != nil {
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
