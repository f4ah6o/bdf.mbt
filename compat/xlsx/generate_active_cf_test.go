//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexActiveCF.
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

func TestCodexActiveCF(t *testing.T) {
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
	fonts := []string{`<b/>`, `<b val="0"/><color rgb="FFAA2211"/>`, `<i/><color rgb="FF0055CC"/>`, `<strike/>`, `<u/>`, `<u val="double"/>`, `<b/><i/><strike/><u/><color rgb="FFAA22EE"/>`, `<b val="0"/><i val="0"/><u val="none"/>`, `<color indexed="10"/>`, `<color theme="4" tint="-0.25"/>`, `<color auto="1"/>`, `<color rgb="FF112233"/><color/>`}
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
		secondSheet, secondRel := "", ""
		if i%11 == 0 {
			secondSheet = `<sheet name="Other" r:id="r3"/>`
			secondRel = `<Relationship Id="r3" Type="x/worksheet" Target="worksheets/sheet2.xml"/>`
			add("xl/worksheets/sheet2.xml", `<worksheet><sheetData><row r="1"><c r="A1" s="3" t="str"><v>invalid style falls back</v></c><c r="B1" s="2" t="str"><v>invalid font falls back</v></c></row></sheetData></worksheet>`)
		}
		add("xl/workbook.xml", `<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet" r:id="r1"/>`+secondSheet+`</sheets></workbook>`)
		add("xl/_rels/workbook.xml.rels", `<Relationships><Relationship Id="r1" Type="x/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="r2" Type="x/styles" Target="styles.xml"/>`+secondRel+`</Relationships>`)
		dxf := `<font>` + fonts[i%len(fonts)] + `</font>`
		if i >= 160 {
			switch i - 160 {
			case 0:
				dxf = `<fill><patternFill patternType="solid"><fgColor rgb="FFFF0000"/></patternFill></fill>`
			case 1:
				dxf = `<border><bottom style="thin"/></border>`
			case 2:
				dxf = `<numFmt formatCode="0.00"/>`
			case 3:
				dxf = `<font><sz val="20"/></font>`
			case 4:
				dxf = `<font><u val="singleAccounting"/></font>`
			case 5:
				dxf = `<font><b/><color rgb="FF112233"/></font><fill/>`
			}
		}
		add("xl/styles.xml", fmt.Sprintf(`<styleSheet><numFmts><numFmt numFmtId="164" formatCode="[Red]0"/></numFmts><fonts><font><name val="Calibri"/><sz val="11"/></font><font><name val="Calibri"/><sz val="11"/><b/></font></fonts><cellXfs><xf fontId="0"/><xf fontId="1" numFmtId="164" applyAlignment="1"><alignment wrapText="1"/></xf><xf fontId="2"/></cellXfs><dxfs><dxf>%s</dxf></dxfs></styleSheet>`, dxf))
		style := (i / 8) % 2
		op := []string{"greaterThanOrEqual", "greaterThan"}[(i/16)%2]
		number := []int{10, 11, 15, 123456789}[(i/32)%4]
		if op == "greaterThan" && number == 10 {
			number = 11
		}
		rule := fmt.Sprintf(`<conditionalFormatting sqref="A1:B1"><cfRule type="cellIs" operator="%s" dxfId="0"><formula>10</formula></cfRule></conditionalFormatting>`, op)
		if i == 166 {
			rule += rule
		}
		if i == 167 {
			rule = strings.Replace(rule, `dxfId="0"`, `dxfId="5"`, 1)
		}
		add("xl/worksheets/sheet1.xml", fmt.Sprintf(`<worksheet><sheetData><row r="1"><c r="A1" s="%d"><v>%d</v></c><c r="B1" s="%d"><v>%d</v></c><c r="C1" s="3" t="str"><v>invalid style</v></c><c r="D1" s="2" t="str"><v>invalid font</v></c></row></sheetData>%s</worksheet>`, style, number, 1-style, number+1, rule))
		if e = z.Close(); e != nil {
			t.Fatal(e)
		}
		if i >= 160 {
			unsupported = append(unsupported, b.Bytes())
		} else {
			convert(b.Bytes())
		}
	}
	for name, v := range map[string]any{"active-cf.json": out, "active-cf-unsupported.json": unsupported} {
		data, e := json.Marshal(v)
		if e != nil {
			t.Fatal(e)
		}
		if e = os.WriteFile(filepath.Join(root, "compat/xlsx", name), data, 0644); e != nil {
			t.Fatal(e)
		}
	}
}
