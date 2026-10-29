//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexXLSXPaint.
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

func TestCodexXLSXPaint(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	samples := [][]byte{}
	for _, name := range []string{"basic.xlsx", "features.xlsx", "form-fixed.xlsx", "form-pages.xlsx", "form-rows.xlsx", "math.xlsx", "print.xlsx"} {
		b, e := os.ReadFile(filepath.Join("testdata", name))
		if e != nil {
			t.Fatal(e)
		}
		samples = append(samples, b)
	}
	r := rand.New(rand.NewSource(201911))
	colors := []string{`<color rgb="FF123456"/>`, `<color indexed="9"/>`, `<color theme="4" tint="0.5"/>`, `<color auto="1"/>`, `<color rgb="bad"/>`, ``}
	fills := []string{`<fill/>`, `<fill><patternFill patternType="none"/></fill>`, `<fill><patternFill patternType="solid"><fgColor rgb="FF112233"/><bgColor indexed="4"/></patternFill></fill>`, `<fill><patternFill patternType="gray125"/></fill>`, `<fill><gradientFill type="path" degree="45" left="0.25" right="0.4"><stop position="0"><color rgb="FF123456"/></stop><stop position="1"><color theme="2" tint="-0.25"/></stop></gradientFill></fill>`, `<fill><gradientFill degree="20"/></fill>`, `<fill><patternFill/><patternFill patternType="solid"/></fill>`, `<fill><gradientFill><stop position="0.2"/></gradientFill></fill>`}
	sides := []string{"left", "right", "start", "end", "top", "bottom", "diagonal", "vertical", "horizontal"}
	styles := []string{"none", "thin", "medium", "double", "dashed", "hair", ""}
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
		add("xl/_rels/workbook.xml.rels", `<Relationships><Relationship Id="rId1" Type="x/styles" Target="styles.xml"/></Relationships>`)
		s := `<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fills>`
		for j := 0; j < r.Intn(8); j++ {
			s += fills[r.Intn(len(fills))]
		}
		s += `</fills><borders>`
		for j := 0; j < r.Intn(7); j++ {
			s += fmt.Sprintf(`<border diagonalUp="%d" diagonalDown="%d">`, r.Intn(2), r.Intn(2))
			for k := 0; k < r.Intn(14); k++ {
				name := sides[r.Intn(len(sides))]
				s += fmt.Sprintf(`<%s style="%s">%s</%s>`, name, styles[r.Intn(len(styles))], colors[r.Intn(len(colors))], name)
			}
			s += `</border>`
		}
		s += `</borders></styleSheet>`
		add("xl/styles.xml", s)
		if e := z.Close(); e != nil {
			t.Fatal(e)
		}
		samples = append(samples, b.Bytes())
	}
	color := func(c colorRef) any {
		return []any{int(c.kind), int(math.Round(c.rgb.R*255))<<16 | int(math.Round(c.rgb.G*255))<<8 | int(math.Round(c.rgb.B*255)), c.idx, c.tint}
	}
	side := func(s borderSide) any { return []any{s.style, color(s.color)} }
	out := []any{}
	for _, b := range samples {
		c, _, e := openWorkbook(bytes.NewReader(b), int64(len(b)), &Options{NoSystemFonts: true, SystemFonts: true})
		if e != nil {
			t.Fatal(e)
		}
		fs := []any{}
		for _, f := range c.st.fills {
			var g any
			if f.grad != nil {
				stops := []any{}
				for _, s := range f.grad.stops {
					stops = append(stops, []any{s.pos, color(s.color)})
				}
				g = []any{f.grad.path, f.grad.degree, f.grad.left, f.grad.right, f.grad.top, f.grad.bottom, stops}
			}
			fs = append(fs, []any{f.pattern, color(f.fg), color(f.bg), g})
		}
		bs := []any{}
		for _, v := range c.st.borders {
			bs = append(bs, []any{side(v.left), side(v.right), side(v.top), side(v.bottom), side(v.diag), v.diagUp, v.diagDown, side(v.vertical), side(v.horizontal)})
		}
		out = append(out, map[string]any{"input": b, "want": []any{fs, bs}})
	}
	b, e := json.Marshal(out)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/paint.json"), b, 0644); e != nil {
		t.Fatal(e)
	}
}
