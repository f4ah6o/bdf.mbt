//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexInactiveCF.
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

func TestCodexInactiveCF(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	out := []any{}
	unsupported := []any{}
	convert := func(input []byte) {
		x, e := Convert(bytes.NewReader(input), int64(len(input)), &Options{NoSystemFonts: true, SystemFonts: true, NoTextIndex: true, Data: "none"})
		if e != nil {
			t.Fatal(e)
		}
		var b bytes.Buffer
		if e = x.Doc.WriteSingle(&b); e != nil {
			t.Fatal(e)
		}
		out = append(out, map[string]any{"input": input, "bdf": b.Bytes(), "warnings": x.Warnings, "mode": "none", "no_index": true})
	}
	real, e := os.ReadFile("testdata/form-rows.xlsx")
	if e != nil {
		t.Fatal(e)
	}
	convert(real)
	for i := 0; i < 168; i++ {
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
		add("xl/styles.xml", `<styleSheet><fonts><font/></fonts><fills><fill/></fills><borders><border/></borders><cellXfs><xf/></cellXfs><dxfs><dxf><font><b/><color rgb="FFCC0000"/></font></dxf></dxfs></styleSheet>`)
		n := []string{"-5", "0", "1", "5", "9", ""}[i%6]
		cell := fmt.Sprintf(`<c r="A1"><v>%s</v></c>`, n)
		op := []string{"greaterThan", "greaterThanOrEqual"}[(i/6)%2]
		formula := "10"
		ref := []string{"A1", "A1:C3", "B1:C3", "A1 B1:C3"}[(i/12)%4]
		rule := fmt.Sprintf(`<cfRule type="cellIs" operator="%s" dxfId="0"><formula>%s</formula></cfRule>`, op, formula)
		if i >= 160 {
			switch i - 160 {
			case 0:
				rule = `<cfRule type="expression"><formula>TRUE</formula></cfRule>`
			case 1:
				cell = `<c r="A1"><v>11</v></c>`
				rule = `<cfRule type="cellIs" operator="greaterThan"><formula>10</formula></cfRule>`
			case 2:
				cell = `<c r="A1" t="str"><v>x</v></c>`
			case 3:
				rule = `<cfRule type="cellIs" operator="equal"><formula>0</formula></cfRule>`
			case 4:
				rule = `<cfRule type="cellIs" operator="greaterThan"><formula>0</formula></cfRule>`
			case 5:
				rule = `<cfRule type="cellIs" operator="greaterThan"><formula>A2</formula></cfRule>`
			case 6:
				rule = `<cfRule type="cellIs" operator="greaterThan"><formula>10</formula><formula>20</formula></cfRule>`
			case 7:
				rule += rule
			}
			ref = "A1"
		}
		second := ""
		if i%7 == 0 && i < 160 {
			second = `<conditionalFormatting sqref="C3"><cfRule type="cellIs" operator="greaterThan"><formula>1</formula></cfRule></conditionalFormatting>`
		}
		add("xl/worksheets/sheet1.xml", fmt.Sprintf(`<worksheet><sheetData><row r="1">%s</row><row r="3"><c r="D3"><v>5</v></c></row></sheetData><conditionalFormatting sqref="%s">%s</conditionalFormatting>%s</worksheet>`, cell, ref, rule, second))
		if e = z.Close(); e != nil {
			t.Fatal(e)
		}
		if i >= 160 {
			unsupported = append(unsupported, b.Bytes())
		} else {
			convert(b.Bytes())
		}
	}
	for name, v := range map[string]any{"inactive-cf.json": out, "inactive-cf-unsupported.json": unsupported} {
		data, e := json.Marshal(v)
		if e != nil {
			t.Fatal(e)
		}
		if e = os.WriteFile(filepath.Join(root, "compat/xlsx", name), data, 0644); e != nil {
			t.Fatal(e)
		}
	}
}
