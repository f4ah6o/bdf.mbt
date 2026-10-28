//go:build ignore

// Generate flow and scroll fixtures with shibukawa/bdf v0.2.1.
package main

import (
	"fmt"
	bdf "github.com/shibukawa/bdf"
	"os"
)

func write(d *bdf.Document, single, split string) {
	out, err := os.Create(single)
	if err != nil {
		panic(err)
	}
	if err = d.WriteSingle(out); err != nil {
		panic(err)
	}
	if err = out.Close(); err != nil {
		panic(err)
	}
	if err = d.WriteSplit(split); err != nil {
		panic(err)
	}
}

func main() {
	flow := bdf.NewDocument()
	v := flow.NewView("flow", bdf.ViewFlow, "Flow")
	v.Direction = bdf.DirectionRTL
	v.Continuous = &bdf.Continuous{Gap: 12.5}
	for i := 0; i < 3; i++ {
		background := bdf.NewObject().SetBBox(0, 0, 200, 120)
		background.FillColor(0xd23c3cff).FillRect(0, 0, 200, 120)
		back, _ := flow.AddObject(background)
		body := bdf.NewObject().SetBBox(0, 0, 200, 120)
		font := body.AddFont(bdf.SystemFont("sans-serif", 400, bdf.StyleNormal))
		colors := []bdf.Color{0xcee5ffff, 0xffe1baff, 0xd7f4d4ff}
		body.FillColor(colors[i]).FillRect(5, 5, 190, 110).FillColor(0x20354aff).Font(font, 16).FillText(fmt.Sprintf("Band %d", i+1), 28, 48, 60)
		content, _ := flow.AddObject(body)
		annotation := bdf.NewObject().SetBBox(0, 0, 200, 120)
		annotation.FillColor(0x5f37c0ff).FillRect(145, 75, 36, 20)
		if i == 0 {
			// A later object must not inherit alpha or the transform.
			annotation.Alpha(0.25).Translate(17, 9)
		}
		note, _ := flow.AddObject(annotation)
		layers := []bdf.Layer{{Role: bdf.RoleBackground, Obj: back}, {Role: bdf.RoleBody, Obj: content}, {Role: bdf.RoleAnnotation, Obj: note}}
		if i == 0 {
			initial := bdf.NewObject().SetBBox(0, 0, 200, 120)
			initial.FillRect(105, 45, 16, 12)
			reset, _ := flow.AddObject(initial)
			layers = append(layers, bdf.Layer{Role: bdf.RoleBody, Obj: reset})
		}
		page := v.AddPage(200, 120, layers...)
		if i == 0 {
			page.Body = &bdf.RectDef{X: 20, Y: 15, W: 150, H: 80}
		}
		if i == 1 {
			page.Body = &bdf.RectDef{X: 30, Y: 25, W: 130, H: 60}
		}
	}
	write(flow, os.Args[1], os.Args[2])
	flowLock, err := bdf.NewPasswordLock("pass", 1000)
	if err != nil {
		panic(err)
	}
	flow.Lock = flowLock
	write(flow, os.Args[7], os.Args[8])
	scroll := bdf.NewDocument()
	s := scroll.NewView("scroll", bdf.ViewScroll, "Scroll")
	heights := []float32{80, 100, 120}
	for i, h := range heights {
		o := bdf.NewObject().SetBBox(0, 0, 200, h)
		f := o.AddFont(bdf.SystemFont("sans-serif", 400, bdf.StyleNormal))
		colors := []bdf.Color{0xcee5ffff, 0xffe1baff, 0xd7f4d4ff}
		o.FillColor(colors[i]).FillRect(0, 0, 200, h).FillColor(0x20354aff).Font(f, 16).FillText(fmt.Sprintf("Strip %d", i+1), 20, 35, 55)
		if i == 0 {
			o.Alpha(0.25).Translate(17, 9)
		}
		hash, _ := scroll.AddObject(o)
		layers := []bdf.Layer{{Role: bdf.RoleBody, Obj: hash}}
		if i == 0 {
			// The second layer relies on the Canvas default black fill.
			initial := bdf.NewObject().SetBBox(0, 0, 200, h)
			initial.FillRect(140, 10, 20, 20)
			reset, _ := scroll.AddObject(initial)
			layers = append(layers, bdf.Layer{Role: bdf.RoleAnnotation, Obj: reset})
		}
		s.AddPage(200, h, layers...)
	}
	write(scroll, os.Args[3], os.Args[4])
	lock, err := bdf.NewPasswordLock("pass", 1000)
	if err != nil {
		panic(err)
	}
	scroll.Lock = lock
	write(scroll, os.Args[5], os.Args[6])
}
