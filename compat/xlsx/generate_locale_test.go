//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexXLSXLocale.
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

func TestCodexXLSXLocale(t *testing.T) {
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
	r := rand.New(rand.NewSource(52317))
	fonts := []string{"Calibri", "游ゴシック", "MS Gothic Bold", "Meiryo UI", "SimSun", "Microsoft YaHei", "맑은 고딕", "Malgun Gothic", "新細明體", "Microsoft JhengHei", "NoThemeFont"}
	langs := []string{"", "en-US", "ja-JP", "JA-jp", "zh-CN", "zh-TW", "zh-HK", "ko-KR", "fr-FR", "foo"}
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
		add("xl/_rels/workbook.xml.rels", `<Relationships><Relationship Id="r1" Type="x/styles" Target="styles.xml"/><Relationship Id="r2" Type="x/theme" Target="theme/theme1.xml"/></Relationships>`)
		font := fonts[r.Intn(len(fonts))]
		add("xl/styles.xml", fmt.Sprintf(`<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts><font><name val="%s"/></font></fonts></styleSheet>`, font))
		ea := ""
		if r.Intn(4) == 0 {
			ea = `<ea typeface="Other"/>`
		}
		jpan := "NoThemeFont"
		if r.Intn(2) == 0 {
			jpan = font
		}
		add("xl/theme/theme1.xml", fmt.Sprintf(`<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:themeElements><a:fontScheme><a:minorFont>%s<font script="Jpan" typeface="%s"/></a:minorFont></a:fontScheme></a:themeElements></a:theme>`, ea, jpan))
		if i%7 != 0 {
			add("_rels/.rels", `<Relationships><Relationship Id="r1" Type="x/core-properties" Target="docProps/core.xml"/></Relationships>`)
			lang := langs[r.Intn(len(langs))]
			props := fmt.Sprintf(`<coreProperties><title>  A %d </title><keywords> apple、banana ; cherry </keywords><subject> Subjects </subject><language> %s </language><creator>A</creator><creator> B </creator><description> one <x>hidden</x> two </description><identifier>Id</identifier><created>2020</created><modified>2024</modified></coreProperties>`, i, lang)
			if i%5 == 0 {
				props = fmt.Sprintf(`<coreProperties><keywords/><keywords>ignored</keywords><language>   %s  </language><subject> one </subject><subject>two</subject><title> before<x>invisible</x>after </title></coreProperties>`, lang)
			}
			if i%5 == 1 {
				props = fmt.Sprintf(`<coreProperties><keywords>alpha; beta,, gamma</keywords><subject>one</subject><keywords>ignored</keywords><language></language><language>%s</language><title> </title><title>two</title></coreProperties>`, lang)
			}
			add("docProps/core.xml", props)
		}
		if e := z.Close(); e != nil {
			t.Fatal(e)
		}
		samples = append(samples, b.Bytes())
	}
	out := []any{}
	for _, b := range samples {
		c, _, e := openWorkbook(bytes.NewReader(b), int64(len(b)), &Options{NoSystemFonts: true, SystemFonts: true})
		if e != nil {
			t.Fatal(e)
		}
		dc := c.doc.Meta.DC
		array := func(v []string) []string {
			if v == nil {
				return []string{}
			}
			return v
		}
		out = append(out, map[string]any{"input": b, "want": []any{array(dc.Title), array(dc.Creator), array(dc.Subject), array(dc.Description), array(dc.Identifier), array(dc.Language), array(dc.Created), array(dc.Modified), c.eaScript, c.eaLang, c.locale}})
	}
	b, e := json.Marshal(out)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/locale.json"), b, 0644); e != nil {
		t.Fatal(e)
	}
}
