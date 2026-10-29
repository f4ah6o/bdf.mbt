//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexXLSXValuesTable.
package xlsx

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"fmt"
	parquetenc "github.com/shibukawa/bdf/encoding/parquet"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexXLSXValuesTable(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	b, e := os.ReadFile(filepath.Join(root, "compat/xlsx/display.json"))
	if e != nil {
		t.Fatal(e)
	}
	var samples []struct {
		Input  []byte `json:"input"`
		Part   string `json:"part"`
		Locale string `json:"locale"`
	}
	if e = json.Unmarshal(b, &samples); e != nil {
		t.Fatal(e)
	}
	r := rand.New(rand.NewSource(431286))
	for i := 0; i < 300; i++ {
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
		add("xl/workbook.xml", fmt.Sprintf(`<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><workbookPr date1904="%d"/><sheets><sheet name="s" r:id="r1"/></sheets></workbook>`, i%2))
		add("xl/_rels/workbook.xml.rels", `<Relationships><Relationship Id="r1" Type="x/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="r2" Type="x/styles" Target="styles.xml"/></Relationships>`)
		add("xl/styles.xml", `<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><cellXfs><xf numFmtId="0"/><xf numFmtId="14"/><xf numFmtId="22"/><xf numFmtId="2"/><xf numFmtId="9"/></cellXfs></styleSheet>`)
		data := `<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>`
		dates := []float64{0, 1, 59, 60, 61, 43587, 2958465, -3}
		for j := 0; j < 10; j++ {
			d := dates[r.Intn(len(dates))]
			data += fmt.Sprintf(`<row r="%d"><c r="A%d"><v>%d</v></c><c r="B%d"><v>%.3f</v></c><c r="C%d" s="1"><v>%g</v></c><c r="D%d" s="2"><v>%g</v></c><c r="E%d" t="b"><v>%d</v></c>`, j+1, j+1, r.Intn(1000)-500, j+1, r.Float64()*100, j+1, d, j+1, d+0.5, j+1, r.Intn(2))
			if j%3 == 0 {
				data += fmt.Sprintf(`<c r="F%d" t="str"><v>Item %d</v></c>`, j+1, j)
			} else {
				data += fmt.Sprintf(`<c r="F%d" s="%d"><v>%.3f</v></c>`, j+1, 3+r.Intn(2), r.Float64()*100)
			}
			data += fmt.Sprintf(`<c r="G%d" t="e"><v>#DIV/0!</v></c></row>`, j+1)
		}
		data += `</sheetData></worksheet>`
		add("xl/worksheets/sheet1.xml", data)
		if e := z.Close(); e != nil {
			t.Fatal(e)
		}
		samples = append(samples, struct {
			Input  []byte `json:"input"`
			Part   string `json:"part"`
			Locale string `json:"locale"`
		}{b.Bytes(), "xl/worksheets/sheet1.xml", ""})
	}
	out := []any{}
	for i, s := range samples {
		c, _, e := openWorkbook(bytes.NewReader(s.Input), int64(len(s.Input)), &Options{NoSystemFonts: true, SystemFonts: true})
		if e != nil {
			t.Fatal(e)
		}
		c.locale = s.Locale
		ws, e := c.readWorksheet(s.Part)
		if e != nil {
			t.Fatal(e)
		}
		ws.sortRows()
		ref, ok := usedRange(ws)
		if !ok || ref.r1-ref.r0 > 1000 || ref.c1-ref.c0 > 100 {
			continue
		}
		names := []string{}
		if i%2 == 0 {
			names = []string{"Alpha", "", "Gamma"}
		}
		table := c.valuesTable(ws, ref, names)
		enc, e := parquetenc.Encode(table)
		if e != nil {
			t.Fatal(e)
		}
		c.storeRange(ws, ref, "sheet1", "Example", names, "sheet1", "all")
		out = append(out, map[string]any{"input": s.Input, "part": s.Part, "locale": s.Locale, "names": names, "range": []int{ref.r0, ref.c0, ref.r1, ref.c1}, "parquet": enc, "manifest": c.doc.Tables})
	}
	b, e = json.Marshal(out)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/table-values.json"), b, 0644); e != nil {
		t.Fatal(e)
	}
}
