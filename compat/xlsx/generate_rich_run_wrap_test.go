//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexRichRunWrap.
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

func TestCodexRichRunWrap(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	out := []any{}
	rejects := []any{}
	texts := []string{`<r><t>long text with words </t></r><r><t>and further wrapped words</t></r>`, `<r><t xml:space="preserve">a </t></r><r><t>b</t></r>`, `<r><t>Hello</t></r><r><t>_x000A_World</t></r>`, `<r><t>日本語</t></r><r><t>é 😀</t></r>`, `<r><t/></r><r><t>x</t></r>`, `<t>before</t><r><t>middle</t></r><r><t>after</t></r>`, `<r><t>Wi</t></r><r><t>de</t></r>`}
	for i := 0; i < 168; i++ {
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
		add("xl/styles.xml", `<styleSheet><numFmts><numFmt numFmtId="164" formatCode="0;0;0;[Red]&quot;prefix &quot;@"/></numFmts><fonts><font/><font><sz val="18"/><b/></font></fonts><cellXfs><xf/><xf numFmtId="164"><alignment wrapText="1"/></xf><xf fontId="1" numFmtId="164"><alignment wrapText="1"/></xf><xf numFmtId="164"><alignment wrapText="1"/></xf><xf><alignment horizontal="center"/></xf><xf><alignment horizontal="right"/></xf></cellXfs></styleSheet>`)
		text := texts[i%len(texts)]
		shared, inline := `<si><t>ordinary</t></si>`, `<is><t>ordinary</t></is>`
		if i%2 == 0 {
			shared = "<si>" + text + "</si>"
		} else {
			inline = "<is>" + text + "</is>"
		}
		add("xl/sharedStrings.xml", "<sst>"+shared+"</sst>")
		style := fmt.Sprintf(` s="%d"`, (i/14)%6)
		add("xl/worksheets/sheet1.xml", fmt.Sprintf(`<worksheet><cols><col min="1" max="2" width="5" customWidth="1"/></cols><sheetData><row r="1"><c r="A1" t="s"%s><v>0</v></c><c r="B1" t="inlineStr"%s>%s</c></row></sheetData></worksheet>`, style, style, inline))
		if e := z.Close(); e != nil {
			t.Fatal(e)
		}
		mode := []string{"none", "all", "default"}[(i/2)%3]
		noIndex := i%2 == 0
		x, e := Convert(bytes.NewReader(b.Bytes()), int64(b.Len()), &Options{NoSystemFonts: true, SystemFonts: true, NoTextIndex: noIndex, Data: mode})
		if e != nil {
			t.Fatal(e)
		}
		var rendered bytes.Buffer
		if e = x.Doc.WriteSingle(&rendered); e != nil {
			t.Fatal(e)
		}
		out = append(out, map[string]any{"input": b.Bytes(), "bdf": rendered.Bytes(), "warnings": x.Warnings, "mode": mode, "no_index": noIndex})
	}
	for name, v := range map[string]any{"rich-run-wrap.json": out, "rich-run-wrap-unsupported.json": rejects} {
		data, e := json.Marshal(v)
		if e != nil {
			t.Fatal(e)
		}
		if e = os.WriteFile(filepath.Join(root, "compat/xlsx", name), data, 0644); e != nil {
			t.Fatal(e)
		}
	}
}
