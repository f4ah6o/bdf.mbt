//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexMultiVaryingConditional.
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

func TestCodexMultiVaryingConditional(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	texts := []string{
		`<r><rPr><sz val="9"/></rPr><t>日本語 </t></r><r><rPr><sz val="18"/></rPr><t>two</t></r>`,
		`<r><rPr><sz val="18"/><b/></rPr><t>こんにちは </t></r><r><rPr><sz val="9"/><i/></rPr><t>世界</t></r>`,
		`<r><rPr><sz val="14"/><rFont val="Courier New"/></rPr><t>漢字abc </t></r><r><rPr><sz val="11"/></rPr><t>text</t></r>`,
		`<r><rPr><sz val="14"/></rPr><t>日本語 </t></r><r><rPr><sz val="8"/><u/></rPr><t>日本語 two</t></r>`,
		`<r><rPr><sz val="8"/><color rgb="FF1122CC"/></rPr><t>日本語 </t></r><r><rPr><sz val="14"/></rPr><t>世界</t></r>`,
		`<r><rPr><sz val="12"/><strike/></rPr><t>こんにちは </t></r><r><rPr><sz val="18"/><rFont val="Arial"/></rPr><t>世界</t></r>`,
		`<r><rPr><sz val="9"/></rPr><t>one</t></r><r><rPr><sz val="14"/></rPr><t>two</t></r><r><rPr><sz val="18"/></rPr><t>世界</t></r>`,
		`<r><rPr><sz val="14"/></rPr><t/></r><r><rPr><sz val="9"/></rPr><t>漢字abc </t></r><r><rPr><sz val="18"/></rPr><t>文章</t></r>`,
	}
	out := []any{}
	for i := 0; i < 320; i++ {
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
		add("xl/styles.xml", `<styleSheet><numFmts><numFmt numFmtId="164" formatCode="0;0;0;[Red]&quot;prefix &quot;@"/></numFmts><fonts><font><sz val="11"/></font><font><sz val="18"/><color rgb="FF008855"/></font></fonts><cellXfs><xf><alignment horizontal="center"/></xf><xf><alignment horizontal="right"/></xf><xf fontId="1"><alignment horizontal="centerContinuous"/></xf><xf><alignment horizontal="right" indent="1"/></xf></cellXfs><dxfs><dxf><font><color rgb="FFEE8800"/></font><fill><patternFill><bgColor rgb="FFDDFFBB"/></patternFill></fill></dxf></dxfs></styleSheet>`)
		text := texts[i%len(texts)]
		add("xl/sharedStrings.xml", `<sst><si>`+text+`</si></sst>`)
		style := (i / 8) % 4
		body := fmt.Sprintf(`<worksheet><cols><col min="1" max="1" width="4" customWidth="1"/><col min="2" max="2" width="6" customWidth="1"/></cols><sheetData><row r="1"><c r="A1" s="%d" t="s"><v>0</v></c><c r="B1" s="%d" t="inlineStr"><is>%s</is></c></row></sheetData><conditionalFormatting sqref="A1:B1"><cfRule type="notContainsBlanks" dxfId="0"></cfRule></conditionalFormatting></worksheet>`, style, style, text)
		add("xl/worksheets/sheet1.xml", body)
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
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/multi-varying-conditional.json"), data, 0644); e != nil {
		t.Fatal(e)
	}
}
