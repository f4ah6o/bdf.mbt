//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexXLSXRender.
package xlsx

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"fmt"
	"html"
	"math/rand"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCodexXLSXRender(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	r := rand.New(rand.NewSource(63156))
	out := []any{}
	for i := 0; i < 600; i++ {
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
		if i >= 450 {
			add("_rels/.rels", `<Relationships><Relationship Id="r1" Type="x/core-properties" Target="docProps/core.xml"/></Relationships>`)
			lang := []string{"", "en-US", "ja-JP", "zh-CN", "ko-KR"}[r.Intn(5)]
			props := fmt.Sprintf(`<coreProperties><title>Test %d</title><creator>A</creator><creator>B</creator><keywords>one;two</keywords><language>%s</language><created>2024-01-01</created></coreProperties>`, i, lang)
			add("docProps/core.xml", props)
		}
		add("xl/workbook.xml", `<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet1" r:id="r1"/></sheets></workbook>`)
		rels := `<Relationships><Relationship Id="r1" Type="x/worksheet" Target="worksheets/sheet1.xml"/>`
		if i >= 300 {
			rels += `<Relationship Id="r2" Type="x/sharedStrings" Target="sharedStrings.xml"/>`
		}
		rels += `</Relationships>`
		add("xl/_rels/workbook.xml.rels", rels)
		shared := []string{"Alpha", "日本語", "First_x000A_Second", "long shared string that extends across cells", "🙂 emoji"}
		if i >= 300 {
			ss := `<sst>`
			for _, t := range shared {
				ss += `<si><t>` + html.EscapeString(t) + `</t></si>`
			}
			ss += `</sst>`
			add("xl/sharedStrings.xml", ss)
		}
		sheet := `<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">`
		if i >= 150 {
			sheet += fmt.Sprintf(`<sheetFormatPr defaultColWidth="%g" defaultRowHeight="%g" zeroHeight="%d"/>`, []float64{0, 8, 12, 20}[r.Intn(4)], []float64{0, 12, 15, 24}[r.Intn(4)], r.Intn(5)/4)
		}
		sheet += `<sheetData>`
		for y := 0; y < r.Intn(4)+1; y++ {
			attrs := ""
			if i >= 150 {
				if r.Intn(3) == 0 {
					attrs = fmt.Sprintf(` ht="%d" customHeight="1"`, 5+r.Intn(40))
				}
				if r.Intn(5) == 0 {
					attrs += ` hidden="1"`
				}
			}
			sheet += fmt.Sprintf(`<row r="%d"%s>`, y+1, attrs)
			for x := 0; x < r.Intn(4)+1; x++ {
				col := colName(x)
				if r.Intn(2) == 0 {
					texts := []string{"Hello", "abc", "hi there", "A"}
					if i >= 50 {
						texts = append(texts, "Longer text that exceeds one cell", strings.Repeat("wide", 40), "日本語", "line1\nline2", "🙂 emoji")
					}
					t := texts[r.Intn(len(texts))]
					switch {
					case i >= 300 && r.Intn(2) == 0:
						sheet += fmt.Sprintf(`<c r="%s%d" t="s"><v>%d</v></c>`, col, y+1, r.Intn(len(shared)))
					case i >= 300:
						sheet += fmt.Sprintf(`<c r="%s%d" t="inlineStr"><is><t>%s</t></is></c>`, col, y+1, html.EscapeString(t))
					default:
						sheet += fmt.Sprintf(`<c r="%s%d" t="str"><v>%s</v></c>`, col, y+1, html.EscapeString(t))
					}
				} else {
					sheet += fmt.Sprintf(`<c r="%s%d"><v>%d</v></c>`, col, y+1, r.Intn(10000))
				}
			}
			sheet += `</row>`
		}
		sheet += `</sheetData></worksheet>`
		add("xl/worksheets/sheet1.xml", sheet)
		if e := z.Close(); e != nil {
			t.Fatal(e)
		}
		mode := []string{"none", "", "all"}[i%3]
		noIndex := i%2 == 0
		result, e := Convert(bytes.NewReader(b.Bytes()), int64(b.Len()), &Options{NoSystemFonts: true, SystemFonts: true, NoTextIndex: noIndex, Data: mode})
		if e != nil {
			t.Fatal(e)
		}
		var file bytes.Buffer
		if e = result.Doc.WriteSingle(&file); e != nil {
			t.Fatal(e)
		}
		out = append(out, map[string]any{"input": b.Bytes(), "bdf": file.Bytes(), "warnings": result.Warnings, "mode": mode, "no_index": noIndex})
	}
	data, e := json.Marshal(out)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/render.json"), data, 0644); e != nil {
		t.Fatal(e)
	}
}
