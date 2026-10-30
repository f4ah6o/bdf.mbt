//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexRichRunIdentity.
package xlsx

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexRichRunIdentity(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	plain := `<c r="A1" s="1" t="s"><v>1</v></c>`
	rich := `<c r="A1" s="1" t="s"><v>2</v></c>`
	variants := []string{
		`<row r="1"><c r="A1" s="1" t="s"><v>1</v></c><c r="B1" s="1" t="s"><v>2</v></c></row>`,
		`<row r="1"><c r="A1" s="1" t="inlineStr"><is><r><t>one</t></r><r><t>two</t></r></is></c><c r="B1" s="1" t="inlineStr"><is><t>onetwo</t></is></c></row>`,
		`<row r="1">` + rich + plain + `</row>`, `<row r="1">` + plain + rich + `</row>`,
		`<row r="1">` + rich + `</row><row r="1">` + plain + `</row>`, `<row r="1">` + plain + `</row><row r="1">` + rich + `</row>`,
		`<row r="1"><c r="A1" s="1" t="s"><v>2</v></c></row>`,
		`<row r="1"><c r="A1" s="1" t="s"><v>3</v></c><c r="B1" s="1" t="s"><v>4</v></c></row>`,
	}
	out := []any{}
	for i := 0; i < 160; i++ {
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
		add("xl/styles.xml", `<styleSheet><numFmts><numFmt numFmtId="164" formatCode="0;0;0;[Red]&quot;prefix &quot;@"/></numFmts><cellXfs><xf/><xf numFmtId="164"/></cellXfs></styleSheet>`)
		add("xl/sharedStrings.xml", `<sst><si/><si><t>onetwo</t></si><si><r><t>one</t></r><r><t>two</t></r></si><si><t>root</t><r><t>one</t></r><r><t>two</t></r></si><si><t>rootonetwo</t></si></sst>`)
		add("xl/worksheets/sheet1.xml", `<worksheet><sheetData>`+variants[i%len(variants)]+`</sheetData></worksheet>`)
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
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/rich-run-identity.json"), data, 0644); e != nil {
		t.Fatal(e)
	}
}
