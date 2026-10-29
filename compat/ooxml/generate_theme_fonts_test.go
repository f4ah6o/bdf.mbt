//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexThemeFonts.
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

func TestCodexThemeFonts(t *testing.T) {
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
	r := rand.New(rand.NewSource(312113))
	parts := []string{`<latin typeface="Aptos"/>`, `<latin typeface=""/>`, `<latin/>`, `<ea typeface="游ゴシック"/>`, `<ea typeface=""/>`, `<cs typeface="Noto Sans Arabic"/>`, `<font script="Jpan" typeface="ＭＳ 明朝"/>`, `<font script="Hans" typeface="SimSun"/>`, `<font script="Jpan" typeface="Other"/>`, `<font/>`, `<font script="Hang" typeface=""/>`}
	for i := 0; i < 1000; i++ {
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
		add("xl/workbook.xml", `<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"/>`)
		if i%10 != 0 {
			add("xl/_rels/workbook.xml.rels", `<Relationships><Relationship Id="rId1" Type="x/theme" Target="theme/theme1.xml"/></Relationships>`)
			theme := `<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:themeElements><a:fontScheme>`
			for _, typ := range []string{"majorFont", "minorFont"} {
				if r.Intn(5) == 0 {
					continue
				}
				theme += fmt.Sprintf("<a:%s>", typ)
				for j := 0; j < r.Intn(8); j++ {
					theme += parts[r.Intn(len(parts))]
				}
				theme += fmt.Sprintf("</a:%s>", typ)
			}
			theme += `</a:fontScheme></a:themeElements></a:theme>`
			add("xl/theme/theme1.xml", theme)
		}
		if e := z.Close(); e != nil {
			t.Fatal(e)
		}
		samples = append(samples, b.Bytes())
	}
	refs := []string{"+mj-lt", "+mn-lt", "+mj-ea", "+mn-ea", "+mj-cs", "+mn-cs", "+xx-ea", "+mj-x", "regular", "+", "+😀-ea"}
	scripts := []string{"", "Jpan", "Hans", "Hang", "Arab"}
	out := []any{}
	for _, b := range samples {
		c, _, e := openWorkbook(bytes.NewReader(b), int64(len(b)), &Options{NoSystemFonts: true, SystemFonts: true})
		if e != nil {
			t.Fatal(e)
		}
		values := []any{}
		for _, ref := range refs {
			for _, script := range scripts {
				values = append(values, c.d.ThemeFont(ref, script))
			}
		}
		out = append(out, map[string]any{"input": b, "want": values})
	}
	b, e := json.Marshal(out)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/ooxml/theme-fonts.json"), b, 0644); e != nil {
		t.Fatal(e)
	}
}
