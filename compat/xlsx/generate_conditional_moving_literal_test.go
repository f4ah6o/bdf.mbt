//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexConditionalMovingLiteral.
package xlsx

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCodexConditionalMovingLiteral(t *testing.T) {
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
	raw, e := os.ReadFile("testdata/form-rows.xlsx")
	if e != nil {
		t.Fatal(e)
	}
	orig, e := zip.NewReader(bytes.NewReader(raw), int64(len(raw)))
	if e != nil {
		t.Fatal(e)
	}
	var real bytes.Buffer
	zw := zip.NewWriter(&real)
	for _, p := range orig.File {
		r, e := p.Open()
		if e != nil {
			t.Fatal(e)
		}
		data, e := io.ReadAll(r)
		r.Close()
		if e != nil {
			t.Fatal(e)
		}
		if p.Name == "xl/worksheets/sheet1.xml" {
			old := `<c r="E4" s="4"><f>C4*D4</f><v></v></c>`
			updated := strings.Replace(string(data), old, `<c r="E4" s="4"><f>C4*D4</f><v>1500</v></c>`, 1)
			if updated == string(data) {
				t.Fatal("expected cell missing")
			}
			data = []byte(updated)
		}
		w, e := zw.Create(p.Name)
		if e != nil {
			t.Fatal(e)
		}
		if _, e = w.Write(data); e != nil {
			t.Fatal(e)
		}
	}
	if e = zw.Close(); e != nil {
		t.Fatal(e)
	}
	convert(real.Bytes())
	fonts := []string{`<font><b/></font>`, `<fill><patternFill><bgColor rgb="FFCCEEAA"/></patternFill></fill>`, `<border><bottom style="thin"/></border>`, `<font><i/><color rgb="FF112233"/></font><fill><patternFill><bgColor rgb="FFCCEEAA"/></patternFill></fill>`}
	for i := 0; i < 329; i++ {
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
		secondSheet, secondRel := "", ""
		if i%11 == 0 {
			secondSheet = `<sheet name="Other" r:id="r3"/>`
			secondRel = `<Relationship Id="r3" Type="x/worksheet" Target="worksheets/sheet2.xml"/>`
			add("xl/worksheets/sheet2.xml", `<worksheet><sheetData><row r="1"><c r="A1" s="3" t="str"><v>invalid style falls back</v></c><c r="B1" s="2" t="str"><v>invalid font falls back</v></c></row></sheetData></worksheet>`)
		}
		add("xl/workbook.xml", `<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet" r:id="r1"/>`+secondSheet+`</sheets></workbook>`)
		add("xl/_rels/workbook.xml.rels", `<Relationships><Relationship Id="r1" Type="x/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="r2" Type="x/styles" Target="styles.xml"/>`+secondRel+`</Relationships>`)
		dxf := fonts[i%len(fonts)]
		if i >= 320 {
			switch i - 320 {
			case 0:
				dxf = `<fill><patternFill patternType="darkGray"><fgColor rgb="FFFF0000"/></patternFill></fill>`
			case 1:
				dxf = `<border/><border/>`
			case 2:
				dxf = `<numFmt formatCode="0.00"/>`
			case 3:
				dxf = `<font><sz val="20"/></font>`
			case 4:
				dxf = `<font><u val="singleAccounting"/></font>`
			case 5:
				dxf = `<font><b/></font><font><i/></font>`
			}
		}
		if i >= 320 && i < 326 {
			dxf = `<font><b/></font>`
		}
		add("xl/styles.xml", fmt.Sprintf(`<styleSheet><numFmts><numFmt numFmtId="164" formatCode="[Red]0"/></numFmts><fonts><font><name val="Calibri"/><sz val="11"/></font><font><name val="Calibri"/><sz val="11"/><b/></font></fonts><fills><fill/><fill><patternFill patternType="solid"><fgColor rgb="FF00BB00"/></patternFill></fill></fills><borders><border/><border diagonalDown="1"><top style="medium"/><right style="thin"/><diagonal style="dotted"/></border></borders><cellXfs><xf fontId="0" fillId="0" borderId="0"/><xf fontId="1" fillId="1" borderId="1" numFmtId="164" applyAlignment="1"><alignment wrapText="1"/></xf><xf fontId="2" fillId="2" borderId="2"/></cellXfs><dxfs><dxf>%s</dxf></dxfs></styleSheet>`, dxf))
		style := (i / 8) % 2
		formulas := []string{`"Foo"`, `"É"`, `"A""B"`, `TRUE`, `FALSE`, `"𐐀"`, `""`, `-1`, `0`, `1`}
		values := []string{"foo", "é", `A"B`, "true", "False", "𐐨", "", "-1", "0", "1"}
		operators := []string{"lessThan", "lessThanOrEqual", "equal", "notEqual", "greaterThanOrEqual", "greaterThan", "between", "notBetween"}
		formula := formulas[(i/32)%len(formulas)]
		second := formulas[((i/32)+1)%len(formulas)]
		value := values[(i/32)%len(values)]
		op := operators[(i/4)%len(operators)]
		formulaXML := `<formula>` + formula + `</formula>`
		if op == "between" || op == "notBetween" {
			formulaXML += `<formula>` + second + `</formula>`
		}
		rule := fmt.Sprintf(`<conditionalFormatting sqref="A1:F3"><cfRule type="cellIs" operator="%s" dxfId="0">%s</cfRule></conditionalFormatting>`, op, formulaXML)
		if i >= 320 && i < 326 {
			rule = `<conditionalFormatting sqref="A1:F3"><cfRule type="cellIs" operator="equal" dxfId="0"><formula>SUM(A1:A2)</formula></cfRule></conditionalFormatting>`
		}
		if i == 326 {
			rule = `<conditionalFormatting sqref="A1:F3"><cfRule type="cellIs" operator="notEqual" dxfId="0"><formula>"unused"</formula></cfRule></conditionalFormatting>`
			rule += rule
		}
		if i == 327 {
			rule = `<conditionalFormatting sqref="A1:F3"><cfRule type="cellIs" operator="notEqual" dxfId="5"><formula>"unused"</formula></cfRule></conditionalFormatting>`
		}

		if i == 328 {
			rule = `<conditionalFormatting sqref="A1:A3"><cfRule type="cellIs" operator="between" dxfId="0"><formula>$F1</formula><formula>"x"</formula></cfRule></conditionalFormatting>`
		}
		merge := ""
		if i%4 == 0 {
			merge = `<mergeCells><mergeCell ref="B1:C1"/></mergeCells>`
		}
		add("xl/worksheets/sheet1.xml", fmt.Sprintf(`<worksheet><sheetData><row r="1" s="1" customFormat="1"><c r="A1" s="%d" t="str"><v>%s</v></c><c r="B1" s="%d" t="b"><v>1</v></c><c r="C1" s="3" t="e"><v>#N/A</v></c><c r="D1" s="2"><v>5</v></c><c r="E1" t="str"><v>  </v></c><c r="F1"/></row><row r="3"><c r="B3" t="str"><v>ABC</v></c><c r="D3" t="e"><v>#REF!</v></c></row></sheetData>%s%s</worksheet>`, style, value, 1-style, merge, rule))

		if e = z.Close(); e != nil {
			t.Fatal(e)
		}
		if i >= 320 && i != 328 {
			unsupported = append(unsupported, b.Bytes())
		} else {
			convert(b.Bytes())
		}
	}
	for i := 0; i < 40; i++ {
		var b bytes.Buffer
		z := zip.NewWriter(&b)
		add := func(name, value string) {
			w, err := z.Create(name)
			if err != nil {
				t.Fatal(err)
			}
			if _, err = w.Write([]byte(value)); err != nil {
				t.Fatal(err)
			}
		}
		add("xl/workbook.xml", `<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet" r:id="r1"/></sheets></workbook>`)
		add("xl/_rels/workbook.xml.rels", `<Relationships><Relationship Id="r1" Type="x/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="r2" Type="x/styles" Target="styles.xml"/></Relationships>`)
		dxf := `<font><b/></font>`
		if i%2 != 0 {
			dxf = `<fill><patternFill><bgColor rgb="FF112233"/></patternFill></fill>`
		}
		add("xl/styles.xml", `<styleSheet><dxfs><dxf>`+dxf+`</dxf></dxfs></styleSheet>`)
		var data, rule string
		if i < 32 {
			values := []string{"\ue000", "\U00010000"}
			value, target := values[(i/4)%2], values[((i/4)+1)%2]
			op := []string{"lessThan", "lessThanOrEqual", "greaterThan", "greaterThanOrEqual"}[i%4]
			data = fmt.Sprintf(`<row r="1"><c r="A1" t="str"><v>%s</v></c></row>`, value)
			rule = fmt.Sprintf(`<conditionalFormatting sqref="A1"><cfRule type="cellIs" operator="%s" dxfId="0"><formula>"%s"</formula></cfRule></conditionalFormatting>`, op, target)
		} else {
			data = `<row r="1"><c r="A1" t="str"><v>VALUE</v></c><c r="F1"><v>4</v></c></row><row r="2"><c r="A2"><v>3</v></c></row>`
			op := "between"
			if i%4 >= 2 {
				op = "notBetween"
			}
			rule = fmt.Sprintf(`<conditionalFormatting sqref="A1:A3"><cfRule type="cellIs" operator="%s" dxfId="0"><formula>$F$1</formula><formula>"VALUE"</formula></cfRule></conditionalFormatting>`, op)
		}
		add("xl/worksheets/sheet1.xml", `<worksheet><sheetData>`+data+`</sheetData>`+rule+`</worksheet>`)
		if err := z.Close(); err != nil {
			t.Fatal(err)
		}
		convert(b.Bytes())
	}
	for i := 0; i < 64; i++ {
		var b bytes.Buffer
		z := zip.NewWriter(&b)
		add := func(name, value string) {
			w, err := z.Create(name)
			if err != nil {
				t.Fatal(err)
			}
			if _, err = w.Write([]byte(value)); err != nil {
				t.Fatal(err)
			}
		}
		add("xl/workbook.xml", `<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet" r:id="r1"/></sheets></workbook>`)
		add("xl/_rels/workbook.xml.rels", `<Relationships><Relationship Id="r1" Type="x/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="r2" Type="x/styles" Target="styles.xml"/></Relationships>`)
		styles := []string{`<font><b/></font>`, `<fill><patternFill><bgColor rgb="FF112233"/></patternFill></fill>`, `<border><bottom style="thin"/></border>`, `<font><i/></font><fill><patternFill><bgColor rgb="FF44AA99"/></patternFill></fill>`}
		add("xl/styles.xml", `<styleSheet><dxfs><dxf>`+styles[i%4]+`</dxf></dxfs></styleSheet>`)
		op := "between"
		if i%8 >= 4 {
			op = "notBetween"
		}
		first, second := `$F1`, `"Foo"`
		if i%16 >= 8 {
			first, second = second, first
		}
		data := `<row r="1"><c r="A1" t="str"><v>Foo</v></c><c r="F1"><v>2</v></c></row><row r="2"><c r="A2"><v>1</v></c><c r="F2"><v>0</v></c></row><row r="3"><c r="F3"><v>-1</v></c></row>`
		rule := fmt.Sprintf(`<conditionalFormatting sqref="A1:A3"><cfRule type="cellIs" operator="%s" dxfId="0"><formula>%s</formula><formula>%s</formula></cfRule></conditionalFormatting>`, op, first, second)
		add("xl/worksheets/sheet1.xml", `<worksheet><sheetData>`+data+`</sheetData>`+rule+`</worksheet>`)
		if err := z.Close(); err != nil {
			t.Fatal(err)
		}
		convert(b.Bytes())
	}
	for i := 0; i < 8; i++ {
		var b bytes.Buffer
		z := zip.NewWriter(&b)
		add := func(name, value string) {
			w, err := z.Create(name)
			if err != nil {
				t.Fatal(err)
			}
			if _, err = w.Write([]byte(value)); err != nil {
				t.Fatal(err)
			}
		}
		add("xl/workbook.xml", `<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet" r:id="r1"/></sheets></workbook>`)
		add("xl/_rels/workbook.xml.rels", `<Relationships><Relationship Id="r1" Type="x/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="r2" Type="x/styles" Target="styles.xml"/></Relationships>`)
		dxf := `<fill><patternFill><bgColor rgb="FF112233"/></patternFill></fill>`
		if i%2 != 0 {
			dxf = `<border><bottom style="thin"/></border>`
		}
		add("xl/styles.xml", `<styleSheet><dxfs><dxf>`+dxf+`</dxf></dxfs></styleSheet>`)
		data := `<row r="1"><c r="A1" t="str"><v>Foo</v></c><c r="F1"><v>2</v></c></row><row r="600"><c r="A600"><v>3</v></c><c r="F600"><v>1</v></c></row><row r="1002"><c r="A1002" t="str"><v>bar</v></c><c r="F1002"><v>-1</v></c></row>`
		op := "between"
		if i%4 >= 2 {
			op = "notBetween"
		}
		first, second := `$F1`, `"Foo"`
		if i%2 != 0 {
			first, second = second, first
		}
		rule := fmt.Sprintf(`<conditionalFormatting sqref="A1:A1002 C5:C6"><cfRule type="cellIs" operator="%s" dxfId="0"><formula>%s</formula><formula>%s</formula></cfRule></conditionalFormatting>`, op, first, second)
		add("xl/worksheets/sheet1.xml", `<worksheet><sheetData>`+data+`</sheetData>`+rule+`</worksheet>`)
		if err := z.Close(); err != nil {
			t.Fatal(err)
		}
		convert(b.Bytes())
	}
	for name, v := range map[string]any{"conditional-moving-literal.json": out, "conditional-moving-literal-unsupported.json": unsupported} {
		data, e := json.Marshal(v)
		if e != nil {
			t.Fatal(e)
		}
		if e = os.WriteFile(filepath.Join(root, "compat/xlsx", name), data, 0644); e != nil {
			t.Fatal(e)
		}
	}
}
