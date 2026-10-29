//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexXLSXListTables.
package xlsx

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexXLSXListTables(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	var samples []struct {
		Input []byte `json:"input"`
		Part  string `json:"part"`
	}
	for _, name := range []string{"basic.xlsx", "features.xlsx", "form-fixed.xlsx", "form-pages.xlsx", "form-rows.xlsx", "math.xlsx", "print.xlsx"} {
		b, e := os.ReadFile(filepath.Join("testdata", name))
		if e != nil {
			t.Fatal(e)
		}
		c, _, e := openWorkbook(bytes.NewReader(b), int64(len(b)), &Options{NoSystemFonts: true, SystemFonts: true})
		if e != nil {
			t.Fatal(e)
		}
		for _, s := range c.sheets {
			if !s.chart {
				samples = append(samples, struct {
					Input []byte `json:"input"`
					Part  string `json:"part"`
				}{b, s.part})
			}
		}
	}
	r := rand.New(rand.NewSource(655108))
	refs := []string{"A1:C5", "B2:B9", "1:3", "A:C", "bad", "", "XFD1048576", "C10:A1"}
	names := []string{"Table1", "Revenue_x0020_2024", "日本語", "_x005F_x0041_", ""}
	for i := 0; i < 1000; i++ {
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
		add("xl/workbook.xml", `<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"/>`)
		sheet := `<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><tableParts>`
		rels := `<Relationships>`
		for j := 0; j < r.Intn(7); j++ {
			sheet += fmt.Sprintf(`<tablePart r:id="r%d"/>`, j)
			rels += fmt.Sprintf(`<Relationship Id="r%d" Type="x/table" Target="../tables/table%d.xml"/>`, j, j)
			if r.Intn(7) != 0 {
				name := names[r.Intn(len(names))]
				table := fmt.Sprintf(`<table ref="%s" displayName="%s" name="fallback" headerRowCount="%d" totalsRowCount="%d"><tableColumns>`, refs[r.Intn(len(refs))], name, r.Intn(4)-1, r.Intn(4)-1)
				for k := 0; k < r.Intn(6); k++ {
					table += fmt.Sprintf(`<tableColumn name="%s"/>`, names[r.Intn(len(names))])
				}
				table += `</tableColumns></table>`
				add(fmt.Sprintf("xl/tables/table%d.xml", j), table)
			}
		}
		sheet += `</tableParts></worksheet>`
		rels += `</Relationships>`
		add("xl/worksheets/sheet1.xml", sheet)
		add("xl/worksheets/_rels/sheet1.xml.rels", rels)
		if e := z.Close(); e != nil {
			t.Fatal(e)
		}
		samples = append(samples, struct {
			Input []byte `json:"input"`
			Part  string `json:"part"`
		}{b.Bytes(), "xl/worksheets/sheet1.xml"})
	}
	out := []any{}
	for _, s := range samples {
		c, _, e := openWorkbook(bytes.NewReader(s.Input), int64(len(s.Input)), &Options{NoSystemFonts: true, SystemFonts: true})
		if e != nil {
			t.Fatal(e)
		}
		ws, e := c.readWorksheet(s.Part)
		if e != nil {
			t.Fatal(e)
		}
		ts := []any{}
		for _, v := range c.listTables(ws) {
			cols := v.cols
			if cols == nil {
				cols = []string{}
			}
			ts = append(ts, []any{v.ref.r0, v.ref.c0, v.ref.r1, v.ref.c1, v.name, cols, v.header, v.totals})
		}
		out = append(out, map[string]any{"input": s.Input, "part": s.Part, "want": ts})
	}
	b, e := json.Marshal(out)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/list-tables.json"), b, 0644); e != nil {
		t.Fatal(e)
	}
}
