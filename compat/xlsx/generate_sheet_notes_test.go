//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexSheetNotes.
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

func TestCodexSheetNotes(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	refs := []string{"A1", "B1", "B2", "D2", "AS145", "invalid", "$A$1", "A1048577"}
	out := []any{}
	unsupported := []any{}
	for i := 0; i < 200; i++ {
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
		add("xl/_rels/workbook.xml.rels", `<Relationships><Relationship Id="r1" Type="x/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="r2" Type="x/styles" Target="styles.xml"/></Relationships>`)
		add("xl/styles.xml", `<styleSheet><cellXfs><xf/></cellXfs></styleSheet>`)
		add("xl/worksheets/_rels/sheet1.xml.rels", `<Relationships><Relationship Id="c" Type="x/comments" Target="../comments1.xml"/></Relationships>`)
		ref := refs[i%len(refs)]
		comment := fmt.Sprintf(`<comment ref="%s" authorId="0"><text><t>Note</t></text></comment>`, ref)
		if i%16 >= 8 {
			comment += comment
		}
		if i >= 192 {
			comment = `<comment ref="A1" authorId="0"><text><t>One</t></text></comment><comment ref="C2" authorId="0"><text><t>Other</t></text></comment>`
		}
		add("xl/comments1.xml", `<comments><authors><author>Author</author></authors><commentList>`+comment+`</commentList></comments>`)
		merge := ``
		if (i/8)%2 != 0 {
			merge = `<mergeCells count="1"><mergeCell ref="A1:B2"/></mergeCells>`
		}
		legacy := ``
		if (i/16)%2 != 0 {
			legacy = `<legacyDrawing/>`
		}
		row := ``
		if (i/32)%2 != 0 {
			row = ` hidden="1"`
		}
		body := fmt.Sprintf(`<worksheet><sheetData><row r="1"%s><c r="A1" t="inlineStr"><is><t>Hello</t></is></c><c r="B1"><v>1</v></c></row><row r="2"><c r="C2"><v>2</v></c></row></sheetData>%s%s</worksheet>`, row, merge, legacy)
		add("xl/worksheets/sheet1.xml", body)
		if e := z.Close(); e != nil {
			t.Fatal(e)
		}
		if i >= 192 {
			unsupported = append(unsupported, b.Bytes())
			continue
		}
		result, e := Convert(bytes.NewReader(b.Bytes()), int64(b.Len()), &Options{NoSystemFonts: true, SystemFonts: true, NoTextIndex: true, Data: "none"})
		if e != nil {
			t.Fatal(e)
		}
		var doc bytes.Buffer
		if e = result.Doc.WriteSingle(&doc); e != nil {
			t.Fatal(e)
		}
		out = append(out, map[string]any{"input": b.Bytes(), "bdf": doc.Bytes(), "warnings": result.Warnings, "mode": "none", "no_index": true})
	}
	for name, v := range map[string]any{"sheet-notes.json": out, "sheet-notes-unsupported.json": unsupported} {
		data, e := json.Marshal(v)
		if e != nil {
			t.Fatal(e)
		}
		if e = os.WriteFile(filepath.Join(root, "compat/xlsx", name), data, 0644); e != nil {
			t.Fatal(e)
		}
	}
}
