package xlsx

// Copy this file into the upstream converter/xlsx package and set
// BDF_SHEET_STYLES to generate the resolved built-in grid style definitions.
import (
	"encoding/json"
	"fmt"
	"os"
	"sort"
	"strings"
	"testing"
)

type styleBorderFixture struct {
	Style string `json:"style"`
	Color uint32 `json:"color"`
}

type styleRegionFixture struct {
	Fill      uint32                `json:"fill"`
	FontColor uint32                `json:"fontColor"`
	Bold      *bool                 `json:"bold"`
	Size      int                   `json:"size"`
	Borders   [6]styleBorderFixture `json:"borders"`
}

func TestGenerateGridStyleDefinitions(t *testing.T) {
	path := os.Getenv("BDF_SHEET_STYLES")
	if path == "" {
		t.Skip("fixture output not requested")
	}
	c := newConverter(nil, &Options{NoSystemFonts: true})
	c.st = loadStyles(c, nil, defaultThemeColor)
	s := &sheetCtx{c: c}
	builtinTableStyle("")
	names := make([]string, 0, len(builtinStyles))
	for name := range builtinStyles {
		names = append(names, name)
	}
	sort.Strings(names)
	out := make(map[string]map[string]styleRegionFixture)
	for _, name := range names {
		table := &table{elems: map[string]styleElem{}}
		s.tableStyle(table, name)
		regions := make(map[string]styleRegionFixture)
		for _, region := range []string{"wholeTable", "firstRowStripe", "secondRowStripe", "headerRow"} {
			element, ok := table.elems[region]
			if !ok {
				continue
			}
			d := element.d
			r := styleRegionFixture{Size: element.size}
			if d.fill != nil && !d.fill.empty() {
				if d.fill.pattern != "solid" {
					t.Fatalf("unexpected pattern %s", d.fill.pattern)
				}
				r.Fill = uint32(c.st.color(d.fill.fg, black).bdf())
			}
			if d.font != nil {
				r.Bold = d.font.bold
				if d.font.color.kind != colorNone {
					r.FontColor = uint32(c.st.color(d.font.color, black).bdf())
				}
			}
			if d.border != nil {
				sides := []borderSide{d.border.top, d.border.bottom, d.border.left, d.border.right, d.border.horizontal, d.border.vertical}
				for i, side := range sides {
					if side.style != "" {
						r.Borders[i] = styleBorderFixture{side.style, uint32(c.st.color(side.color, black).bdf())}
					}
				}
			}
			regions[region] = r
		}
		out[name] = regions
	}
	f, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	if err := json.NewEncoder(f).Encode(out); err != nil {
		t.Fatal(err)
	}
}

func TestGenerateGridStyleCells(t *testing.T) {
	path := os.Getenv("BDF_SHEET_STYLE_CELLS")
	if path == "" {
		t.Skip("fixture output not requested")
	}
	c := newConverter(nil, &Options{NoSystemFonts: true})
	c.st = loadStyles(c, nil, defaultThemeColor)
	s := &sheetCtx{c: c}
	builtinTableStyle("")
	names := make([]string, 0, len(builtinStyles))
	for name := range builtinStyles {
		names = append(names, name)
	}
	sort.Strings(names)
	out := make(map[string]string)
	for _, name := range names {
		var str strings.Builder
		for header := 0; header <= 2; header++ {
			table := &table{ref: cellRange{0, 0, 4, 2}, header: header, elems: map[string]styleElem{}, rowStripes: true}
			s.tableStyle(table, name)
			for r := 0; r < 5; r++ {
				for col := 0; col < 3; col++ {
					f := &cellFmt{}
					table.apply(s, f, r, col)
					fill := uint32(0)
					if !f.fill.empty() {
						fill = uint32(c.st.color(f.fill.fg, black).bdf())
					}
					fmt.Fprintf(&str, "%d,%d,%t", fill, uint32(c.st.color(f.font.color, black).bdf()), f.font.bold)
					for _, b := range []borderSide{f.border.top, f.border.bottom, f.border.left, f.border.right} {
						fmt.Fprintf(&str, ",%d:%d", borderStyles[b.style].weight, func() uint32 {
							if b.style == "" {
								return 0
							}
							return uint32(c.st.color(b.color, black).bdf())
						}())
					}
					str.WriteByte(';')
				}
			}
		}
		out[name] = str.String()
	}
	f, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	if err := json.NewEncoder(f).Encode(out); err != nil {
		t.Fatal(err)
	}
}
