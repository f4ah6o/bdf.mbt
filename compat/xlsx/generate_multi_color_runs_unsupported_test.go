//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexMultiColorRunsUnsupported.
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

func TestCodexMultiColorRunsUnsupported(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	texts := []string{
		`<r><rPr><b/></rPr><t>bold</t></r><r><t>plain</t></r>`,
		`<r><rPr><sz val="14"/></rPr><t>large</t></r><r><t>plain</t></r>`,
		`<r><rPr><rFont val="Arial"/></rPr><t>font</t></r><r><t>plain</t></r>`,
		`<r><rPr><color rgb="FFCC0011"/></rPr><t>日本語</t></r><r><t>plain</t></r>`,
		`<r><rPr><color rgb="FFCC0011"/></rPr><t>red </t></r><r><t>plain </t></r>`,
		`<r><rPr><color rgb="FFCC0011"/></rPr><t>red_x000A_</t></r><r><t>plain</t></r>`,
		`<r><rPr><color rgb="FFCC0011"/></rPr><t/></r><r><t/></r>`,
		`<r><rPr><color rgb="FFCC0011"/></rPr><t>` + strings.Repeat("x", 1025) + `</t></r><r><t>plain</t></r>`,
	}
	out := []any{}
	for i := 0; i < 32; i++ {
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
		add("xl/styles.xml", `<styleSheet><fonts><font/><font><b/></font></fonts><cellXfs><xf/><xf fontId="1"/><xf><alignment wrapText="1"/></xf><xf><alignment horizontal="center"/></xf></cellXfs></styleSheet>`)
		text := texts[i%len(texts)]
		style := (i / 8) % 4
		body := fmt.Sprintf(`<worksheet><sheetData><row r="1"><c r="A1" s="%d" t="inlineStr"><is>%s</is></c></row></sheetData></worksheet>`, style, text)
		add("xl/worksheets/sheet1.xml", body)
		if e := z.Close(); e != nil {
			t.Fatal(e)
		}
		out = append(out, b.Bytes())
	}
	data, e := json.Marshal(out)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/multi-color-runs-unsupported.json"), data, 0644); e != nil {
		t.Fatal(e)
	}
}
