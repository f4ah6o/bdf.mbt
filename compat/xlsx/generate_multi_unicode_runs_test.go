//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexMultiUnicodeRuns.
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

func TestCodexMultiUnicodeRuns(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	texts := []string{
		`<r><rPr><b/></rPr><t>日本語</t></r><r><t>文章</t></r>`,
		`<r><rPr><i/><color rgb="FFCC0011"/></rPr><t>abc 日本語</t></r><r><t> 漢字abc</t></r>`,
		`<r><t>Ελληνικά </t></r><r><rPr><u/></rPr><t>Русский</t></r>`,
		`<r><rPr><strike/></rPr><t>こんにちは 🌸</t></r><r><t>world</t></r>`,
		`<r><rPr><b/></rPr><t>中文</t></r><r><rPr><i/></rPr><t>한국어</t></r>`,
		`<r><t>éà ñ </t></r><r><rPr><color rgb="FF1122CC"/></rPr><t>λ ω</t></r>`,
		`<r><rPr><b/></rPr><t>😀🦊</t></r><r><rPr><u val="double"/></rPr><t> é</t></r>`,
		`<r><t>abc</t></r><r><rPr><i/></rPr><t>日本abc日本</t></r>`,
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
		add("xl/styles.xml", `<styleSheet><numFmts><numFmt numFmtId="164" formatCode="0;0;0;[Red]&quot;prefix &quot;@"/></numFmts><fonts><font/><font><color rgb="FF008855"/></font></fonts><cellXfs><xf/><xf numFmtId="164"/><xf fontId="1"/><xf><alignment indent="1"/></xf></cellXfs></styleSheet>`)
		text := texts[i%len(texts)]
		add("xl/sharedStrings.xml", `<sst><si>`+text+`</si></sst>`)
		style := (i / 8) % 4
		body := fmt.Sprintf(`<worksheet><sheetData><row r="1"><c r="A1" s="%d" t="s"><v>0</v></c><c r="B1" s="%d" t="inlineStr"><is>%s</is></c></row></sheetData></worksheet>`, style, style, text)
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
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/multi-unicode-runs.json"), data, 0644); e != nil {
		t.Fatal(e)
	}
}
