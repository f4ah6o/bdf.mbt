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
	for i := 0; i < 1850; i++ {
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
		count := 1
		if i >= 600 {
			count = 2 + r.Intn(3)
		}
		wb := `<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>`
		rels := `<Relationships>`
		for j := 1; j <= count; j++ {
			state := ""
			if i >= 600 && j < count && r.Intn(4) == 0 {
				state = ` state="hidden"`
			}
			wb += fmt.Sprintf(`<sheet name="Sheet%d" r:id="r%d"%s/>`, j, j, state)
			rels += fmt.Sprintf(`<Relationship Id="r%d" Type="x/worksheet" Target="worksheets/sheet%d.xml"/>`, j, j)
		}
		wb += `</sheets></workbook>`
		add("xl/workbook.xml", wb)
		if i >= 300 {
			rels += `<Relationship Id="rShared" Type="x/sharedStrings" Target="sharedStrings.xml"/>`
		}
		if i >= 1450 {
			rels += `<Relationship Id="rStyles" Type="x/styles" Target="styles.xml"/>`
		}
		rels += `</Relationships>`
		add("xl/_rels/workbook.xml.rels", rels)
		if i >= 1450 {
			st := `<styleSheet><cellXfs><xf numFmtId="0"/>`
			for _, id := range []int{1, 2, 3, 4, 9, 10, 11, 14, 20, 22, 46, 49} {
				st += fmt.Sprintf(`<xf numFmtId="%d"/>`, id)
			}
			st += `</cellXfs></styleSheet>`
			add("xl/styles.xml", st)
		}
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
		if i >= 1050 {
			sheet += fmt.Sprintf(`<sheetViews><sheetView showGridLines="%d" showZeros="%d" rightToLeft="%d"><pane state="frozen" xSplit="%d" ySplit="%d"/></sheetView></sheetViews>`, r.Intn(2), r.Intn(2), r.Intn(5)/4, r.Intn(6), r.Intn(6))
		}
		if i >= 150 {
			sheet += fmt.Sprintf(`<sheetFormatPr defaultColWidth="%g" defaultRowHeight="%g" zeroHeight="%d"/>`, []float64{0, 8, 12, 20}[r.Intn(4)], []float64{0, 12, 15, 24}[r.Intn(4)], r.Intn(5)/4)
		}
		if i >= 900 {
			sheet += `<cols>`
			for j := 0; j < 4; j++ {
				a := 1 + r.Intn(5)
				b := a + r.Intn(4)
				sheet += fmt.Sprintf(`<col min="%d" max="%d" width="%d" hidden="%d"/>`, a, b, func() int {
					if i >= 1200 {
						if i >= 1750 {
							return r.Intn(4)
						}
						return 2 + r.Intn(14)
					}
					return 12 + r.Intn(18)
				}(), r.Intn(6)/5)
			}
			sheet += `</cols>`
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
				if i >= 1750 && r.Intn(4) == 0 {
					if r.Intn(2) == 0 {
						sheet += fmt.Sprintf(`<c r="%s%d" t="str"><v></v></c>`, col, y+1)
					} else {
						sheet += fmt.Sprintf(`<c r="%s%d" t="inlineStr"><is><t/></is></c>`, col, y+1)
					}
					continue
				}
				if i >= 750 && (i < 1200 || i >= 1600) && r.Intn(3) == 0 {
					if r.Intn(2) == 0 {
						sheet += fmt.Sprintf(`<c r="%s%d" t="b"><v>%d</v></c>`, col, y+1, r.Intn(2))
					} else {
						sheet += fmt.Sprintf(`<c r="%s%d" t="e"><v>%s</v></c>`, col, y+1, []string{"#N/A", "#REF!", "#VALUE!", "#DIV/0!", "#LONG-ERROR-CODE"}[r.Intn(2)])
					}
					continue
				}
				if r.Intn(2) == 0 {
					texts := []string{"Hello", "abc", "hi there", "A"}
					if i >= 50 {
						texts = append(texts, "Longer text that exceeds one cell", strings.Repeat("wide", 40), "日本語", "line1\nline2", "🙂 emoji")
					}
					if i >= 1350 {
						texts = append(texts, strings.Repeat("a\n", 600)+"end", "tab\ttext", "A\rB")
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
					if i >= 1200 {
						v := []string{"123456789", "-123456789", "0.123456789012345", "0.000000000012345", "123456789012345", "-0.987654321", "0"}[r.Intn(7)]
						if i >= 1450 {
							sheet += fmt.Sprintf(`<c r="%s%d" s="%d"><v>%s</v></c>`, col, y+1, 1+r.Intn(12), v)
						} else {
							sheet += fmt.Sprintf(`<c r="%s%d"><v>%s</v></c>`, col, y+1, v)
						}
					} else {
						v := r.Intn(10000)
						if i >= 1050 && r.Intn(3) == 0 {
							v = 0
						}
						sheet += fmt.Sprintf(`<c r="%s%d"><v>%d</v></c>`, col, y+1, v)
					}
				}
			}
			sheet += `</row>`
		}
		sheet += `</sheetData></worksheet>`
		add("xl/worksheets/sheet1.xml", sheet)
		for j := 2; j <= count; j++ {
			extra := fmt.Sprintf(`<row r="%d"><c r="A%d" t="str"><v>Sheet %d</v></c></row>`, 5+j, 5+j, j)
			add(fmt.Sprintf("xl/worksheets/sheet%d.xml", j), strings.Replace(sheet, "</sheetData>", extra+"</sheetData>", 1))
		}
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
