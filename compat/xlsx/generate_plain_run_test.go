//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexPlainRun.
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

func TestCodexPlainRun(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	out := []any{}
	rejects := []any{}
	texts := []string{`<r><t>one</t></r>`, `<r><t>one &amp; two</t></r>`, `<t>before </t><r><t>middle</t></r><t> after</t>`, `<r><t>Hello_x000A_World</t></r>`, `<r><t/></r>`, `<r><t xml:space="preserve">  spaced  </t></r>`}
	for i := 0; i < 128; i++ {
		var b bytes.Buffer
		z := zip.NewWriter(&b)
		add := func(n, s string) {
			f, e := z.Create(n)
			if e != nil {
				t.Fatal(e)
			}
			if _, e = f.Write([]byte(s)); e != nil {
				t.Fatal(e)
			}
		}
		add("xl/workbook.xml", `<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet" r:id="r1"/></sheets></workbook>`)
		add("xl/_rels/workbook.xml.rels", `<Relationships><Relationship Id="r1" Type="x/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="r2" Type="x/sharedStrings" Target="sharedStrings.xml"/><Relationship Id="r3" Type="x/styles" Target="styles.xml"/></Relationships>`)
		add("xl/styles.xml", `<styleSheet><numFmts><numFmt numFmtId="164" formatCode="0;0;0;[Red]&quot;prefix &quot;@"/></numFmts><cellXfs><xf/><xf numFmtId="164"/></cellXfs></styleSheet>`)
		text := texts[i%len(texts)]
		if i >= 120 {
			text = []string{`<r/>`, `<r><t>one</t></r><r><t>two</t></r>`, `<r><t>one</t><t>two</t></r>`, `<r><rPr><b/></rPr><t>styled</t></r>`}[((i-120)/2)%4]
		}
		shared, inline := `<si><t>ordinary</t></si>`, `<is><t>ordinary</t></is>`
		if i%2 == 0 {
			shared = "<si>" + text + "</si>"
		} else {
			inline = "<is>" + text + "</is>"
		}
		add("xl/sharedStrings.xml", "<sst>"+shared+"</sst>")
		style := ""
		if i%3 == 0 {
			style = ` s="1"`
		}
		add("xl/worksheets/sheet1.xml", fmt.Sprintf(`<worksheet><sheetData><row r="1"><c r="A1" t="s"%s><v>0</v></c><c r="B1" t="inlineStr"%s>%s</c></row></sheetData></worksheet>`, style, style, inline))
		if e := z.Close(); e != nil {
			t.Fatal(e)
		}
		if i >= 120 {
			rejects = append(rejects, b.Bytes())
			continue
		}
		x, e := Convert(bytes.NewReader(b.Bytes()), int64(b.Len()), &Options{NoSystemFonts: true, SystemFonts: true, NoTextIndex: true, Data: "none"})
		if e != nil {
			t.Fatal(e)
		}
		var rendered bytes.Buffer
		if e = x.Doc.WriteSingle(&rendered); e != nil {
			t.Fatal(e)
		}
		out = append(out, map[string]any{"input": b.Bytes(), "bdf": rendered.Bytes(), "warnings": x.Warnings, "mode": "none", "no_index": true})
	}
	for name, v := range map[string]any{"plain-run.json": out, "plain-run-unsupported.json": rejects} {
		data, e := json.Marshal(v)
		if e != nil {
			t.Fatal(e)
		}
		if e = os.WriteFile(filepath.Join(root, "compat/xlsx", name), data, 0644); e != nil {
			t.Fatal(e)
		}
	}
}
