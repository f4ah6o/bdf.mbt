//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexLinks.
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

func TestCodexLinks(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	out := []any{}
	for i := 0; i < 200; i++ {
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
		add("xl/_rels/workbook.xml.rels", `<Relationships><Relationship Id="r1" Type="x/worksheet" Target="worksheets/sheet1.xml"/></Relationships>`)
		url := []string{"https://example.com/path", "http://example.org/a?x=1", "mailto:hello@example.com", "ftp://example.com/no", "https://example.com/other"}[i%5]
		rels := fmt.Sprintf(`<Relationships><Relationship Id="ext" Type="x/hyperlink" Target="%s" TargetMode="External"/><Relationship Id="internal" Type="x/hyperlink" Target="other.xml"/></Relationships>`, url)
		add("xl/worksheets/_rels/sheet1.xml.rels", rels)
		refs := []string{"A1", "B1:D3", "A1:AT200", "AT1:AT200", "A199:AT200", "A1 B200", "C4:D10"}[(i/5)%7]
		id := []string{"ext", "ext", "ext", "internal", "missing", ""}[(i/35)%6]
		loc := ""
		if i%3 == 0 {
			loc = ` location="section"`
		}
		if id != "" {
			id = ` r:id="` + id + `"`
		}
		hidden := ""
		if i%4 == 0 {
			hidden = `<row r="2" hidden="1"/>`
		}
		add("xl/worksheets/sheet1.xml", fmt.Sprintf(`<worksheet xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheetData><row r="1"><c r="A1" t="str"><v>first</v></c><c r="AT1" t="str"><v>last</v></c></row>%s<row r="200"><c r="B200" t="str"><v>end</v></c></row></sheetData><hyperlinks><hyperlink ref="%s"%s%s/><hyperlink ref="A1" location="Sheet2!A1"/></hyperlinks></worksheet>`, hidden, refs, id, loc))
		if e := z.Close(); e != nil {
			t.Fatal(e)
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
	unsupported := []any{}
	for _, target := range []string{"https://example.com/%20", "http://example.com:bad"} {
		var b bytes.Buffer
		z := zip.NewWriter(&b)
		add := func(n, s string) {
			f, err := z.Create(n)
			if err != nil {
				t.Fatal(err)
			}
			if _, err = f.Write([]byte(s)); err != nil {
				t.Fatal(err)
			}
		}
		add("xl/workbook.xml", `<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet" r:id="r1"/></sheets></workbook>`)
		add("xl/_rels/workbook.xml.rels", `<Relationships><Relationship Id="r1" Type="x/worksheet" Target="worksheets/sheet1.xml"/></Relationships>`)
		add("xl/worksheets/_rels/sheet1.xml.rels", fmt.Sprintf(`<Relationships><Relationship Id="ext" Type="x/hyperlink" Target="%s" TargetMode="External"/></Relationships>`, target))
		add("xl/worksheets/sheet1.xml", `<worksheet xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheetData><row r="1"><c r="A1" t="str"><v>x</v></c></row></sheetData><hyperlinks><hyperlink ref="A1" r:id="ext"/></hyperlinks></worksheet>`)
		if err := z.Close(); err != nil {
			t.Fatal(err)
		}
		unsupported = append(unsupported, b.Bytes())
	}
	{
		var b bytes.Buffer
		z := zip.NewWriter(&b)
		add := func(n, s string) {
			f, err := z.Create(n)
			if err != nil {
				t.Fatal(err)
			}
			if _, err = f.Write([]byte(s)); err != nil {
				t.Fatal(err)
			}
		}
		add("xl/workbook.xml", `<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet" r:id="r1"/></sheets></workbook>`)
		add("xl/_rels/workbook.xml.rels", `<Relationships><Relationship Id="r1" Type="x/worksheet" Target="worksheets/sheet1.xml"/></Relationships>`)
		add("xl/worksheets/_rels/sheet1.xml.rels", `<Relationships><Relationship Id="ext" Type="x/hyperlink" Target="https://example.com" TargetMode="External"/></Relationships>`)
		add("xl/worksheets/sheet1.xml", `<worksheet xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheetData><row r="1"><c r="XFD1" t="str"><v>x</v></c></row><row r="30000"><c r="A30000" t="str"><v>x</v></c></row></sheetData><hyperlinks><hyperlink ref="A1:XFD30000" r:id="ext"/></hyperlinks></worksheet>`)
		if err := z.Close(); err != nil {
			t.Fatal(err)
		}
		unsupported = append(unsupported, b.Bytes())
	}
	data, e := json.Marshal(unsupported)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/links-unsupported.json"), data, 0644); e != nil {
		t.Fatal(e)
	}
	data, e = json.Marshal(out)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/links.json"), data, 0644); e != nil {
		t.Fatal(e)
	}
}
