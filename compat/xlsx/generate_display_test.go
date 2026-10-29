//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexXLSXDisplay.
package xlsx

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"fmt"
	"math"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexXLSXDisplay(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	raw, e := os.ReadFile(filepath.Join(root, "compat/xlsx/cells.json"))
	if e != nil {
		t.Fatal(e)
	}
	var prior []struct {
		Input []byte `json:"input"`
		Part  string `json:"part"`
	}
	if e = json.Unmarshal(raw, &prior); e != nil {
		t.Fatal(e)
	}
	samples := prior[:min(250, len(prior))]
	r := rand.New(rand.NewSource(315212))
	for i := 0; i < 300; i++ {
		var b bytes.Buffer
		z := zip.NewWriter(&b)
		add := func(name, s string) {
			f, e := z.Create(name)
			if e != nil {
				t.Fatal(e)
			}
			if _, e = f.Write([]byte(s)); e != nil {
				t.Fatal(e)
			}
		}
		add("xl/workbook.xml", `<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="s" r:id="rId1"/></sheets></workbook>`)
		add("xl/_rels/workbook.xml.rels", `<Relationships><Relationship Id="rId1" Type="x/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="x/styles" Target="styles.xml"/></Relationships>`)
		style := `<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><numFmts><numFmt numFmtId="164" formatCode="[Color10]0.00"/><numFmt numFmtId="165" formatCode="yyyy-mm-dd"/><numFmt numFmtId="166" formatCode="0;[Red](0);0;&quot;Value: &quot;@"/></numFmts><cellXfs><xf numFmtId="0"/><xf numFmtId="164"/><xf numFmtId="165"/><xf numFmtId="166"/><xf numFmtId="14"/></cellXfs><colors><indexedColors>`
		for j := 0; j < r.Intn(30); j++ {
			style += fmt.Sprintf(`<rgbColor rgb="FF%06X"/>`, r.Intn(1<<24))
		}
		style += `</indexedColors></colors></styleSheet>`
		add("xl/styles.xml", style)
		data := `<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1">`
		for j := 0; j < 20; j++ {
			data += fmt.Sprintf(`<c s="%d"><v>%f</v></c>`, r.Intn(8), r.Float64()*50000-5000)
		}
		data += `<c s="3" t="inlineStr"><is><t>text</t></is></c><c t="b"><v>1</v></c><c t="e"><v>#VALUE!</v></c><c/></row></sheetData></worksheet>`
		add("xl/worksheets/sheet1.xml", data)
		if e = z.Close(); e != nil {
			t.Fatal(e)
		}
		samples = append(samples, struct {
			Input []byte `json:"input"`
			Part  string `json:"part"`
		}{b.Bytes(), "xl/worksheets/sheet1.xml"})
	}
	encode := func(f formatted) any {
		p := []any{}
		for _, x := range f.pieces {
			p = append(p, []any{int(x.kind), x.s})
		}
		var color any = nil
		if f.color != nil {
			color = int(math.Round(f.color.R*255))<<16 | int(math.Round(f.color.G*255))<<8 | int(math.Round(f.color.B*255))
		}
		return []any{p, color, f.general, f.number}
	}
	out := []any{}
	for i, s := range samples {
		c, _, e := openWorkbook(bytes.NewReader(s.Input), int64(len(s.Input)), &Options{NoSystemFonts: true, SystemFonts: true})
		if e != nil {
			t.Fatal(e)
		}
		locale := ""
		if i%2 == 0 {
			locale = "ja"
		}
		c.locale = locale
		ws, e := c.readWorksheet(s.Part)
		if e != nil {
			t.Fatal(e)
		}
		rows := []any{}
		for _, row := range ws.rows {
			cells := []any{}
			for _, cl := range row.cells {
				var f any
				nf := c.st.numFormat(c.st.xf(cl.style).numFmt)
				switch cl.kind {
				case cellNum:
					f = encode(nf.formatNumber(cl.num, c.date1904))
				case cellStr:
					f = encode(nf.formatText(cl.text.plain))
				case cellBool:
					word := "FALSE"
					if cl.num != 0 {
						word = "TRUE"
					}
					f = encode(formatted{pieces: []piece{{pieceText, word}}})
				case cellErr:
					f = encode(formatted{pieces: []piece{{pieceText, cl.text.plain}}})
				}
				cells = append(cells, f)
			}
			rows = append(rows, cells)
		}
		pal := []any{}
		for _, color := range c.st.palette {
			pal = append(pal, int(math.Round(color.R*255))<<16|int(math.Round(color.G*255))<<8|int(math.Round(color.B*255)))
		}
		out = append(out, map[string]any{"input": s.Input, "part": s.Part, "locale": locale, "palette": pal, "rows": rows})
	}
	b, e := json.Marshal(out)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/display.json"), b, 0644); e != nil {
		t.Fatal(e)
	}
}
