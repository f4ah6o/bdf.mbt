//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexPlainTableFontStyleWrap.
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

func TestCodexPlainTableFontStyleWrap(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	texts := []string{
		`<r><rPr><sz val="9"/><vertAlign val="superscript"/></rPr><t>日本語 </t></r><r><t>two</t></r>`,
		`<r><rPr><sz val="18"/><vertAlign val="subscript"/><b/></rPr><t>hello </t></r><r><rPr><vertAlign val="superscript"/><i/></rPr><t>世界</t></r>`,
		`<r><t>漢字abc </t></r><r><rPr><sz val="14"/><vertAlign val="superscript"/><rFont val="Courier New"/></rPr><t>text</t></r>`,
		`<r><rPr><sz val="14"/><vertAlign val="superscript"/></rPr><t>日本語 </t></r><r><rPr><u/></rPr><t>two</t></r>`,
		`<r><rPr><color rgb="FF1122CC"/></rPr><t>one </t></r><r><rPr><sz val="8"/><vertAlign val="subscript"/></rPr><t>世界</t></r>`,
		`<r><rPr><strike/></rPr><t>hello </t></r><r><rPr><sz val="18"/><vertAlign val="subscript"/><rFont val="Arial"/></rPr><t>world</t></r>`,
		`<r><t>one</t></r><r><rPr><sz val="14"/><vertAlign val="superscript"/></rPr><t>two</t></r><r><t>世界</t></r>`,
		`<r><rPr><sz val="14"/><vertAlign val="superscript"/></rPr><t/></r><r><t>漢字abc </t></r><r><rPr><sz val="18"/><vertAlign val="subscript"/></rPr><t>文章</t></r>`,
	}
	out := []any{}
	for i := 0; i < 384; i++ {
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
		add("xl/_rels/workbook.xml.rels", `<Relationships><Relationship Id="r1" Type="x/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="r2" Type="x/styles" Target="styles.xml"/><Relationship Id="r3" Type="x/sharedStrings" Target="sharedStrings.xml"/></Relationships>`)
		styles := `<styleSheet><numFmts><numFmt numFmtId="164" formatCode="0;0;0;[Red]&quot;prefix &quot;@"/></numFmts><fonts><font><sz val="11"/></font><font><sz val="18"/><color rgb="FF008855"/></font></fonts><cellXfs><xf><alignment wrapText="1" horizontal="center"/></xf><xf><alignment wrapText="1" horizontal="right"/></xf><xf fontId="1"><alignment wrapText="1" horizontal="centerContinuous"/></xf><xf><alignment wrapText="1" horizontal="right" indent="1"/></xf></cellXfs><tableStyles><tableStyle name="EmptyStyle"/></tableStyles></styleSheet>`
		fonts := []string{`<b/>`, `<i/>`, `<u/>`, `<strike/>`, `<color rgb="FF1122CC"/>`, `<b/><color rgb="FF008855"/>`, `<i/><u/>`, `<b val="false"/>`}
		definition := fmt.Sprintf(`<dxfs><dxf><font>%s</font></dxf></dxfs><tableStyles><tableStyle name="EmptyStyle"><tableStyleElement type="wholeTable" dxfId="0"/></tableStyle></tableStyles>`, fonts[(i/8)%len(fonts)])
		styles = strings.Replace(styles, `<tableStyles><tableStyle name="EmptyStyle"/></tableStyles>`, definition, 1)
		add("xl/styles.xml", styles)
		text := texts[i%len(texts)]
		add("xl/sharedStrings.xml", `<sst><si>`+text+`</si></sst>`)
		style := (i / 8) % 4
		body := fmt.Sprintf(`<worksheet><cols><col min="1" max="1" width="4" customWidth="1"/><col min="2" max="2" width="6" customWidth="1"/></cols><sheetData><row r="1"><c r="A1" s="%d" t="s"><v>0</v></c><c r="B1" s="%d" t="inlineStr"><is>%s</is></c></row></sheetData></worksheet>`, style, style, text)
		body = strings.Replace(body, `</sheetData>`, `<row r="2"><c r="A2" t="inlineStr"><is><t>value</t></is></c><c r="B2"><v>42</v></c></row><row r="3"><c r="B3" t="inlineStr"><is><t>total</t></is></c></row></sheetData>`, 1)
		body = strings.Replace(body, `</worksheet>`, `<tableParts count="1"><tablePart xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:id="t1"/></tableParts></worksheet>`, 1)
		add("xl/worksheets/sheet1.xml", body)
		add("xl/worksheets/_rels/sheet1.xml.rels", `<Relationships><Relationship Id="t1" Type="x/table" Target="../tables/table1.xml"/></Relationships>`)
		refs := []string{"A1:B2", "B2:B3", "A2:B3", "A1:B3", "A3:B3", "A1:A3"}
		headers := []int{0, 1, 2}
		infos := []string{"", `<tableStyleInfo/>`, `<tableStyleInfo name="" showRowStripes="1"/>`}
		table := fmt.Sprintf(`<table ref="%s" name="Test" displayName="Test" headerRowCount="%d" totalsRowCount="%d"><tableColumns count="2"><tableColumn id="1" name="one"/><tableColumn id="2" name="two"/></tableColumns>%s</table>`, refs[(i/8)%len(refs)], headers[(i/48)%len(headers)], (i/144)%2, infos[(i/24)%len(infos)])
		filters := []string{`<autoFilter/>`, `<autoFilter><filterColumn colId="0" hiddenButton="1"/></autoFilter>`, `<autoFilter><filterColumn colId="1" showButton="0"/></autoFilter>`}
		table = strings.Replace(table, `</table>`, filters[(i/8)%len(filters)]+`</table>`, 1)
		table = strings.Replace(table, `</tableColumns>`, `</tableColumns><tableStyleInfo name="EmptyStyle"/>`, 1)
		add("xl/tables/table1.xml", table)
		if e := z.Close(); e != nil {
			t.Fatal(e)
		}
		mode := []string{"none", "all", "default"}[(i/2)%3]
		noIndex := i%2 == 0
		result, e := Convert(bytes.NewReader(b.Bytes()), int64(b.Len()), &Options{NoSystemFonts: true, SystemFonts: true, NoTextIndex: noIndex, Data: mode})
		if e != nil {
			t.Fatal(e)
		}
		var doc bytes.Buffer
		if e = result.Doc.WriteSingle(&doc); e != nil {
			t.Fatal(e)
		}
		out = append(out, map[string]any{"input": b.Bytes(), "bdf": doc.Bytes(), "warnings": result.Warnings, "mode": mode, "no_index": noIndex})
	}
	data, e := json.Marshal(out)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/plain-table-font-style-wrap.json"), data, 0644); e != nil {
		t.Fatal(e)
	}
}
