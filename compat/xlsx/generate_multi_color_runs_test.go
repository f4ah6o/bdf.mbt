//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexMultiColorRuns.
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

func TestCodexMultiColorRuns(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	texts := []string{
		`<r><t>Hello </t></r><r><rPr><color rgb="FFCC0011"/></rPr><t>red</t></r>`,
		`<r><rPr><color rgb="FF1122CC"/></rPr><t>blue </t></r><r><t>base</t></r>`,
		`<r><rPr><color rgb="FFCC0011"/></rPr><t>red </t></r><r><rPr><color rgb="FF1122CC"/></rPr><t>blue</t></r>`,
		`<r><t>one </t></r><r><t>two </t></r><r><rPr><color indexed="10"/></rPr><t>three</t></r>`,
		`<t>ignored </t><r><rPr/><t>styled </t></r><r><t>base</t></r><t> ignored</t>`,
		`<r><rPr><color theme="1" tint="0.2"/></rPr><t>a &amp; b </t></r><r><t>text</t></r>`,
		`<r><rPr><color rgb="FFCC0011"/></rPr><t>red</t></r><r><rPr><color rgb="FFCC0011"/></rPr><t>same</t></r>`,
		`<r><rPr><color rgb="FFCC0011"/></rPr><t/></r><r><t>plain</t></r>`,
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
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/multi-color-runs.json"), data, 0644); e != nil {
		t.Fatal(e)
	}
}
