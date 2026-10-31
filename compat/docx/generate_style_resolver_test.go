//go:build ignore

// Copy without the build tag into upstream converter/internal/wordproc.
// Set BDF_REFERENCE_OUTPUT, then run TestCodexDOCXStyleResolver.
package wordproc

import (
	"archive/zip"
	"bytes"
	"fmt"
	"io"
	"os"
	"strings"
	"testing"

	"github.com/shibukawa/bdf/converter/internal/ooxml"
)

type codexStyleCase struct{ styles, ppr, rpr string }

func codexStylesPackage(t *testing.T, styles string) *ooxml.Package {
	t.Helper()
	var b bytes.Buffer
	z := zip.NewWriter(&b)
	add := func(name, value string) {
		f, e := z.Create(name)
		if e != nil {
			t.Fatal(e)
		}
		if _, e = f.Write([]byte(value)); e != nil {
			t.Fatal(e)
		}
	}
	add("word/_rels/document.xml.rels", `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="styles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>`)
	add("word/styles.xml", styles)
	if e := z.Close(); e != nil {
		t.Fatal(e)
	}
	p, e := ooxml.Open(bytes.NewReader(b.Bytes()), int64(b.Len()))
	if e != nil {
		t.Fatal(e)
	}
	return p
}

func codexStyleNode(t *testing.T, text string) *ooxml.Node {
	t.Helper()
	if text == "" {
		return nil
	}
	n, e := ooxml.Parse([]byte(text))
	if e != nil {
		t.Fatal(e)
	}
	return n
}

func codexEmitStyle(t *testing.T, out io.Writer, id int, tc codexStyleCase) {
	t.Helper()
	c := &converter{opts: &Options{}, warned: map[string]bool{}, pkg: codexStylesPackage(t, tc.styles), main: "word/document.xml"}
	c.loadStyles()
	c.loadNumbering()
	directP, directR := codexStyleNode(t, tc.ppr), codexStyleNode(t, tc.rpr)
	pStyle := c.st.paraStyle(val(directP.Child("pStyle")))
	p := c.paraProps(pStyle, nil, directP)
	r := c.runProps(pStyle, val(directR.Child("rStyle")), nil, directR)
	fmt.Fprintf(out, "///|\ntest \"DOCX style resolver matches upstream Go %d\" {\n check_docx_style(%q,%q,%q,%q,\n", id, tc.styles, tc.ppr, tc.rpr, pStyle)
	fmt.Fprintf(out, "(%q,%#.17g,%#.17g,%#.17g,%#.17g,%#.17g,%#.17g,%q,%t,%t,%d,[", p.jc, p.indL, p.indR, p.indFirst, p.before, p.after, p.line, p.lineRule, p.keepNext, p.snapToGrid, p.outline)
	for _, tab := range p.tabs {
		fmt.Fprintf(out, "(%#.17g,%q,%q),", tab.pos, tab.align, tab.leader)
	}
	fmt.Fprintln(out, "]),")
	fmt.Fprintf(out, "{fonts:[%q,%q,%q,%q],themes:[%q,%q,%q,%q],hint:%q,toggles:%d,specified:%d,\n", r.fonts[0], r.fonts[1], r.fonts[2], r.fonts[3], r.themes[0], r.themes[1], r.themes[2], r.themes[3], r.hint, r.toggles, r.set)
	fmt.Fprintf(out, "size:%#.17g,color:%dU,auto_color:%t,shading:%dU,has_shading:%t,underline_color:%dU,has_underline_color:%t,\n", r.sz, r.color, r.autoColor, r.shd, r.hasShd, r.uColor, r.hasUColor)
	fmt.Fprintf(out, "highlight:%q,underline:%q,vertical_align:%q,position:%#.17g,spacing:%#.17g,scale:%#.17g,emphasis:%q,\n", r.highlight, r.u, r.vertAlign, r.position, r.spacing, r.scale, r.em)
	fmt.Fprintf(out, "languages:[%q,%q,%q],web_hidden:%t,rtl:%t,tcy:%t,tcy_fit:%t,})\n}\n", r.lang[0], r.lang[1], r.lang[2], r.webHidden, r.rtl, r.tcy, r.tcyFit)
}

