//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexXLSXRender.
package xlsx

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"fmt"
	"html"
	"io"
	"math"
	"math/rand"
	"os"
	"path/filepath"
	"regexp"
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
	for i := 0; i < 9600; i++ {
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
		if i >= 2250 {
			rels += `<Relationship Id="rTheme" Type="x/theme" Target="theme/theme1.xml"/>`
		}
		rels += `</Relationships>`
		add("xl/_rels/workbook.xml.rels", rels)
		if i >= 2250 {
			th := `<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:themeElements><a:clrScheme>`
			for j, name := range []string{"lt1", "dk1", "lt2", "dk2", "accent1", "accent2", "accent3", "accent4", "accent5", "accent6", "hlink", "folHlink"} {
				value := r.Intn(1 << 24)
				if j%2 == 0 {
					th += fmt.Sprintf(`<a:%s><a:srgbClr val="%06X"/></a:%s>`, name, value, name)
				} else {
					th += fmt.Sprintf(`<a:%s><a:sysClr val="window" lastClr="%06X"/></a:%s>`, name, value, name)
				}
			}
			th += `</a:clrScheme>`
			if i >= 7400 {
				ea := []string{"", "Noto Sans CJK"}[i%2]
				major := []string{"Times New Roman", ""}[(i/2)%2]
				minor := []string{"Arial", ""}[(i/4)%2]
				th += fmt.Sprintf(`<a:fontScheme name="Test"><a:majorFont><a:latin typeface="%s"/><a:ea typeface="%s"/><a:font script="Jpan" typeface="MS Mincho"/><a:font script="Hans" typeface="SimSun"/><a:font script="Hant" typeface="PMingLiU"/><a:font script="Hang" typeface="Batang"/></a:majorFont><a:minorFont><a:latin typeface="%s"/><a:ea typeface="%s"/><a:font script="Jpan" typeface="MS PGothic"/><a:font script="Hans" typeface="Microsoft YaHei"/><a:font script="Hant" typeface="Microsoft JhengHei"/><a:font script="Hang" typeface="Malgun Gothic"/></a:minorFont></a:fontScheme>`, major, ea, minor, ea)
			}
			th += `</a:themeElements></a:theme>`
			add("xl/theme/theme1.xml", th)
		}
		if i >= 1450 {
			st := `<styleSheet>`
			if i >= 1850 {
				st += `<numFmts><numFmt numFmtId="164" formatCode="0.00;[Red](0.00)"/><numFmt numFmtId="165" formatCode="[Color10]0.00"/><numFmt numFmtId="166" formatCode="[Blue]0%"/></numFmts>`
			}
			if i >= 2000 {
				st += `<fonts><font><name val="Calibri"/><sz val="11"/><color rgb="FF445566"/></font><font><name val="Calibri"/><sz val="11"/><color indexed="10"/></font><font><name val="Calibri"/><sz val="11"/><color rgb="FFD396A7" tint="0.1"/></font><font><name val="Calibri"/><sz val="11"/><color auto="1"/></font>`
				if i >= 2150 {
					st += fmt.Sprintf(`<font><name val="Calibri"/><sz val="11"/><color theme="%d" tint="%g"/></font>`, r.Intn(14), []float64{0, 0.1, -0.25, 0.5}[r.Intn(4)])
				}
				if i >= 3000 {
					if i%2 == 0 {
						st += `<font><name val="Calibri"/><sz val="11"/><b/></font>`
					} else {
						st += `<font><b/></font>`
					}
				}
				if i >= 3600 {
					size := []float64{7, 9, 12.5, 14, 18, 32}[i%6]
					if i >= 4200 {
						size = (float64(5+i%35) + 0.05) * 0.75 / 1.15
						if i%3 == 0 {
							size = math.Nextafter(size, math.Inf(-1))
						}
						if i%3 == 1 {
							size = math.Nextafter(size, math.Inf(1))
						}
					}
					if i >= 3750 && i < 3900 {
						size = 14
					}
					bold := []string{"", "<b/>"}[(i/6)%2]
					st += fmt.Sprintf(`<font><name val="Calibri"/><sz val="%g"/>%s</font>`, size, bold)
					if i >= 3750 {
						other := 14.0000001
						if i >= 4200 {
							other = 11
						}
						st += fmt.Sprintf(`<font><name val="Calibri"/><sz val="%g"/>%s</font>`, other, bold)
					}
				}
				st += `</fonts>`
				if i >= 7200 {
					names := []string{"Calibri", "Arial", "Times New Roman", "Noto Sans", "MS PGothic", "MS Mincho"}
					font := 0
					st = regexp.MustCompile(`<name val="Calibri"/>`).ReplaceAllStringFunc(st, func(string) string {
						name := names[((i-7200)/4+font)%len(names)]
						font++
						return fmt.Sprintf(`<name val="%s"/>`, name)
					})
				}
				if i >= 7400 {
					font := 0
					st = regexp.MustCompile(`</font>`).ReplaceAllStringFunc(st, func(string) string {
						scheme := []string{"major", "minor", "none"}[(i+font)%3]
						font++
						return fmt.Sprintf(`<scheme val="%s"/></font>`, scheme)
					})
				}
				if i >= 7600 {
					font := 0
					st = regexp.MustCompile(`</font>`).ReplaceAllStringFunc(st, func(string) string {
						italic := (i+font)%2 == 0
						font++
						if italic {
							return `<i/></font>`
						}
						return `</font>`
					})
				}
				if i >= 7800 {
					font := 0
					st = regexp.MustCompile(`</font>`).ReplaceAllStringFunc(st, func(string) string {
						decoration := []string{"", `<u/>`, `<u val="double"/>`, `<strike/>`, `<u/><strike/>`}[(i+font)%5]
						font++
						return decoration + `</font>`
					})
				}
				if i >= 8000 {
					font := 0
					st = regexp.MustCompile(`</font>`).ReplaceAllStringFunc(st, func(string) string {
						vert := []string{"superscript", "subscript", "baseline"}[(i+font)%3]
						font++
						return fmt.Sprintf(`<vertAlign val="%s"/></font>`, vert)
					})
				}
				if i >= 9400 {
					st = strings.Replace(st, `<sz val="11"/>`, fmt.Sprintf(`<sz val="%g"/>`, []float64{7, 9, 10, 12, 14, 18, 32}[i%7]), 1)
				}
			}
			if i >= 3300 {
				st += `<fills><fill/><fill><patternFill patternType="solid"><fgColor rgb="FF112233"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor indexed="10"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FF112233"/><bgColor rgb="FF556677"/></patternFill></fill></fills>`
			}
			if i >= 4500 {
				st += `<borders><border/>`
				lines := []string{"thin", "medium", "double", "thick"}
				if i >= 6300 && i < 6500 {
					for j := range lines {
						lines[j] = []string{"thin", "medium", "dotted", "double"}[(i-6300)/50]
					}
				} else if i >= 6100 {
					all := []string{"hair", "dotted", "dashDotDot", "dashDot", "dashed", "mediumDashDotDot", "slantDashDot", "mediumDashDot", "mediumDashed", "thin", "medium", "double", "thick"}
					for j := range lines {
						lines[j] = all[((i-6100)/10+j)%len(all)]
					}
				}
				for j, line := range lines {
					if i >= 5400 {
						color := []string{"00000000", "001F4E79", "00559A17", "00CB1256"}[j]
						st += fmt.Sprintf(`<border><left style="%s"><color rgb="%s"/></left><right style="%s"><color rgb="%s"/></right><top style="%s"><color rgb="%s"/></top><bottom style="%s"><color rgb="%s"/></bottom></border>`, line, color, line, color, line, color, line, color)
					} else {
						st += fmt.Sprintf(`<border><left style="%s"><color rgb="00000000"/></left><right style="%s"/><top style="%s"/><bottom style="%s"/></border>`, line, line, line, line)
					}
				}
				if i >= 6800 {
					up, down, line := "1", "1", "thin"
					if i >= 6900 {
						up = []string{"1", "0", "1"}[i%3]
						down = []string{"0", "1", "1"}[i%3]
						line = []string{"hair", "dotted", "dashDotDot", "dashDot", "dashed", "thin", "mediumDashDotDot", "slantDashDot", "mediumDashDot", "mediumDashed", "medium", "double", "thick"}[(i-6900)/3%13]
					}
					st = strings.ReplaceAll(st, `<border><left`, fmt.Sprintf(`<border diagonalUp="%s" diagonalDown="%s"><left`, up, down))
					st = strings.ReplaceAll(st, `</border>`, fmt.Sprintf(`<diagonal style="%s"><color rgb="00000000"/></diagonal></border>`, line))
				}
				st += `</borders>`
			}
			st += `<cellXfs>`
			if i >= 3150 {
				st += fmt.Sprintf(`<xf numFmtId="0" fontId="5"><alignment horizontal="%s" vertical="%s"/></xf>`, []string{"general", "left", "right", "center"}[i%4], []string{"bottom", "top", "center"}[(i/4)%3])
			} else if i >= 2700 && i < 2850 {
				st += fmt.Sprintf(`<xf numFmtId="0"><alignment horizontal="%s" vertical="%s"/></xf>`, []string{"left", "right"}[i%2], []string{"bottom", "top", "center"}[(i/2)%3])
			} else if i >= 2500 && i < 2600 {
				st += fmt.Sprintf(`<xf numFmtId="0"><alignment horizontal="%s" vertical="%s"/></xf>`, []string{"general", "center"}[i%2], []string{"top", "center"}[(i/2)%2])
			} else if i >= 2450 && i < 2500 {
				st += `<xf numFmtId="0"><alignment horizontal="center"/></xf>`
			} else {
				st += `<xf numFmtId="0"/>`
			}
			ids := []int{1, 2, 3, 4, 9, 10, 11, 14, 20, 22, 46, 49}
			if i >= 1850 {
				ids = append(ids, 164, 165, 166)
			}
			for _, id := range ids {
				font := 0
				if i >= 2000 {
					if i >= 2150 {
						font = r.Intn(5)
					} else {
						font = r.Intn(4)
					}
				}
				st += fmt.Sprintf(`<xf numFmtId="%d" fontId="%d"/>`, id, font)
			}
			if i >= 2350 {
				format := 0
				if i >= 2400 && i < 2450 {
					format = []int{2, 14, 164}[i%3]
				}
				if i >= 5400 {
					for j := 1; j <= 4; j++ {
						wrap := ""
						if i >= 6500 && i < 8200 {
							wrap = ` wrapText="1"`
						} else if i >= 8200 {
							wrap = ` shrinkToFit="1"`
						}
						if i >= 8400 {
							wrap = fmt.Sprintf(` indent="%d"`, 1+i%3)
							if i%3 == 0 {
								wrap += ` wrapText="1"`
							}
							if i%3 == 1 {
								wrap += ` shrinkToFit="1"`
							}
						}
						horizontal := []string{"general", "left", "right", "center"}[(i/4)%4]
						if i >= 8600 {
							horizontal, wrap = "centerContinuous", ""
							if i >= 8800 {
								wrap = []string{` wrapText="1"`, ` shrinkToFit="1"`}[i%2]
							}
						}
						st += fmt.Sprintf(`<xf fontId="%d" fillId="1" borderId="%d" numFmtId="%d"><alignment horizontal="%s" vertical="%s"%s/></xf>`, 6+j%2, j, []int{0, 2, 14, 164}[i%4], horizontal, []string{"bottom", "top", "center"}[(i/16)%3], wrap)
					}
				} else if i >= 5000 {
					for j := 0; j < 2; j++ {
						st += fmt.Sprintf(`<xf fontId="%d" numFmtId="%d"><alignment horizontal="%s" vertical="%s"/></xf>`, 6+j, []int{0, 2, 14, 164}[i%4], []string{"general", "left", "right", "center"}[(i/4)%4], []string{"bottom", "top", "center"}[(i/16)%3])
					}
				} else if i >= 4500 {
					for j := 1; j <= 4; j++ {
						st += fmt.Sprintf(`<xf fontId="%d" fillId="1" borderId="%d" numFmtId="%d"><alignment horizontal="%s" vertical="%s"/></xf>`, 6+j%2, j, []int{0, 2, 14, 164}[i%4], []string{"general", "left", "right", "center"}[(i/4)%4], []string{"bottom", "top", "center"}[(i/16)%3])
					}
				} else if i >= 3600 {
					st += fmt.Sprintf(`<xf fontId="6" fillId="1" numFmtId="%d"><alignment horizontal="%s" vertical="%s"/></xf>`, []int{0, 2, 14, 164}[i%4], []string{"general", "left", "right", "center"}[(i/4)%4], []string{"bottom", "top", "center"}[(i/16)%3])
					if i >= 3750 {
						st += fmt.Sprintf(`<xf fontId="7" fillId="1" numFmtId="%d"><alignment horizontal="%s" vertical="%s"/></xf>`, []int{0, 2, 14, 164}[i%4], []string{"general", "left", "right", "center"}[(i/4)%4], []string{"bottom", "top", "center"}[(i/16)%3])
					}
				} else if i >= 3300 {
					st += `<xf fontId="5" fillId="1"/><xf fontId="5" fillId="2"/><xf fontId="5" fillId="3"/>`
				} else if i >= 3000 {
					format = []int{0, 2, 14, 164}[i%4]
					st += fmt.Sprintf(`<xf numFmtId="%d" fontId="5"><alignment horizontal="%s" vertical="%s"/></xf>`, format, []string{"general", "left", "right", "center"}[i%4], []string{"bottom", "top", "center"}[(i/4)%3])
				} else if i >= 2850 {
					format = []int{0, 2, 14, 164}[i%4]
					st += fmt.Sprintf(`<xf numFmtId="%d"><alignment horizontal="%s" vertical="%s"/></xf>`, format, []string{"left", "right"}[i%2], []string{"bottom", "top", "center"}[(i/2)%3])
				} else if i >= 2600 {
					format = []int{0, 2, 14, 164}[i%4]
					st += fmt.Sprintf(`<xf numFmtId="%d"><alignment horizontal="%s" vertical="%s"/></xf>`, format, []string{"general", "center"}[i%2], []string{"top", "center"}[(i/2)%2])
				} else {
					st += fmt.Sprintf(`<xf numFmtId="%d"><alignment horizontal="center"/></xf>`, format)
				}
			}
			st += `</cellXfs>`
			if i >= 1850 {
				st += `<colors><indexedColors>`
				for j := 0; j < 20; j++ {
					st += fmt.Sprintf(`<rgbColor rgb="FF%06X"/>`, r.Intn(1<<24))
				}
				st += `</indexedColors></colors>`
			}
			st += `</styleSheet>`
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
				if i >= 3900 {
					if r.Intn(2) == 0 {
						attrs = fmt.Sprintf(` ht="%d" customHeight="1"`, 5+r.Intn(70))
					}
				} else if i >= 3600 {
					attrs = fmt.Sprintf(` ht="%d" customHeight="1"`, 5+r.Intn(70))
				} else if r.Intn(3) == 0 {
					attrs = fmt.Sprintf(` ht="%d" customHeight="1"`, 5+r.Intn(40))
				}
				if r.Intn(5) == 0 {
					attrs += ` hidden="1"`
				}
			}
			if i >= 6500 && i < 6600 {
				attrs = fmt.Sprintf(` ht="%d" customHeight="1"`, 15+r.Intn(60))
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
							sheet += fmt.Sprintf(`<c r="%s%d" s="%d"><v>%s</v></c>`, col, y+1, 1+r.Intn(func() int {
								if i >= 1850 {
									return 15
								}
								return 12
							}()), v)
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
		if i >= 3300 {
			sheet = strings.Replace(sheet, `</row>`, `<c r="E1"/><c r="F1"/></row>`, 1)
		}
		if i >= 2350 {
			style := 16
			if (i >= 2450 && i < 2600) || (i >= 2700 && i < 2850) || (i >= 3150 && i < 3300) {
				style = 0
			}
			cellRE := regexp.MustCompile(`<c r="([^"]+)"(?: s="[0-9]+")?`)
			if i >= 5400 {
				sheet = cellRE.ReplaceAllStringFunc(sheet, func(match string) string {
					return fmt.Sprintf(`<c r="%s" s="%d"`, cellRE.FindStringSubmatch(match)[1], 16+r.Intn(4))
				})
			} else if i >= 5000 {
				sheet = cellRE.ReplaceAllStringFunc(sheet, func(match string) string {
					return fmt.Sprintf(`<c r="%s" s="%d"`, cellRE.FindStringSubmatch(match)[1], 16+r.Intn(2))
				})
			} else if i >= 4500 {
				sheet = cellRE.ReplaceAllStringFunc(sheet, func(match string) string {
					return fmt.Sprintf(`<c r="%s" s="%d"`, cellRE.FindStringSubmatch(match)[1], 16+r.Intn(4))
				})
			} else if i >= 3750 {
				sheet = cellRE.ReplaceAllStringFunc(sheet, func(match string) string {
					return fmt.Sprintf(`<c r="%s" s="%d"`, cellRE.FindStringSubmatch(match)[1], 16+r.Intn(2))
				})
			} else if i >= 3300 && i < 3600 {
				sheet = cellRE.ReplaceAllStringFunc(sheet, func(match string) string {
					return fmt.Sprintf(`<c r="%s" s="%d"`, cellRE.FindStringSubmatch(match)[1], 16+r.Intn(3))
				})
			} else {
				sheet = cellRE.ReplaceAllString(sheet, fmt.Sprintf(`<c r="$1" s="%d"`, style))
			}
		}
		if i >= 4800 {
			sheet = strings.Replace(sheet, `</row>`, `<c r="G1" s="16"><f>1+2</f></c><c r="H1" s="17" t="str"><f>"x"</f><v/></c><c r="I1" s="18"><f>3+4</f><v>7</v></c></row>`, 1)
		}
		if i >= 9200 {
			sheet = strings.Replace(sheet, `</worksheet>`, `<mergeCells count="2"><mergeCell ref="A1:C1"/><mergeCell ref="E2:F2"/></mergeCells></worksheet>`, 1)
		} else if (i >= 5700 && i < 8600) || i >= 9000 {
			sheet = strings.Replace(sheet, `</worksheet>`, `<mergeCells count="2"><mergeCell ref="A1:C2"/><mergeCell ref="E3:F4"/></mergeCells></worksheet>`, 1)
		} else if i >= 5000 && i < 5400 {
			sheet = strings.Replace(sheet, `</worksheet>`, `<mergeCells count="2"><mergeCell ref="A1:C1"/><mergeCell ref="E2:F2"/></mergeCells></worksheet>`, 1)
		}
		add("xl/worksheets/sheet1.xml", sheet)
		for j := 2; j <= count; j++ {
			extra := fmt.Sprintf(`<row r="%d"><c r="A%d" t="str"><v>Sheet %d</v></c></row>`, 5+j, 5+j, j)
			add(fmt.Sprintf("xl/worksheets/sheet%d.xml", j), strings.Replace(sheet, "</sheetData>", extra+"</sheetData>", 1))
		}
		if e := z.Close(); e != nil {
			t.Fatal(e)
		}
		if i == 3600 {
			// Keep a real package with nondefault sizes on auto-height rows.
			reader, e := zip.NewReader(bytes.NewReader(b.Bytes()), int64(b.Len()))
			if e != nil {
				t.Fatal(e)
			}
			var rejected bytes.Buffer
			writer := zip.NewWriter(&rejected)
			for _, file := range reader.File {
				input, e := file.Open()
				if e != nil {
					t.Fatal(e)
				}
				data, e := io.ReadAll(input)
				input.Close()
				if e != nil {
					t.Fatal(e)
				}
				if strings.HasPrefix(file.Name, "xl/worksheets/sheet") && strings.HasSuffix(file.Name, ".xml") {
					data = regexp.MustCompile(` ht="[^"]*" customHeight="1"`).ReplaceAll(data, nil)
				}
				output, e := writer.Create(file.Name)
				if e != nil {
					t.Fatal(e)
				}
				if _, e = output.Write(data); e != nil {
					t.Fatal(e)
				}
			}
			if e = writer.Close(); e != nil {
				t.Fatal(e)
			}
			data, e := json.Marshal(rejected.Bytes())
			if e != nil {
				t.Fatal(e)
			}
			if e = os.WriteFile(filepath.Join(root, "compat/xlsx/auto-height.json"), data, 0644); e != nil {
				t.Fatal(e)
			}
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
	// Exercise an upstream workbook with real styles, borders and uncached formulas.
	actual, e := os.ReadFile(filepath.Join("testdata", "form-pages.xlsx"))
	if e != nil {
		t.Fatal(e)
	}
	converted, e := Convert(bytes.NewReader(actual), int64(len(actual)), &Options{NoSystemFonts: true, SystemFonts: true, NoTextIndex: true, Data: "none"})
	if e != nil {
		t.Fatal(e)
	}
	var actualBDF bytes.Buffer
	if e = converted.Doc.WriteSingle(&actualBDF); e != nil {
		t.Fatal(e)
	}
	out = append(out, map[string]any{"input": actual, "bdf": actualBDF.Bytes(), "warnings": converted.Warnings, "mode": "none", "no_index": true})
	printed, e := os.ReadFile(filepath.Join("testdata", "print.xlsx"))
	if e != nil {
		t.Fatal(e)
	}
	printResult, e := Convert(bytes.NewReader(printed), int64(len(printed)), &Options{NoSystemFonts: true, SystemFonts: true, NoTextIndex: true, Data: "none"})
	if e != nil {
		t.Fatal(e)
	}
	var printBDF bytes.Buffer
	if e = printResult.Doc.WriteSingle(&printBDF); e != nil {
		t.Fatal(e)
	}
	out = append(out, map[string]any{"input": printed, "bdf": printBDF.Bytes(), "warnings": printResult.Warnings, "mode": "none", "no_index": true})
	fixed, e := os.ReadFile(filepath.Join("testdata", "form-fixed.xlsx"))
	if e != nil {
		t.Fatal(e)
	}
	fixedResult, e := Convert(bytes.NewReader(fixed), int64(len(fixed)), &Options{NoSystemFonts: true, SystemFonts: true, NoTextIndex: true, Data: "none"})
	if e != nil {
		t.Fatal(e)
	}
	var fixedBDF bytes.Buffer
	if e = fixedResult.Doc.WriteSingle(&fixedBDF); e != nil {
		t.Fatal(e)
	}
	out = append(out, map[string]any{"input": fixed, "bdf": fixedBDF.Bytes(), "warnings": fixedResult.Warnings, "mode": "none", "no_index": true})
	dir := filepath.Join(root, "compat/xlsx/render")
	if e = os.MkdirAll(dir, 0755); e != nil {
		t.Fatal(e)
	}
	files := []string{}
	for start := 0; start < len(out); start += 1000 {
		end := min(start+1000, len(out))
		name := fmt.Sprintf("%03d.json", start/1000)
		data, err := json.Marshal(out[start:end])
		if err != nil {
			t.Fatal(err)
		}
		if err = os.WriteFile(filepath.Join(dir, name), data, 0644); err != nil {
			t.Fatal(err)
		}
		files = append(files, name)
	}
	index, e := json.Marshal(map[string]any{"count": len(out), "files": files})
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(dir, "index.json"), index, 0644); e != nil {
		t.Fatal(e)
	}
}
