//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexSheetAutoFilterTiles.
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

func TestCodexSheetAutoFilterTiles(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	ranges := []string{"AO1:AS4", "A145:C146", "C1:A1", "$A$1:$C$3", "1:3", "A:AZ", "A1:C3", "invalid"}
	out := []any{}
	for i := 0; i < 128; i++ {
		var b bytes.Buffer
		z := zip.NewWriter(&b)
		add := func(n, s string) {
			w, e := z.Create(n)
			if e != nil {
				t.Fatal(e)
			}
			if _, e = w.Write([]byte(s)); e != nil {
				t.Fatal(e)
			}
		}
		add("xl/workbook.xml", `<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet" r:id="r1"/></sheets></workbook>`)
		add("xl/_rels/workbook.xml.rels", `<Relationships><Relationship Id="r1" Type="x/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="r2" Type="x/styles" Target="styles.xml"/></Relationships>`)
		add("xl/styles.xml", `<styleSheet><fonts><font/><font><b/></font></fonts><cellXfs><xf/><xf fontId="1"/></cellXfs></styleSheet>`)
		columns := []string{``, `<cols><col min="1" max="1" width="2" customWidth="1"/><col min="2" max="2" width="18" customWidth="1"/></cols>`, `<cols><col min="2" max="2" hidden="1"/></cols>`, `<cols><col min="1" max="1" width="0.1" customWidth="1"/></cols>`}[(i/8)%4]
		row := []string{``, ` ht="25" customHeight="1"`, ` hidden="1"`, ` ht="2" customHeight="1"`}[(i/32)%4]
		grid := `1`
		if i%2 != 0 {
			grid = `0`
		}
		body := fmt.Sprintf(`<worksheet><sheetViews><sheetView showGridLines="%s"/></sheetViews>%s<sheetData><row r="1"%s><c r="A1" t="inlineStr"><is><t>Header</t></is></c><c r="B1" s="1"><v>42</v></c></row><row r="2"><c r="C2"><v>3</v></c></row><row r="145"><c r="AS145"><v>7</v></c></row></sheetData><autoFilter ref="%s"><filterColumn colId="0"/></autoFilter></worksheet>`, grid, columns, row, ranges[i%len(ranges)])
		add("xl/worksheets/sheet1.xml", body)
		if e := z.Close(); e != nil {
			t.Fatal(e)
		}
		result, e := Convert(bytes.NewReader(b.Bytes()), int64(b.Len()), &Options{NoSystemFonts: true, SystemFonts: true, NoTextIndex: true, Data: "none"})
		if e != nil {
			t.Fatal(e)
		}
		var doc bytes.Buffer
		if e = result.Doc.WriteSingle(&doc); e != nil {
			t.Fatal(e)
		}
		out = append(out, map[string]any{"input": b.Bytes(), "bdf": doc.Bytes(), "warnings": result.Warnings, "mode": "none", "no_index": true})
	}
	data, e := json.Marshal(out)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/sheet-autofilter-tiles.json"), data, 0644); e != nil {
		t.Fatal(e)
	}
}