func TestCodexDOCXStyleResolver(t *testing.T) {
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dest == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(dest)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	fixtures := []codexStyleCase{
		{`<styles/>`, `<pPr/>`, `<rPr/>`},
		{`<styles><docDefaults><pPrDefault><pPr><jc val="right"/><spacing before="400"/></pPr></pPrDefault><rPrDefault><rPr><rFonts asciiTheme="minorAscii"/><sz val="24"/><lang val="en-US"/><b/></rPr></rPrDefault></docDefaults><style styleId="base" type="paragraph"><pPr><ind left="300"/><jc val="center"/></pPr><rPr><i/><sz val="30"/></rPr></style><style styleId="p" type="paragraph" default="1"><basedOn val="base"/><pPr><spacing after="120"/></pPr><rPr><b val="0"/></rPr></style><style styleId="cbase" type="character"><rPr><b/><rFonts ascii="Styled"/></rPr></style><style styleId="c" type="character" default="1"><basedOn val="cbase"/><rPr><i/><lang eastAsia="ja-JP"/></rPr></style></styles>`, `<pPr><pStyle val="unknown"/><jc val="both"/><ind hanging="240"/></pPr>`, `<rPr><b/><sz val="18"/></rPr>`},
		{`<styles><style styleId="p" type="paragraph" default="1"><pPr><jc val="center"/></pPr></style><style styleId="x" type="character"><rPr><i/></rPr></style><style styleId="x" type="paragraph" default="1"><pPr><jc val="right"/></pPr></style><style styleId="unused" type="character"><rPr><color val="FF0000"/></rPr></style></styles>`, `<pPr><pStyle val="missing"/></pPr>`, `<rPr><rStyle val="missing"/></rPr>`},
		{`<styles><style styleId="a" type="paragraph" default="1"><basedOn val="b"/><pPr><spacing before="20"/></pPr><rPr><b/></rPr></style><style styleId="b" type="paragraph"><basedOn val="a"/><pPr><jc val="right"/></pPr><rPr><i/></rPr></style><style styleId="c" type="character"><basedOn val="missing"/><rPr><caps/></rPr></style></styles>`, `<pPr/>`, `<rPr><rStyle val="c"/></rPr>`},
		{`<styles><style styleId="p" type="paragraph" default="1"><rPr><b/><rFonts ascii="Paragraph"/><lang val="en"/></rPr></style><style styleId="c" type="character" default="1"><rPr><b/><rFonts ascii="Character"/><lang val="de"/></rPr></style></styles>`, `<pPr/>`, `<rPr><rStyle val="unknown"/></rPr>`},
	}
	fixtures = append(fixtures,
		codexStyleCase{`<styles><docDefaults><pPrDefault><pPr><spacing line="300" lineRule="atLeast"/><tabs><tab pos="100" val="start"/><tab pos="300" val="right"/></tabs></pPr></pPrDefault></docDefaults><style type="paragraph" styleId="p" default="1"><pPr><spacing before="60"/><tabs><tab pos="100" val="clear"/><tab pos="200" val="center" leader="dot"/></tabs></pPr></style></styles>`, `<pPr><spacing line="480" lineRule="exact"/><tabs><tab pos="400" val="left"/></tabs></pPr>`, `<rPr><rStyle val="p"/></rPr>`},
	)
	for _, inherited := range []string{`<b val="0"/>`, `<b/>`} {
		for _, character := range []string{"", `<b/>`, `<b val="0"/>`} {
			styles := `<styles><style styleId="p" type="paragraph" default="1"><rPr>` + inherited + `</rPr></style><style styleId="c" type="character"><rPr>` + character + `</rPr></style></styles>`
			fixtures = append(fixtures, codexStyleCase{styles, `<pPr/>`, `<rPr><rStyle val="c"/></rPr>`})
		}
	}
	var deep strings.Builder
	deep.WriteString(`<styles>`)
	for i := 0; i < 40; i++ {
		fmt.Fprintf(&deep, `<style styleId="n%d" type="paragraph"`, i)
		if i == 0 {
			deep.WriteString(` default="1"`)
		}
		deep.WriteString(`>`)
		if i < 39 {
			fmt.Fprintf(&deep, `<basedOn val="n%d"/>`, i+1)
		}
		if i == 31 {
			deep.WriteString(`<rPr><b/></rPr>`)
		}
		if i == 32 {
			deep.WriteString(`<rPr><i/></rPr>`)
		}
		deep.WriteString(`</style>`)
	}
	deep.WriteString(`</styles>`)
	fixtures = append(fixtures, codexStyleCase{deep.String(), `<pPr/>`, `<rPr/>`})
	for i, tc := range fixtures {
		codexEmitStyle(t, out, i, tc)
	}
	t.Logf("%d style fixtures", len(fixtures))
}
