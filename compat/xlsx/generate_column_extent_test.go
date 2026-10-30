//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexColumnExtent.
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
	"strings"
	"testing"
)

func TestCodexColumnExtent(t *testing.T) {
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
	img.SetNRGBA(0, 0, color.NRGBA{R: 120, G: 30, B: 40, A: 255})
	var otherPicture bytes.Buffer
	if err := png.Encode(&otherPicture, img); err != nil {
		t.Fatal(err)
	}
	out := []any{}
	for i := 0; i < 96; i++ {
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
		text("xl/drawings/_rels/drawing1.xml.rels", `<Relationships><Relationship Id="img" Type="x/image" Target="../media/image1.png"/><Relationship Id="img2" Type="x/image" Target="../media/image2.png"/></Relationships>`)
		add("xl/media/image1.png", picture.Bytes())
		add("xl/media/image2.png", otherPicture.Bytes())
		pic := `<pic><nvPicPr><cNvPr id="1" name="Picture" descr="example"/><cNvPicPr/></nvPicPr><blipFill><a:blip r:embed="img"/><a:stretch><a:fillRect/></a:stretch></blipFill><spPr><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></spPr></pic>`
		anchor := fmt.Sprintf(`<absoluteAnchor><pos x="12700000" y="0"/><ext cx="914400" cy="457200"/>%s<clientData/></absoluteAnchor>`, pic)
		secondPic := strings.Replace(pic, `r:embed="img"`, `r:embed="img2"`, 1)
		secondPic = strings.Replace(secondPic, `descr="example"`, `descr="second image"`, 1)
		second := fmt.Sprintf(`<twoCellAnchor><from><col>0</col><colOff>0</colOff><row>0</row><rowOff>0</rowOff></from><to><col>1</col><colOff>0</colOff><row>2</row><rowOff>0</rowOff></to>%s<clientData/></twoCellAnchor>`, secondPic)
		if i%2 == 1 {
			anchor, second = second, anchor
		}
		text("xl/drawings/drawing1.xml", `<wsDr xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">`+anchor+second+`</wsDr>`)
		cells := fmt.Sprintf(`<row r="1"><c r="A1" t="inlineStr"><is><t>Hello</t></is></c><c r="B1"><v>%d</v></c></row>`, i)
		if (i/2)%2 == 1 {
			cells = ""
		}
		cols := []string{`<col min="3" max="100" hidden="1"/>`, `<col min="30" max="40" width="20"/>`, `<col min="5" max="200" width="9"/><col min="20" max="120" hidden="1"/>`, `<col min="50" max="100" width="8.43"/>`, `<col min="16384" max="16384" hidden="1"/>`, `<col min="10" max="150" hidden="1"/><col min="20" max="100" width="8"/>`}[(i/4)%6]
        text("xl/worksheets/sheet1.xml", `<worksheet xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><cols>`+cols+`</cols><sheetData>`+cells+`</sheetData></worksheet>`)
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
	if err = os.WriteFile(filepath.Join(root, "compat/xlsx/column-extent.json"), data, 0644); err != nil {
		t.Fatal(err)
	}
}
