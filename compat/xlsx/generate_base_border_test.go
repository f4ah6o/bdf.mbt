//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexBaseBorder.
package xlsx

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexBaseBorder(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	out := []any{}
	for i := 0; i <= 240; i++ {
		var b bytes.Buffer
		z := zip.NewWriter(&b)
		add := func(n, s string) {
			f, e := z.Create(n)
			if e != nil {
				t.Fatal(e)
			}
			if _, e = f.Write([]byte(s)); e != nil {
				t.Fatal(e)
			}
		}
		add("xl/workbook.xml", `<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet" r:id="r1"/></sheets></workbook>`)
		add("xl/_rels/workbook.xml.rels", `<Relationships><Relationship Id="r1" Type="x/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="r2" Type="x/styles" Target="styles.xml"/></Relationships>`)
		add("xl/styles.xml", `<styleSheet><fills><fill/><fill><patternFill patternType="solid"><fgColor rgb="FF112233"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFEEAA44"/></patternFill></fill></fills><borders><border/><border diagonalUp="1"><left style="thin"><color rgb="FF112233"/></left><bottom style="dashed"><color rgb="FFEEAA44"/></bottom><diagonal style="dotted"><color rgb="FF332211"/></diagonal></border><border diagonalDown="1"><top style="medium"/><right style="double"/><diagonal style="thin"/></border></borders><cellXfs><xf/><xf fillId="1" borderId="1"/><xf fillId="2" borderId="2"/></cellXfs></styleSheet>`)
		cols := []string{`<col min="1" max="3" style="1"/>`, `<col min="1" max="2" style="1"/><col min="2" max="4" style="2"/>`, `<col min="1" max="3" style="1"/><col min="2" max="2" width="10"/>`, `<col min="2" max="5" style="2"/><col min="3" max="3" hidden="1"/>`}[i%4]
		rs := []string{"", ` s="1" customFormat="1"`, ` s="2" customFormat="1"`, ` s="0" customFormat="1"`}[(i/4)%4]
		cells := []string{`<c r="A1" t="str"><v>x</v></c>`, `<c r="A1" s="2" t="str"><v>x</v></c><c r="C1"/>`, `<c r="B1" s="1"/><c r="D1" t="str"><v>y</v></c>`, `<c r="D1" t="str"><v>y</v></c>`}[(i/16)%4]
		merge := []string{"", `<mergeCells><mergeCell ref="A1:B1"/></mergeCells>`, `<mergeCells><mergeCell ref="B1:C3"/></mergeCells>`}[(i/64)%3]
		hidden := ""
		if i%5 == 0 {
			hidden = `<row r="2" hidden="1"/>`
		}
		late := ""
		if i == 240 {
			late = `<row r="20000"><c r="A20000" t="str"><v>z</v></c></row>`
		}
		add("xl/worksheets/sheet1.xml", fmt.Sprintf(`<worksheet><cols>%s</cols><sheetData><row r="1"%s>%s</row>%s<row r="3"><c r="E3" t="str"><v>z</v></c></row>%s</sheetData>%s</worksheet>`, cols, rs, cells, hidden, late, merge))
		if e := z.Close(); e != nil {
			t.Fatal(e)
		}
		if i == 240 {
			data, e := json.Marshal(b.Bytes())
			if e != nil {
				t.Fatal(e)
			}
			if e = os.WriteFile(filepath.Join(root, "compat/xlsx/base-border-too-large.json"), data, 0644); e != nil {
				t.Fatal(e)
			}
			continue
		}
		x, e := Convert(bytes.NewReader(b.Bytes()), int64(b.Len()), &Options{NoSystemFonts: true, SystemFonts: true, NoTextIndex: true, Data: "none"})
		if e != nil {
			t.Fatal(e)
		}
		var rendered bytes.Buffer
		if e = x.Doc.WriteSingle(&rendered); e != nil {
			t.Fatal(e)
		}
		out = append(out, map[string]any{"input": b.Bytes(), "bdf": rendered.Bytes(), "warnings": x.Warnings, "mode": "none", "no_index": true})
	}
	data, e := json.Marshal(out)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/base-border.json"), data, 0644); e != nil {
		t.Fatal(e)
	}
}
