//go:build ignore

// Copy without the build tag into upstream converter/internal/wordproc.
// Set BDF_REFERENCE_OUTPUT and run TestCodexDOCXDocumentText.
package wordproc

import (
	"archive/zip"
	"bytes"
	"compress/gzip"
	"encoding/base64"
	"encoding/xml"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/shibukawa/bdf/converter/internal/ooxml"
)

func codexTextPackage(t *testing.T, body string, styles bool) []byte {
	t.Helper()
	var b bytes.Buffer
	z := zip.NewWriter(&b)
	add := func(name, value string) {
		f, err := z.Create(name)
		if err != nil {
			t.Fatal(err)
		}
		if _, err = f.Write([]byte(value)); err != nil {
			t.Fatal(err)
		}
	}
	add("_rels/.rels", `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="doc" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="custom/document.xml"/></Relationships>`)
	add("custom/document.xml", `<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>`+body+`</w:body></w:document>`)
	if styles {
		add("custom/_rels/document.xml.rels", `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="s" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>`)
		add("custom/styles.xml", `<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:docDefaults><w:rPrDefault><w:rPr><w:color w:val="FF0000"/></w:rPr></w:rPrDefault></w:docDefaults></w:styles>`)
	}
	if err := z.Close(); err != nil {
		t.Fatal(err)
	}
	return b.Bytes()
}

func codexTextChunks(b []byte) string {
	var compressed bytes.Buffer
	z := gzip.NewWriter(&compressed)
	_, _ = z.Write(b)
	_ = z.Close()
	encoded := base64.StdEncoding.EncodeToString(compressed.Bytes())
	var out strings.Builder
	out.WriteString("[")
	for i := 0; i < len(encoded); i += 1000 {
		fmt.Fprintf(&out, "%q,\n", encoded[i:min(i+1000, len(encoded))])
	}
	out.WriteString("]")
	return out.String()
}

func codexStyledPackage(t *testing.T, body, styles string) []byte {
	t.Helper()
	var b bytes.Buffer
	z := zip.NewWriter(&b)
	add := func(name, content string) {
		w, e := z.Create(name)
		if e != nil {
			t.Fatal(e)
		}
		if _, e = w.Write([]byte(content)); e != nil {
			t.Fatal(e)
		}
	}
	add("_rels/.rels", `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="doc" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="custom/document.xml"/></Relationships>`)
	add("custom/_rels/document.xml.rels", `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="s" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>`)
	add("custom/document.xml", `<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>`+body+`</w:body></w:document>`)
	add("custom/styles.xml", `<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">`+styles+`</w:styles>`)
	if e := z.Close(); e != nil {
		t.Fatal(e)
	}
	return b.Bytes()
}

func codexUnsupportedRelPackage(t *testing.T, kind string) []byte {
	t.Helper()
	var b bytes.Buffer
	z := zip.NewWriter(&b)
	add := func(name, content string) {
		w, e := z.Create(name)
		if e != nil {
			t.Fatal(e)
		}
		if _, e = w.Write([]byte(content)); e != nil {
			t.Fatal(e)
		}
	}
	add("_rels/.rels", `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="doc" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="custom/document.xml"/></Relationships>`)
	add("custom/_rels/document.xml.rels", `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="x" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/`+kind+`" Target="`+kind+`.xml"/></Relationships>`)
	add("custom/document.xml", `<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/></w:body></w:document>`)
	add("custom/"+kind+".xml", `<root/>`)
	if e := z.Close(); e != nil {
		t.Fatal(e)
	}
	return b.Bytes()
}

func codexWriteRunProps(out *os.File, r *rprops) {
	fmt.Fprintf(out, "{fonts:[%q,%q,%q,%q],themes:[%q,%q,%q,%q],hint:%q,toggles:%d,specified:%d,", r.fonts[0], r.fonts[1], r.fonts[2], r.fonts[3], r.themes[0], r.themes[1], r.themes[2], r.themes[3], r.hint, r.toggles, r.set)
	fmt.Fprintf(out, "size:%#.17g,color:%dU,auto_color:%t,shading:%dU,has_shading:%t,underline_color:%dU,has_underline_color:%t,", r.sz, r.color, r.autoColor, r.shd, r.hasShd, r.uColor, r.hasUColor)
	fmt.Fprintf(out, "highlight:%q,underline:%q,vertical_align:%q,position:%#.17g,spacing:%#.17g,scale:%#.17g,emphasis:%q,", r.highlight, r.u, r.vertAlign, r.position, r.spacing, r.scale, r.em)
	fmt.Fprintf(out, "languages:[%q,%q,%q],web_hidden:%t,rtl:%t,tcy:%t,tcy_fit:%t,}", r.lang[0], r.lang[1], r.lang[2], r.webHidden, r.rtl, r.tcy, r.tcyFit)
}

