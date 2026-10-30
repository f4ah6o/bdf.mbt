//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexMultiRepeatedPropsPlain.
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

func TestCodexMultiRepeatedPropsPlain(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	texts := []string{
		`<r><rPr><rFont val="Arial"/><rFont val="Courier New"/><sz val="9"/><sz val="18"/></rPr><t>hello </t></r><r><t>world</t></r>`,
		`<r><rPr><sz val="14"/><sz val="7"/><vertAlign val="superscript"/></rPr><t>日本語 </t></r><r><t>two</t></r>`,
		`<r><t>one </t></r><r><rPr><rFont val="Courier New"/><rFont val="Arial"/><b/></rPr><t>world</t></r>`,
		`<r><rPr><sz val="0"/><sz val="14"/></rPr><t>aa </t></r><r><rPr><sz val="9"/><sz val="18"/></rPr><t>世界</t></r>`,
		`<r><rPr><rFont val=""/><rFont val="Arial"/><sz val=""/><sz val="18"/></rPr><t>日本語 </t></r><r><t>word</t></r>`,
		`<r><rPr><sz val="9"/><sz val="14"/><vertAlign val="subscript"/></rPr><t>hello </t></r><r><t>world</t></r>`,
		`<r><rPr><rFont val="Arial"/><rFont val="Courier New"/><sz val="18"/><sz val="9"/><b/><i/></rPr><t>one </t></r><r><t>two</t></r>`,
		`<r><rPr><sz val="-5"/><sz val="9"/></rPr><t>一 二 三</t></r><r><t>日本語</t></r>`,
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
		add("xl/styles.xml", `<styleSheet><numFmts><numFmt numFmtId="164" formatCode="0;0;0;[Red]&quot;prefix &quot;@"/></numFmts><fonts><font><sz val="11"/></font><font><sz val="18"/><color rgb="FF008855"/></font></fonts><cellXfs><xf><alignment horizontal="center"/></xf><xf><alignment horizontal="right"/></xf><xf fontId="1"><alignment horizontal="centerContinuous"/></xf><xf><alignment horizontal="right" indent="1"/></xf></cellXfs></styleSheet>`)
		text := texts[i%len(texts)]
		add("xl/sharedStrings.xml", `<sst><si>`+text+`</si></sst>`)
		style := (i / 8) % 4
		body := fmt.Sprintf(`<worksheet><cols><col min="1" max="1" width="4" customWidth="1"/><col min="2" max="2" width="6" customWidth="1"/></cols><sheetData><row r="1"><c r="A1" s="%d" t="s"><v>0</v></c><c r="B1" s="%d" t="inlineStr"><is>%s</is></c></row></sheetData></worksheet>`, style, style, text)
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
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/multi-repeated-props-plain.json"), data, 0644); e != nil {
		t.Fatal(e)
	}
}
