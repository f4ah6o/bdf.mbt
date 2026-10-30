//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexSimplePictureVariants.
package xlsx

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexSimplePictureVariants(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	img := image.NewNRGBA(image.Rect(0, 0, 2, 2))
	img.SetNRGBA(0, 0, color.NRGBA{R: 255, A: 255})
	img.SetNRGBA(1, 0, color.NRGBA{G: 255, A: 255})
	img.SetNRGBA(0, 1, color.NRGBA{B: 255, A: 255})
	img.SetNRGBA(1, 1, color.NRGBA{R: 255, G: 255, A: 255})
	var picture bytes.Buffer
	if err := png.Encode(&picture, img); err != nil {
		t.Fatal(err)
	}
	out := []any{}
	for i := 0; i < 144; i++ {
		var b bytes.Buffer
		z := zip.NewWriter(&b)
		add := func(n string, v []byte) {
			w, err := z.Create(n)
			if err != nil {
				t.Fatal(err)
			}
			if _, err = w.Write(v); err != nil {
				t.Fatal(err)
			}
		}
		text := func(n, s string) { add(n, []byte(s)) }
		text("xl/workbook.xml", `<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet" r:id="r1"/></sheets></workbook>`)
		text("xl/_rels/workbook.xml.rels", `<Relationships><Relationship Id="r1" Type="x/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="r2" Type="x/styles" Target="styles.xml"/></Relationships>`)
		text("xl/styles.xml", `<styleSheet><cellXfs><xf/></cellXfs></styleSheet>`)
		text("xl/worksheets/_rels/sheet1.xml.rels", `<Relationships><Relationship Id="draw" Type="x/drawing" Target="../drawings/drawing1.xml"/></Relationships>`)
		text("xl/drawings/_rels/drawing1.xml.rels", `<Relationships><Relationship Id="img" Type="x/image" Target="../media/image1.png"/></Relationships>`)
		add("xl/media/image1.png", picture.Bytes())
		alts := []string{`descr=" example "`, `title=" title "`, `descr="" title="fallback"`, `descr="  "`, `descr="日本語 &amp; image"`, ``}
		pic := `<pic><nvPicPr><cNvPr id="1" name="Picture" ` + alts[(i/4)%len(alts)] + `/><cNvPicPr/></nvPicPr><blipFill><a:blip r:embed="img"/><a:stretch><a:fillRect/></a:stretch></blipFill><spPr><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></spPr></pic>`
		sizes := []int{0, 1, 12700, 457200, 914400, 1270000}
		cx, cy := sizes[(i/4)%len(sizes)], sizes[(i/24)%len(sizes)]
		var anchor string
		switch (i / 8) % 3 {
		case 0:
			anchor = fmt.Sprintf(`<twoCellAnchor><from><col>%d</col><colOff>0</colOff><row>%d</row><rowOff>0</rowOff></from><to><col>%d</col><colOff>0</colOff><row>%d</row><rowOff>0</rowOff></to>%s<clientData/></twoCellAnchor>`, i%4, i%3, i%4+(i/24)%3, i%3+(i/32)%4, pic)
		case 1:
			anchor = fmt.Sprintf(`<oneCellAnchor><from><col>%d</col><colOff>0</colOff><row>%d</row><rowOff>0</rowOff></from><ext cx="%d" cy="%d"/>%s<clientData/></oneCellAnchor>`, i%4, i%3, cx, cy, pic)
		case 2:
			anchor = fmt.Sprintf(`<absoluteAnchor><pos x="%d" y="%d"/><ext cx="%d" cy="%d"/>%s<clientData/></absoluteAnchor>`, (i%4)*127000, (i%3)*127000, cx, cy, pic)
		}
		text("xl/drawings/drawing1.xml", `<wsDr xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">`+anchor+`</wsDr>`)
		text("xl/worksheets/sheet1.xml", fmt.Sprintf(`<worksheet xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>Hello</t></is></c><c r="B1"><v>%d</v></c></row></sheetData><drawing r:id="draw"/></worksheet>`, i))
		if err := z.Close(); err != nil {
			t.Fatal(err)
		}
		mode := []string{"none", "all", "default"}[(i/2)%3]
		noIndex := i%2 == 0
		result, err := Convert(bytes.NewReader(b.Bytes()), int64(b.Len()), &Options{NoSystemFonts: true, SystemFonts: true, NoTextIndex: noIndex, Data: mode})
		if err != nil {
			t.Fatal(err)
		}
		var doc bytes.Buffer
		if err = result.Doc.WriteSingle(&doc); err != nil {
			t.Fatal(err)
		}
		out = append(out, map[string]any{"input": b.Bytes(), "bdf": doc.Bytes(), "warnings": result.Warnings, "mode": mode, "no_index": noIndex})
	}
	data, err := json.Marshal(out)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/xlsx/simple-picture-variants.json"), data, 0644); err != nil {
		t.Fatal(err)
	}
}
