//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexSheetMissingParts.
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

func TestCodexSheetMissingParts(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	variants := []string{`<drawing/>`, `<drawing r:id="missing"/>`, `<drawing id="missing"/>`, `<tableParts/>`, `<tableParts><tablePart r:id="missing"/></tableParts>`, `<tableParts><tablePart/><tablePart r:id="missing"/></tableParts>`, `<drawing r:id="missing"/><tableParts><tablePart r:id="missing"/></tableParts>`, `<tableParts><other><tablePart r:id="real"/></other></tableParts>`}
	out := []any{}
	unsupported := []any{}
	for i := 0; i < 168; i++ {
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
		add("xl/worksheets/_rels/sheet1.xml.rels", `<Relationships><Relationship Id="real" Type="x/drawing" Target="../drawings/drawing1.xml"/></Relationships>`)
		add("xl/drawings/drawing1.xml", `<wsDr/>`)
		feature := variants[i%len(variants)]
		if i >= 160 {
			if i%2 == 0 {
				feature = `<drawing r:id="real"/>`
			} else {
				feature = `<tableParts><tablePart r:id="real"/></tableParts>`
			}
		}
		body := fmt.Sprintf(`<worksheet xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>Hello</t></is></c><c r="B1"><v>%d</v></c></row></sheetData>%s</worksheet>`, i, feature)
		add("xl/worksheets/sheet1.xml", body)
		if e := z.Close(); e != nil {
			t.Fatal(e)
		}
		if i >= 160 {
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
	for name, v := range map[string]any{"sheet-missing-parts.json": out, "sheet-missing-parts-unsupported.json": unsupported} {
		data, e := json.Marshal(v)
		if e != nil {
			t.Fatal(e)
		}
		if e = os.WriteFile(filepath.Join(root, "compat/xlsx", name), data, 0644); e != nil {
			t.Fatal(e)
		}
	}
}