func codexStyledFixture(t *testing.T, out *os.File, index int, body, styles string) {
	t.Helper()
	data := codexStyledPackage(t, body, styles)
	p, e := ooxml.Open(bytes.NewReader(data), int64(len(data)))
	if e != nil {
		t.Fatal(e)
	}
	c, _, e := newConverter(&Options{NoSystemFonts: true, SystemFonts: true}, ViewsBoth)
	if e != nil {
		t.Fatal(e)
	}
	c.pkg = p
	c.main = "custom/document.xml"
	c.loadStyles()
	c.loadNumbering()
	root, e := p.XML(c.main)
	if e != nil {
		t.Fatal(e)
	}
	bodyNode := root.Child("body")
	w := &walker{c: c, part: c.main}
	blocks := w.blocks(bodyNode)
	c.splitSections(blocks, bodyNode.Child("sectPr"))
	fmt.Fprintf(out, "///|\ntest \"DOCX styled text matches upstream Go %d\" {\n check_docx_styled_text(%s,[\n", index, codexTextChunks(data))
	section := 0
	for _, block := range blocks {
		para, ok := block.(*para)
		if !ok {
			t.Fatal("unexpected table")
		}
		fmt.Fprintf(out, "(%d,%q,%#.17g,%#.17g,%#.17g,", section, para.pp.jc, para.pp.indL, para.pp.before, para.pp.after)
		codexWriteRunProps(out, para.mark.rp)
		fmt.Fprint(out, ",[")
		for _, item := range para.items {
			var kind, text string
			switch item.kind {
			case kChar:
				kind = "char"
				text = string(item.r)
			case kTab:
				kind = "tab"
				text = "\t"
			case kBreak:
				kind = "break"
				text = "\n"
			case kPage:
				kind = "page"
			case kColumn:
				kind = "column"
			default:
				t.Fatalf("unexpected kind %d", item.kind)
			}
			fmt.Fprintf(out, "(%q,%q,%t,", kind, text, item.clear)
			codexWriteRunProps(out, item.st.rp)
			fmt.Fprint(out, "),")
		}
		fmt.Fprintln(out, "]),")
		if para.sect != nil {
			section++
		}
	}
	fmt.Fprintln(out, "])\n}")
}

