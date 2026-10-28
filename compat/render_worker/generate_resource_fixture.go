//go:build ignore

// Generate resource-fixture.bdf with shibukawa/bdf v0.2.1 (commit 4f9af52).
// Run this file from that checkout: go run <path>/generate_resource_fixture.go <output>.
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
	doc := bdf.NewDocument()
	var hashes []bdf.Hash
	for _, c := range []color.RGBA{{R: 255, A: 255}, {G: 255, A: 255}, {B: 255, A: 255}} {
		img := image.NewRGBA(image.Rect(0, 0, 2, 2))
		for y := 0; y < 2; y++ {
			for x := 0; x < 2; x++ {
				img.SetRGBA(x, y, c)
			}
		}
		var data bytes.Buffer
		if err := png.Encode(&data, img); err != nil {
			panic(err)
		}
		hashes = append(hashes, doc.AddImage(data.Bytes()))
	}
	view := doc.NewView("pages", bdf.ViewFixed, "")
	for _, images := range [][]int{{0}, {1}, {2}, {0, 1}} {
		obj := bdf.NewObject().SetBBox(0, 0, 40, 20)
		for i, index := range images {
			ref := obj.AddImage(hashes[index])
			obj.Image(ref, float32(i*20), 0, 20, 20)
		}
		hash, _ := doc.AddObject(obj)
		view.AddPage(40, 20, bdf.Layer{Role: bdf.RoleBody, Obj: hash})
	}
	f, err := os.Create(os.Args[1])
	if err != nil {
		panic(err)
	}
	defer f.Close()
	if err := doc.WriteSingle(f); err != nil {
		panic(err)
	}
}
