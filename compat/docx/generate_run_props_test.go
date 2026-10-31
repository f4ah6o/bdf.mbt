//go:build ignore

// Copy without the build tag into upstream converter/internal/wordproc.
// Set BDF_REFERENCE_OUTPUT and BDF_DOCX_FIXTURES, then run TestCodexDOCXRunProps.
package wordproc

import (
	"archive/zip"
	"encoding/xml"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/shibukawa/bdf/converter/internal/ooxml"
)

func codexRunXML(n *ooxml.Node) string {
	var b strings.Builder
	var emit func(*ooxml.Node)
	emit = func(x *ooxml.Node) {
		fmt.Fprintf(&b, "<%s", x.Name)
		for _, a := range x.Attrs {
			if strings.HasSuffix(a.Name.Space, "relationships") || a.Name.Space == "xmlns" || a.Name.Local == "xmlns" {
				continue
			}
			fmt.Fprintf(&b, " %s=\"", a.Name.Local)
			_ = xml.EscapeText(&b, []byte(a.Value))
			b.WriteByte('"')
		}
		b.WriteByte('>')
		for _, k := range x.Elements() {
			emit(k)
		}
		fmt.Fprintf(&b, "</%s>", x.Name)
	}
	emit(n)
	return b.String()
}

func codexRunSupported(n *ooxml.Node) bool {
	for _, c := range n.Elements() {
		if len(c.Elements()) != 0 {
			return false
		}
		switch c.Name {
		case "b", "i", "caps", "smallCaps", "strike", "dstrike", "vanish", "outline", "shadow", "emboss", "imprint", "rFonts", "sz", "highlight", "vertAlign", "position", "spacing", "w", "em", "lang", "webHidden", "rtl":
		case "u":
			for _, attr := range []string{"color", "themeColor", "themeTint", "themeShade"} {
				if _, ok := c.Attr(attr); ok {
					return false
				}
			}
		case "eastAsianLayout":
			if c.AttrBool("combine", false) {
				return false
			}
		default:
			return false
		}
	}
	return true
}

func codexEmitRun(t *testing.T, out io.Writer, id int, layers []string) {
	t.Helper()
	r := defaultRProps()
	c := &converter{opts: &Options{}, warned: map[string]bool{}}
	for _, layer := range layers {
		node, err := ooxml.Parse([]byte(layer))
		if err != nil {
			t.Fatal(err)
		}
		c.applyRPr(r, node)
	}
	fmt.Fprintf(out, "///|\ntest \"DOCX run properties match upstream Go %d\" {\n check_docx_run_props([", id)
	for _, layer := range layers {
		fmt.Fprintf(out, "%q,", layer)
	}
	fmt.Fprintf(out, "], {fonts:[%q,%q,%q,%q],themes:[%q,%q,%q,%q],hint:%q,toggles:%d,specified:%d,\n", r.fonts[0], r.fonts[1], r.fonts[2], r.fonts[3], r.themes[0], r.themes[1], r.themes[2], r.themes[3], r.hint, r.toggles, r.set)
	fmt.Fprintf(out, "size:%#.17g,color:%dU,auto_color:%t,shading:%dU,has_shading:%t,underline_color:%dU,has_underline_color:%t,\n", r.sz, r.color, r.autoColor, r.shd, r.hasShd, r.uColor, r.hasUColor)
	fmt.Fprintf(out, "highlight:%q,underline:%q,vertical_align:%q,position:%#.17g,spacing:%#.17g,scale:%#.17g,emphasis:%q,\n", r.highlight, r.u, r.vertAlign, r.position, r.spacing, r.scale, r.em)
	fmt.Fprintf(out, "languages:[%q,%q,%q],web_hidden:%t,rtl:%t,tcy:%t,tcy_fit:%t,})\n}\n", r.lang[0], r.lang[1], r.lang[2], r.webHidden, r.rtl, r.tcy, r.tcyFit)
}

func TestCodexDOCXRunProps(t *testing.T) {
	dest, dir := os.Getenv("BDF_REFERENCE_OUTPUT"), os.Getenv("BDF_DOCX_FIXTURES")
	if dest == "" || dir == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT and BDF_DOCX_FIXTURES required")
	}
	out, err := os.Create(dest)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	cases := [][]string{
		{`<rPr/>`},
		{`<rPr><b/><i val="false"/><caps val="on"/><smallCaps/><strike val="0"/><dstrike/><vanish val="off"/><outline/><shadow/><emboss/><imprint/></rPr>`},
		{`<rPr><rFonts ascii="Alpha" hAnsi="Beta" eastAsia="Gamma" cs="Delta" hint="eastAsia" asciiTheme="majorAscii" hAnsiTheme="minorHAnsi" eastAsiaTheme="minorEastAsia" cstheme="majorBidi"/><sz val="22"/><position val="3"/><spacing val="40"/><w val="85"/><vertAlign val="superscript"/><u/><highlight val="yellow"/><em val="dot"/><lang val="en-US" eastAsia="ja-JP" bidi="ar-SA"/><rtl/><webHidden/><eastAsianLayout vert="1" vertCompress="true"/></rPr>`},
		{`<rPr><b/><i/><sz val="20"/><rFonts asciiTheme="minorAscii" hAnsiTheme="minorHAnsi"/><lang val="en"/><w val="120"/></rPr>`, `<rPr><b val="0"/><i val="garbage"/><sz val="0"/><rFonts ascii="Local" eastAsia="日本語" hAnsi=""/><lang eastAsia="ja"/><w val="0"/><position val="-5"/></rPr>`},
		{`<rPr><sz val="bad"/><w val="bad"/><spacing val="2cm"/><u val="double"/><eastAsianLayout vert="bad" vertCompress="on" combine="false"/></rPr>`, `<rPr><spacing val="garbage"/><u val="none"/><lang bidi="he-IL"/><webHidden val="off"/></rPr>`},
	}
	for _, name := range []string{"basic.docx", "form-fixed.docx", "form-pages.docx", "form-rows.docx", "grid.docx", "math.docx", "styles.docx", "vertical.docx"} {
		z, err := zip.OpenReader(filepath.Join(dir, name))
		if err != nil {
			t.Fatal(err)
		}
		for _, f := range z.File {
			if f.Name != "word/document.xml" && f.Name != "word/styles.xml" {
				continue
			}
			r, err := f.Open()
			if err != nil {
				t.Fatal(err)
			}
			data, err := io.ReadAll(r)
			_ = r.Close()
			if err != nil {
				t.Fatal(err)
			}
			root, err := ooxml.Parse(data)
			if err != nil {
				t.Fatal(err)
			}
			var walk func(*ooxml.Node)
			walk = func(n *ooxml.Node) {
				if n.Name == "rPr" && codexRunSupported(n) {
					cases = append(cases, []string{codexRunXML(n)})
				}
				for _, child := range n.Elements() {
					walk(child)
				}
			}
			walk(root)
		}
		_ = z.Close()
	}
	for i, layers := range cases {
		codexEmitRun(t, out, i, layers)
	}
	t.Logf("%d run property fixtures", len(cases))
}
