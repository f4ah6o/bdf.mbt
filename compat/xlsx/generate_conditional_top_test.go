//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexConditionalTop.
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

func TestCodexConditionalTop(t *testing.T) {
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
	for i := 0; i < 264; i++ {
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
		if i >= 256 {
			switch i - 256 {
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
		if i >= 256 && i < 262 {
			dxf = `<font><b/></font>`
		}
		add("xl/styles.xml", fmt.Sprintf(`<styleSheet><numFmts><numFmt numFmtId="164" formatCode="[Red]0"/></numFmts><fonts><font><name val="Calibri"/><sz val="11"/></font><font><name val="Calibri"/><sz val="11"/><b/></font></fonts><fills><fill/><fill><patternFill patternType="solid"><fgColor rgb="FF00BB00"/></patternFill></fill></fills><borders><border/><border diagonalDown="1"><top style="medium"/><right style="thin"/><diagonal style="dotted"/></border></borders><cellXfs><xf fontId="0" fillId="0" borderId="0"/><xf fontId="1" fillId="1" borderId="1" numFmtId="164" applyAlignment="1"><alignment wrapText="1"/></xf><xf fontId="2" fillId="2" borderId="2"/></cellXfs><dxfs><dxf>%s</dxf></dxfs></styleSheet>`, dxf))
		style := (i / 8) % 2
		ranks := []string{"0", "-1", "1", "2", "3", "10", "50", "100", "200000000000", "10000000000", "bad", "1000001", "-9999999999", " 1.9 ", "2e0", "-0.9"}
		rank := ranks[(i/16)%len(ranks)]
		percent := "0"
		if i%2 != 0 {
			percent = "1"
		}
		bottom := "0"
		if i%4 >= 2 {
			bottom = "1"
		}
		rule := fmt.Sprintf(`<conditionalFormatting sqref="A1:F3 C1:F2"><cfRule type="top10" rank="%s" percent="%s" bottom="%s" dxfId="0"/></conditionalFormatting>`, rank, percent, bottom)
		// Go accepts an empty rule node; the port requires a nonempty element.
		rule = strings.Replace(rule, `dxfId="0"/>`, `dxfId="0"></cfRule>`, 1)
		if i >= 256 && i < 262 {
			rule = `<conditionalFormatting sqref="A1:F3"><cfRule type="colorScale" dxfId="0"/></conditionalFormatting>`
		}
		if i == 256 {
			rule = `<conditionalFormatting sqref="A1:F3"><cfRule type="top10" rank="200000000001" dxfId="0"></cfRule></conditionalFormatting>`
		}
		if i == 257 {
			rule = `<conditionalFormatting sqref="A1:F3"><cfRule type="top10" rank="0x1p1" dxfId="0"></cfRule></conditionalFormatting>`
		}
		if i == 262 {
			rule = strings.Replace(rule, `rank="0"`, `rank="1"`, 1)
			rule += strings.Replace(rule, `dxfId="0"`, `dxfId="1"`, 1)
		}
		if i == 263 {
			rule = strings.Replace(rule, `rank="0"`, `rank="1"`, 1)
			rule = strings.Replace(rule, `dxfId="0"`, `dxfId="5"`, 1)
		}

		merge := ""
		if i%4 == 0 {
			merge = `<mergeCells><mergeCell ref="B1:C1"/></mergeCells>`
		}
		add("xl/worksheets/sheet1.xml", fmt.Sprintf(`<worksheet><sheetData><row r="1" s="1" customFormat="1"><c r="A1" s="%d"><v>1</v></c><c r="B1" s="%d"><v>3</v></c><c r="C1" s="3" t="e"><v>#N/A</v></c><c r="D1" s="2"><v>3</v></c><c r="E1" t="str"><v>text</v></c><c r="F1"><v>-1</v></c></row><row r="2"><c r="A2"><v>0</v></c><c r="B2"><v>10</v></c><c r="F2" t="b"><v>1</v></c></row><row r="3"><c r="B3"><v>-1</v></c><c r="D3"><v>2</v></c></row></sheetData>%s%s</worksheet>`, style, 1-style, merge, rule))

		if e = z.Close(); e != nil {
			t.Fatal(e)
		}
		if i >= 256 {
			unsupported = append(unsupported, b.Bytes())
		} else {
			convert(b.Bytes())
		}
	}
	for name, v := range map[string]any{"conditional-top.json": out, "conditional-top-unsupported.json": unsupported} {
		data, e := json.Marshal(v)
		if e != nil {
			t.Fatal(e)
		}
		if e = os.WriteFile(filepath.Join(root, "compat/xlsx", name), data, 0644); e != nil {
			t.Fatal(e)
		}
	}
}
