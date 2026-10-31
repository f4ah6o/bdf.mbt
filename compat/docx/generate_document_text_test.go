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
		add("custom/styles.xml", `<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"/>`)
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
	fmt.Fprintf(out, "///|\ntest \"DOCX document text rejects unresolved styles\" {\n reject_docx_document_text(%s)\n}\n", codexTextChunks(codexTextPackage(t, `<w:p/>`, true)))
}
