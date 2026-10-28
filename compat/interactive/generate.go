//go:build ignore

// Generate an interactive-text fixture using shibukawa/bdf v0.2.1.
package main

import (
	bdf "github.com/shibukawa/bdf"
	"os"
)

func main() {
	d := bdf.NewDocument()
	o := bdf.NewObject().SetBBox(0, 0, 640, 400)
	f := o.AddFont(bdf.SystemFont("sans-serif", 400, bdf.StyleNormal))
	o.FillColor(0xffffffff).FillRect(0, 0, 640, 400).FillColor(0x16283fff).Font(f, 24)
	o.Mark(bdf.MarkHeading, "2").FillText("Document example", 30, 50, 220)
	o.Font(f, 18).Mark(bdf.MarkParagraph, "").FillText("Hello", 30, 90, 45).FillText("world", 83, 90, 48)
	o.Mark(bdf.MarkLine, "").FillText("Second line", 30, 120, 100)
	o.Mark(bdf.MarkParagraph, "").FillText("Jump to page", 30, 160, 110).Link(28, 140, 120, 25, "#page=1")
	o.Link(450, 30, 30, 20, "javascript:alert(1)")
	o.Mark(bdf.MarkTable, "").Mark(bdf.MarkCell, "A1 col").FillText("Header", 30, 210, 60).Mark(bdf.MarkCell, "B1:C1 col").FillText("Value", 160, 210, 50)
	o.Mark(bdf.MarkCell, "A2").FillText("Price", 30, 240, 45).Mark(bdf.MarkCell, "B2").FillText("42", 160, 240, 20).Mark(bdf.MarkEnd, "")
	o.Mark(bdf.MarkTable, "").Mark(bdf.MarkCell, "A1").FillText("Far left", 320, 210, 65).Mark(bdf.MarkCell, "ZZ10000").FillText("Far right", 460, 240, 70).Mark(bdf.MarkEnd, "")
	o.Mark(bdf.MarkFigure, "Example chart").FillColor(0x5d8dddff).FillRect(30, 280, 120, 55).FillColor(0xffffffff).FillText("Chart", 45, 315, 48).Mark(bdf.MarkEnd, "")
	h, _ := d.AddObject(o)
	annotation := bdf.NewObject().SetBBox(0, 0, 640, 400)
	af := annotation.AddFont(bdf.SystemFont("sans-serif", 400, bdf.StyleNormal))
	annotation.FillColor(0x16283fff).Font(af, 18).Mark(bdf.MarkParagraph, "").FillText("Annotation", 360, 370, 90)
	annotation.Mark(bdf.MarkTable, "").Mark(bdf.MarkCell, "D4").FillText("Anno X", 300, 320, 65).Mark(bdf.MarkCell, "E4").FillText("Anno Y", 450, 320, 65).Mark(bdf.MarkEnd, "")
	ah, _ := d.AddObject(annotation)
	view := d.NewView("p", bdf.ViewFixed, "")
	view.AddPage(640, 400, bdf.Layer{Role: bdf.RoleBody, Obj: h}, bdf.Layer{Role: bdf.RoleAnnotation, Obj: ah})
	page2 := bdf.NewObject().SetBBox(0, 0, 640, 160)
	pf := page2.AddFont(bdf.SystemFont("sans-serif", 400, bdf.StyleNormal))
	page2.FillColor(0xffffffff).FillRect(0, 0, 640, 160).FillColor(0x16283fff).Font(pf, 18).Mark(bdf.MarkParagraph, "").FillText("Second page", 30, 50, 100)
	ph, _ := d.AddObject(page2)
	view.AddPage(640, 160, bdf.Layer{Role: bdf.RoleBody, Obj: ph})
	file, err := os.Create(os.Args[1])
	if err != nil {
		panic(err)
	}
	defer file.Close()
	if err = d.WriteSingle(file); err != nil {
		panic(err)
	}
}
