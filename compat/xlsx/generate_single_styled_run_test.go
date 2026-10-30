//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexSingleStyledRun.
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

func TestCodexSingleStyledRun(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	props := []string{`<rPr/>`, `<rPr><b/></rPr>`, `<rPr><i/></rPr>`, `<rPr><u/></rPr>`, `<rPr><strike/></rPr>`, `<rPr><color rgb="FF1122CC"/></rPr>`, `<rPr><sz val="18"/></rPr>`, `<rPr><rFont val="Arial"/></rPr>`, `<rPr><vertAlign val="superscript"/></rPr>`, `<rPr><vertAlign val="subscript"/></rPr>`, `<rPr><b val="0"/></rPr>`, `<rPr><rFont val="Arial"/><sz val="13"/><b/><color rgb="FFAB1234"/></rPr>`}
	texts := []string{"hello world", "Wi test 日本語", "Long wrapped words and more", "space_x000A_newline"}
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
		add("xl/styles.xml", `<styleSheet><numFmts><numFmt numFmtId="164" formatCode="0;0;0;[Red]&quot;prefix &quot;@"/></numFmts><fonts><font/><font><b/></font><font><sz val="16"/><i/></font></fonts><cellXfs><xf/><xf numFmtId="164"/><xf fontId="1"/><xf fontId="2"><alignment wrapText="1"/></xf></cellXfs></styleSheet>`)
		run := `<r>` + props[i%len(props)] + `<t>` + texts[(i/12)%len(texts)] + `</t></r>`
		add("xl/sharedStrings.xml", `<sst><si>`+run+`</si></sst>`)
		style := (i / 48) % 4
		inline := `<is>` + run + `</is>`
		body := fmt.Sprintf(`<worksheet><cols><col min="1" max="2" width="10" customWidth="1"/></cols><sheetData><row r="1"><c r="A1" s="%d" t="s"><v>0</v></c><c r="B1" s="%d" t="inlineStr">%s</c></row></sheetData></worksheet>`, style, style, inline)
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
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/single-styled-run.json"), data, 0644); e != nil {
		t.Fatal(e)
	}
}
