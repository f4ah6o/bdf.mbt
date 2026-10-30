//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexConditionalDisjointMatches.
package xlsx

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCodexConditionalDisjointMatches(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	out := []any{}
	for i := 0; i < 512; i++ {
		var b bytes.Buffer
		z := zip.NewWriter(&b)
		add := func(name, value string) {
			w, e := z.Create(name)
			if e != nil {
				t.Fatal(e)
			}
			if _, e = w.Write([]byte(value)); e != nil {
				t.Fatal(e)
			}
		}
		add("xl/workbook.xml", `<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet" r:id="r1"/></sheets></workbook>`)
		add("xl/_rels/workbook.xml.rels", `<Relationships><Relationship Id="r1" Type="x/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="r2" Type="x/styles" Target="styles.xml"/></Relationships>`)
		add("xl/styles.xml", `<styleSheet><dxfs><dxf><font><b/></font></dxf><dxf><font><i/><color rgb="FF112233"/></font></dxf><dxf><fill><patternFill><bgColor rgb="FFCCEEAA"/></patternFill></fill></dxf><dxf><border><bottom style="thin"/></border></dxf></dxfs></styleSheet>`)
		variants := []string{
			`<cfRule type="cellIs" operator="greaterThan" dxfId="%d"><formula>0</formula></cfRule>`,
			`<cfRule type="cellIs" operator="lessThan" dxfId="%d"><formula>0</formula></cfRule>`,
		}
		v1, v2 := i%2, 1-i%2
		s1 := (i / 2) % 4
		s2 := (s1 + (i/8)%3 + 1) % 4
		first := fmt.Sprintf(variants[v1], s1)
		second := fmt.Sprintf(variants[v2], s2)
		if i%2 != 0 {
			first, second = second, first
		}
		if i%4 >= 2 {
			first = strings.Replace(first, "<cfRule ", `<cfRule priority="2" stopIfTrue="1" `, 1)
			second = strings.Replace(second, "<cfRule ", `<cfRule priority="1" `, 1)
		}
		first = `<conditionalFormatting sqref="A1:D2">` + first + second + `</conditionalFormatting>`
		second = ""
		sheet := fmt.Sprintf(`<worksheet><sheetData><row r="1"><c r="A1"><v>-1</v></c><c r="B1"><v>3</v></c><c r="D1"><v>0</v></c><c r="E1"><v>1</v></c></row><row r="2"><c r="A2"><v>4</v></c><c r="D2"><v>-2</v></c><c r="E2"><v>5</v></c></row></sheetData>%s%s</worksheet>`, first, second)
		add("xl/worksheets/sheet1.xml", sheet)
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
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/conditional-disjoint-matches.json"), data, 0644); e != nil {
		t.Fatal(e)
	}
}
