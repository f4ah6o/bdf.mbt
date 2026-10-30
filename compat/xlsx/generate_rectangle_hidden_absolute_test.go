//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexRectangleHiddenAbsolute.
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

func TestCodexRectangleHiddenAbsolute(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	img := image.NewNRGBA(image.Rect(0, 0, 17, 29))
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
		text("xl/drawings/_rels/drawing1.xml.rels", `<Relationships><Relationship Id="img" Type="x/image" Target="../media/image1.png"/><Relationship Id="img2" Type="x/image" Target="../media/image2.png"/></Relationships>`)
		add("xl/media/image1.png", picture.Bytes())
		add("xl/media/image2.png", otherPicture.Bytes())
		pic := fmt.Sprintf(`<sp><nvSpPr><cNvPr id="1" name="Rectangle" descr="example"/><cNvSpPr/></nvSpPr><spPr><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val="%s"/></a:solidFill><a:ln><a:noFill/></a:ln></spPr></sp>`, []string{"FF0000", "00FF00", "0000FF", "FFA0D4", "012345", "FFFFFF", "000000"}[i%7])
		pic = strings.Replace(pic, `descr="example"`, fmt.Sprintf(`descr="example" hidden="%s"`, []string{"1", "true", "0", "false"}[i%4]), 1)
		positions := []int{-254000000, -1270000, -1, 0, 12700, 508000, 25400000, 26035000, 254000000}
		anchor := fmt.Sprintf(`<absoluteAnchor><pos x="%d" y="%d"/><ext cx="914400" cy="457200"/>%s<clientData/></absoluteAnchor>`, positions[(i/2)%len(positions)], positions[(i/3)%len(positions)], pic)
		secondPic := strings.Replace(pic, `r:embed="img"`, `r:embed="img2"`, 1)
		secondPic = strings.Replace(secondPic, `descr="example"`, `descr="second image"`, 1)
		secondPic = strings.Replace(secondPic, fmt.Sprintf(`hidden="%s"`, []string{"1", "true", "0", "false"}[i%4]), fmt.Sprintf(`hidden="%s"`, []string{"1", "true", "0", "false"}[(i/5)%4]), 1)
		second := fmt.Sprintf(`<absoluteAnchor><pos x="%d" y="%d"/><ext cx="914400" cy="457200"/>%s<clientData/></absoluteAnchor>`, positions[(i/4)%len(positions)], positions[(i/5)%len(positions)], secondPic)
		amt := []int{0, 12500, 25000, 50000, 75000, 100000}[(i/2)%6]
		alpha := fmt.Sprintf(`<a:alphaModFix amt="%d"/>`, amt)
		anchor = strings.Replace(anchor, `r:embed="img"/>`, `r:embed="img">`+alpha+`</a:blip>`, 1)
		secondAlpha := fmt.Sprintf(`<a:alphaModFix amt="%d"/>`, []int{0, 12500, 25000, 50000, 75000, 100000}[(i/3+1)%6])
		if i%3 == 0 {
			secondAlpha = ""
		}
		second = strings.Replace(second, `r:embed="img2"/>`, `r:embed="img2">`+secondAlpha+`</a:blip>`, 1)
		vals := []int{0, 12500, 25000, 50000}
		fr := fmt.Sprintf(`<a:fillRect l="%d" t="%d" r="%d" b="%d"/>`, vals[(i/2)%4], vals[(i/3)%4], vals[(i/4)%4], vals[(i/5)%4])
		anchor = strings.Replace(anchor, `<a:fillRect/>`, fr, 1)
		second = strings.Replace(second, `<a:fillRect/>`, fr, 1)
		anchor = strings.Replace(anchor, "<colOff>0</colOff>", fmt.Sprintf("<colOff>%d</colOff>", vals[(i/6)%4]), 1)
		second = strings.Replace(second, "<rowOff>0</rowOff>", fmt.Sprintf("<rowOff>%d</rowOff>", vals[(i/7)%4]), 1)
		cr := fmt.Sprintf(`<a:srcRect l="%d" t="%d" r="%d" b="%d"/><a:stretch>`, []int{0, 12345, 33333}[(i/3)%3], []int{0, 12345, 33333}[(i/4)%3], []int{0, 12345, 33333}[(i/5)%3], []int{0, 12345, 33333}[(i/6)%3])
		anchor = strings.Replace(anchor, `<a:stretch>`, cr, 1)
		second = strings.Replace(second, `<a:stretch>`, cr, 1)
		text("xl/drawings/drawing1.xml", `<wsDr xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">`+anchor+second+`</wsDr>`)
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
	if err = os.WriteFile(filepath.Join(root, "compat/xlsx/rectangle-hidden-absolute.json"), data, 0644); err != nil {
		t.Fatal(err)
	}
}