func TestCodexDOCXDocumentText(t *testing.T) {
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dest == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(dest)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	fixtures := []string{
		`<w:p><w:r><w:t>Hello, 世界🙂</w:t></w:r></w:p><w:p/><w:sectPr/>`,
		`<w:p><w:r><w:t xml:space="preserve">  A&amp;B &#x1F600; </w:t><w:t><![CDATA[x<y]]></w:t><w:t>&#x9;&#xD;&#xA;&#xAD;</w:t></w:r></w:p>`,
		`<w:p><w:r><w:t>first</w:t><w:tab/><w:ptab/><w:br/><w:br w:type="page"/><w:br w:type="column"/><w:br w:clear="all"/><w:cr/><w:noBreakHyphen/><w:softHyphen/><w:lastRenderedPageBreak/></w:r></w:p>`,
		`<w:sdt><w:sdtContent><w:p><w:ins><w:r><w:t>insert</w:t></w:r></w:ins><w:sdt><w:sdtContent><w:r><w:t> nested</w:t></w:r></w:sdtContent></w:sdt></w:p></w:sdtContent></w:sdt><w:customXml><w:p><w:r><w:t>end</w:t></w:r></w:p></w:customXml>`,
		`<w:p><w:pPr><w:jc w:val="center"/><w:ind w:start="720" w:hanging="240"/><w:spacing w:before="40" w:after="80"/><w:sectPr><w:pgSz w:w="9in" w:h="11in"/></w:sectPr></w:pPr><w:r><w:t>one</w:t></w:r></w:p><w:p><w:r><w:t>two</w:t></w:r></w:p><w:sectPr><w:pgMar w:left="2in"/></w:sectPr>`,
		`<w:p><w:pPr><w:tabs><w:tab w:val="right" w:pos="600"/><w:tab w:val="start" w:pos="200"/></w:tabs><w:keepNext/><w:snapToGrid w:val="0"/></w:pPr><w:r/><w:r><w:t>z</w:t></w:r></w:p>`,
	}
	fixturesDir := os.Getenv("BDF_DOCX_FIXTURES")
	if fixturesDir == "" {
		t.Fatal("BDF_DOCX_FIXTURES required")
	}
	for _, name := range []string{"basic.docx", "form-fixed.docx", "form-pages.docx", "form-rows.docx", "grid.docx", "math.docx", "styles.docx", "vertical.docx"} {
		data, err := os.ReadFile(filepath.Join(fixturesDir, name))
		if err != nil {
			t.Fatal(err)
		}
		pack, err := ooxml.Open(bytes.NewReader(data), int64(len(data)))
		if err != nil {
			t.Fatal(err)
		}
		root, err := pack.XML("word/document.xml")
		if err != nil {
			t.Fatal(err)
		}
		count := 0
		var visit func(*ooxml.Node)
		visit = func(node *ooxml.Node) {
			if node.Name == "t" && node.Content() != "" && len(node.Content()) < 200 && count < 4 {
				var text strings.Builder
				_ = xml.EscapeText(&text, []byte(node.Content()))
				fixtures = append(fixtures, `<w:p><w:r><w:t xml:space="preserve">`+text.String()+`</w:t></w:r></w:p>`)
				count++
			}
			for _, child := range node.Elements() {
				visit(child)
			}
		}
		visit(root)
	}
	for i, body := range fixtures {
		data := codexTextPackage(t, body, false)
		p, err := ooxml.Open(bytes.NewReader(data), int64(len(data)))
		if err != nil {
			t.Fatal(err)
		}
		c, _, err := newConverter(&Options{NoSystemFonts: true, SystemFonts: true}, ViewsBoth)
		if err != nil {
			t.Fatal(err)
		}
		c.pkg = p
		c.main = "custom/document.xml"
		c.loadStyles()
		c.loadNumbering()
		root, err := p.XML(c.main)
		if err != nil {
			t.Fatal(err)
		}
		bodyNode := root.Child("body")
		w := &walker{c: c, part: c.main}
		blocks := w.blocks(bodyNode)
		c.splitSections(blocks, bodyNode.Child("sectPr"))
		fmt.Fprintf(out, "///|\ntest \"DOCX document text matches upstream Go %d\" {\n check_docx_document_text(%s, [\n", i, codexTextChunks(data))
		sec := 0
		for _, block := range blocks {
			para, ok := block.(*para)
			if !ok {
				t.Fatal("unexpected table")
			}
			fmt.Fprintf(out, "(%d, %q, %#.17g, %#.17g, %#.17g, %#.17g, %t, %t, [", sec, para.pp.jc, para.pp.indL, para.pp.indFirst, para.pp.before, para.pp.after, para.pp.keepNext, para.pp.snapToGrid)
			for _, item := range para.items {
				kind := ""
				text := ""
				switch item.kind {
				case kChar:
					kind = "char"
					text = string(item.r)
				case kTab:
					kind = "tab"
					text = "\t"
				case kBreak:
					kind = "break"
					text = "\n"
				case kPage:
					kind = "page"
				case kColumn:
					kind = "column"
				default:
					t.Fatalf("unexpected kind %d", item.kind)
				}
				fmt.Fprintf(out, "(%q,%q,%t),", kind, text, item.clear)
			}
			fmt.Fprintln(out, "]),")
			if para.sect != nil {
				sec++
			}
		}
		fmt.Fprint(out, "], [")
		for _, section := range c.sections {
			fmt.Fprintf(out, "(%#.17g,%#.17g,%#.17g),", section.pgW, section.pgH, section.left)
		}
		fmt.Fprintln(out, "])\n}")
	}
	codexStyledFixture(t, out, 0,
		`<w:p><w:pPr><w:pStyle w:val="Heading"/><w:spacing w:after="240"/></w:pPr><w:r><w:t>Hi</w:t><w:tab/></w:r><w:r><w:rPr><w:b/><w:sz w:val="28"/></w:rPr><w:t>A</w:t><w:br/></w:r></w:p><w:p/><w:sectPr/>`,
		`<w:docDefaults><w:pPrDefault><w:pPr><w:spacing w:before="100"/></w:pPr></w:pPrDefault><w:rPrDefault><w:rPr><w:rFonts w:ascii="Base"/><w:sz w:val="20"/><w:lang w:val="en-US"/></w:rPr></w:rPrDefault></w:docDefaults><w:style w:type="paragraph" w:styleId="Normal" w:default="1"><w:pPr><w:jc w:val="left"/></w:pPr></w:style><w:style w:type="paragraph" w:styleId="Heading"><w:basedOn w:val="Normal"/><w:pPr><w:jc w:val="center"/><w:ind w:left="720"/></w:pPr><w:rPr><w:i/></w:rPr></w:style>`)
	codexStyledFixture(t, out, 1,
		`<w:p><w:r><w:rPr><w:rStyle w:val="Emphasis"/><w:rFonts w:ascii="Direct"/></w:rPr><w:t>X</w:t></w:r><w:r><w:t>Y</w:t><w:br w:type="page"/></w:r></w:p>`,
		`<w:style w:type="paragraph" w:styleId="Normal" w:default="1"><w:rPr><w:b/><w:rFonts w:ascii="Parent"/></w:rPr></w:style><w:style w:type="character" w:styleId="Emphasis"><w:rPr><w:b/><w:i/><w:lang w:eastAsia="ja-JP"/></w:rPr></w:style><w:style w:type="character" w:styleId="Default" w:default="1"><w:rPr><w:u/></w:rPr></w:style>`)
	for _, kind := range []string{"settings", "numbering", "footnotes", "endnotes"} {
		fmt.Fprintf(out, "///|\ntest \"DOCX document text rejects unsupported %s\" {\n reject_docx_document_text(%s)\n}\n", kind, codexTextChunks(codexUnsupportedRelPackage(t, kind)))
	}
	fmt.Fprintf(out, "///|\ntest \"DOCX document text rejects unsupported styles\" {\n reject_docx_document_text(%s)\n}\n", codexTextChunks(codexTextPackage(t, `<w:p/>`, true)))
}
