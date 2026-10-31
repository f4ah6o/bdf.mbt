//go:build ignore

// Copy without its build tag into upstream converter/internal/wordproc and run
// TestCodexDOCXParagraphProps with BDF_REFERENCE_OUTPUT and BDF_DOCX_FIXTURES.
package wordproc

import (
	"archive/zip"
	"bytes"
	"encoding/xml"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/shibukawa/bdf/converter/internal/ooxml"
)

func codexPPrXML(n *ooxml.Node) string {
	var b strings.Builder
	var emit func(*ooxml.Node)
	emit = func(x *ooxml.Node) {
		fmt.Fprintf(&b, "<%s", x.Name)
		for _, a := range x.Attrs {
			// Relationship attributes are excluded by Node.Attr and cannot affect pPr.
			if strings.HasSuffix(a.Name.Space, "relationships") || a.Name.Space == "xmlns" || a.Name.Local == "xmlns" {
				continue
			}
			fmt.Fprintf(&b, " %s=\"", a.Name.Local)
			xml.EscapeText(&b, []byte(a.Value))
			b.WriteByte('"')
		}
		b.WriteByte('>')
		for _, child := range x.Elements() {
			emit(child)
		}
		fmt.Fprintf(&b, "</%s>", x.Name)
	}
	emit(n)
	return b.String()
}

func codexEmitPPr(t *testing.T, out io.Writer, id int, layers []string) {
	t.Helper()
	p := defaultPProps()
	c := &converter{opts: &Options{}, warned: map[string]bool{}}
	for _, source := range layers {
		n, err := ooxml.Parse([]byte(source))
		if err != nil {
			t.Fatal(err)
		}
		c.applyPPr(p, n)
	}
	fmt.Fprintf(out, "///|\ntest \"DOCX paragraph properties match upstream Go %d\" {\n check_docx_ppr([", id)
	for _, s := range layers {
		fmt.Fprintf(out, "%q,", s)
	}
	fmt.Fprint(out, "], {\n")
	fmt.Fprintf(out, "alignment:%q,left:%#.17g,right:%#.17g,first:%#.17g,left_chars:%#.17g,right_chars:%#.17g,first_chars:%#.17g,\n", p.jc, p.indL, p.indR, p.indFirst, p.indLCh, p.indRCh, p.indFirstCh)
	fmt.Fprintf(out, "before:%#.17g,after:%#.17g,before_lines:%#.17g,after_lines:%#.17g,before_auto:%t,after_auto:%t,line:%#.17g,line_rule:%q,\n", p.before, p.after, p.beforeLn, p.afterLn, p.beforeAuto, p.afterAuto, p.line, p.lineRule)
	fmt.Fprintf(out, "contextual:%t,keep_next:%t,keep_lines:%t,page_break_before:%t,widow_control:%t,snap_to_grid:%t,\n", p.contextual, p.keepNext, p.keepLines, p.pageBreakBefore, p.widowCtl, p.snapToGrid)
	fmt.Fprintf(out, "kinsoku:%t,overflow_punct:%t,auto_space_de:%t,auto_space_dn:%t,bidi:%t,suppress_line_numbers:%t,frame:%t,number_id:%q,level:%d,outline:%d,\n", p.kinsoku, p.overflowPunct, p.autoSpaceDE, p.autoSpaceDN, p.bidi, p.suppressLineNumbers, p.framePr, p.numID, p.ilvl, p.outline)
	fmt.Fprint(out, "tabs:[")
	for _, tab := range p.tabs {
		fmt.Fprintf(out, "{position:%#.17g,alignment:%q,leader:%q},", tab.pos, tab.align, tab.leader)
	}
	fmt.Fprintf(out, "],tabs_truncated:%t,\n})\n}\n", c.warned["tabs"])
}

func TestCodexDOCXParagraphProps(t *testing.T) {
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
		{`<pPr/>`},
		{`<pPr><keepNext/><keepLines val="false"/><pageBreakBefore val="on"/><widowControl val="1"/><contextualSpacing/><snapToGrid val="0"/><kinsoku val="off"/><overflowPunct val="0"/><autoSpaceDE val="false"/><autoSpaceDN val="false"/><bidi/><suppressLineNumbers/><framePr/><jc val="thaiDistribute"/><outlineLvl val="9"/></pPr>`},
		{`<pPr><ind left="1in" start="1440" right="200" end="-30" firstLine="400" hanging="300" leftChars="1" startChars="2" rightChars="3" endChars="4" firstLineChars="9" hangingChars="7"/><spacing before="720" after="2cm" beforeLines="150" afterLines="25" beforeAutospacing="on" afterAutospacing="true" line="360" lineRule="exact"/><numPr><ilvl val="2"/><numId val="57"/></numPr></pPr>`},
		{`<pPr><tabs><tab val="start" pos="100" leader="dot"/><tab val="end" pos="300"/><tab val="num" pos="200"/><tab val="decimal" pos="101"/><tab val="clear" pos="300"/></tabs></pPr>`, `<pPr><spacing before="100" lineRule="atLeast"/><ind start="-2pt"/><keepNext/></pPr>`},
		{`<pPr><tabs><tab val="left" pos="120"/><tab val="bar" pos="122"/><tab val="center" pos="123.9"/></tabs><outlineLvl val="-5"/><jc val="bad"/><numPr><numId val="a"/><numId val="b"/><ilvl val="3.9"/><ilvl val="8"/></numPr></pPr>`},
		{`<pPr><spacing line="bad" lineRule="exact" before="bad"/><ind left="bad" hanging="bad"/><keepLines val="BAD"/></pPr>`, `<pPr><spacing line="480"/><numPr><numId val="9"/></numPr></pPr>`},
	}
	var many strings.Builder
	many.WriteString("<pPr><tabs>")
	for i := 0; i < 201; i++ {
		fmt.Fprintf(&many, `<tab val="left" pos="%d"/>`, i*20)
	}
	many.WriteString("</tabs></pPr>")
	cases = append(cases, []string{many.String(), `<pPr><tabs><tab val="clear" pos="0"/></tabs></pPr>`})
	for _, name := range []string{"basic.docx", "form-fixed.docx", "form-pages.docx", "form-rows.docx", "grid.docx", "math.docx", "styles.docx", "vertical.docx"} {
		data, err := os.ReadFile(filepath.Join(dir, name))
		if err != nil {
			t.Fatal(err)
		}
		z, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
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
			r.Close()
			if err != nil {
				t.Fatal(err)
			}
			root, err := ooxml.Parse(data)
			if err != nil {
				t.Fatal(err)
			}
			var walk func(*ooxml.Node)
			walk = func(n *ooxml.Node) {
				if n.Name == "pPr" && n.Child("pBdr") == nil && n.Child("shd") == nil {
					cases = append(cases, []string{codexPPrXML(n)})
				}
				for _, child := range n.Elements() {
					walk(child)
				}
			}
			walk(root)
		}
	}
	for i, layers := range cases {
		codexEmitPPr(t, out, i, layers)
	}
	t.Logf("%d paragraph property fixtures", len(cases))
}
