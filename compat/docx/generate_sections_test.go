//go:build ignore

// Copy without its build tag beside upstream converter/internal/wordproc,
// set BDF_DOCX_FIXTURES and BDF_REFERENCE_OUTPUT, then run TestCodexDOCXSections.
package wordproc

import (
	"archive/zip"
	"bytes"
	"compress/gzip"
	"encoding/base64"
	"fmt"
	"github.com/shibukawa/bdf/converter/internal/ooxml"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func docxChunks(b []byte) string {
	var s strings.Builder
	s.WriteString("[")
	v := base64.StdEncoding.EncodeToString(b)
	for i := 0; i < len(v); i += 1000 {
		end := min(i+1000, len(v))
		fmt.Fprintf(&s, "%q,\n", v[i:end])
	}
	s.WriteString("]")
	return s.String()
}
func sectionSynthetic(t *testing.T) []byte {
	t.Helper()
	var b bytes.Buffer
	z := zip.NewWriter(&b)
	files := []struct{ name, content string }{
		{"_rels/.rels", `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="x" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="custom/doc.xml"/></Relationships>`},
		{"custom/doc.xml", `<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:pPr><w:sectPr><w:pgSz w:w="9in" w:h="12in"/><w:pgSz w:w="1in" w:h="1in"/><w:pgMar w:top="-400" w:bottom="-720" w:left="1000" w:right="1100" w:header="300" w:footer="400" w:gutter="200"/><w:type w:val="continuous"/><w:titlePg/><w:pgNumType w:start="3" w:fmt="upperRoman"/><w:docGrid w:type="linesAndChars" w:linePitch="360" w:charSpace="2048"/><w:textDirection w:val="tbRl"/><w:cols w:equalWidth="false" w:sep="1"><w:col w:w="2000" w:space="240"/><w:col w:w="3000"/></w:cols></w:sectPr></w:pPr></w:p><w:p/><w:sectPr><w:pgMar w:left="2cm"/><w:pgMar w:left="1in"/><w:cols w:num="3" w:space="720" w:sep="true"/></w:sectPr></w:body></w:document>`},
	}
	for _, f := range files {
		w, e := z.Create(f.name)
		if e != nil {
			t.Fatal(e)
		}
		if _, e = w.Write([]byte(f.content)); e != nil {
			t.Fatal(e)
		}
	}
	if e := z.Close(); e != nil {
		t.Fatal(e)
	}
	return b.Bytes()
}
func TestCodexDOCXSections(t *testing.T) {
	dir, dest := os.Getenv("BDF_DOCX_FIXTURES"), os.Getenv("BDF_REFERENCE_OUTPUT")
	if dir == "" || dest == "" {
		t.Fatal("BDF_DOCX_FIXTURES and BDF_REFERENCE_OUTPUT required")
	}
	out, e := os.Create(dest)
	if e != nil {
		t.Fatal(e)
	}
	defer out.Close()
	names := []string{"basic.docx", "form-fixed.docx", "form-pages.docx", "form-rows.docx", "grid.docx", "math.docx", "styles.docx", "vertical.docx", "synthetic.docx"}
	for idx, name := range names {
		var data []byte
		if name == "synthetic.docx" {
			data = sectionSynthetic(t)
		} else {
			data, e = os.ReadFile(filepath.Join(dir, name))
			if e != nil {
				t.Fatal(e)
			}
		}
		p, e := ooxml.Open(bytes.NewReader(data), int64(len(data)))
		if e != nil {
			t.Fatal(e)
		}
		part := "word/document.xml"
		if r, ok := p.RelOfType("", "/officeDocument"); ok {
			part = r.Target
		}
		root, e := p.XML(part)
		if e != nil {
			t.Fatal(e)
		}
		body := root.Child("body")
		c := &converter{pkg: p, main: part, warned: map[string]bool{}}
		var sections []*section
		var prev *section
		for _, para := range body.Children("p") {
			if n := para.Path("pPr", "sectPr"); n != nil {
				prev = c.parseSection(n, prev)
				sections = append(sections, prev)
			}
		}
		sections = append(sections, c.parseSection(body.Child("sectPr"), prev))
		var compressed bytes.Buffer
		w := gzip.NewWriter(&compressed)
		w.Write(data)
		w.Close()
		fmt.Fprintf(out, "///|\ntest \"DOCX sections match upstream Go %d\" {\n check_docx_sections(%q,%s,%q,[\n", idx, name, docxChunks(compressed.Bytes()), part)
		for _, s := range sections {
			fmt.Fprintf(out, "(%#.17g,%#.17g,%#.17g,%#.17g,%#.17g,%#.17g,%#.17g,%#.17g,%t,%t),\n", s.pgW, s.pgH, s.top, s.bottom, s.left, s.right, s.header, s.footer, s.topExact, s.bottomExact)
		}
		fmt.Fprintln(out, "],[")
		for _, s := range sections {
			fmt.Fprintf(out, "(%q,%t,%dL,%q,%q,%#.17g,%#.17g,%t,%t,[", s.typ, s.titlePg, s.pgStart, s.pgFmt, s.gridType, s.linePitch, s.charSpace, s.vertical, s.colSep)
			for _, col := range s.cols {
				fmt.Fprintf(out, "(%#.17g,%#.17g),", col.x, col.w)
			}
			fmt.Fprintln(out, "]),")
		}
		fmt.Fprintln(out, "])\n}")
		t.Logf("%s: %d sections", name, len(sections))
	}
}
