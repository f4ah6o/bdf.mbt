//go:build ignore

// Copy without its build tag beside upstream converter/pptx/pptx.go, set
// BDF_PPTX_FIXTURES and BDF_REFERENCE_OUTPUT, then run TestCodexPPTXManifest.
package pptx

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

func manifestChunks(b []byte) string {
	var s strings.Builder
	s.WriteString("[")
	encoded := base64.StdEncoding.EncodeToString(b)
	for i := 0; i < len(encoded); i += 1000 {
		end := min(i+1000, len(encoded))
		fmt.Fprintf(&s, "%q,\n", encoded[i:end])
	}
	s.WriteString("]")
	return s.String()
}
func syntheticPPTX(t *testing.T) []byte {
	t.Helper()
	var data bytes.Buffer
	z := zip.NewWriter(&data)
	files := []struct{ name, content string }{
		{"_rels/.rels", `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="root" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="custom/pres.xml"/></Relationships>`},
		{"custom/pres.xml", `<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://purl.oclc.org/ooxml/officeDocument/relationships" firstSlideNum="7.9"><p:sldIdLst><p:sldId id="1" r:id="b"/><p:sldId id="2" r:id="a"/><p:sldId id="3" r:id="missing"/></p:sldIdLst><p:sldSz cx="10in" cy="15cm"/></p:presentation>`},
		{"custom/_rels/pres.xml.rels", `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="a" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/one.xml"/><Relationship Id="b" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/two.xml"/></Relationships>`},
		{"custom/slides/one.xml", `<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"/>`},
		{"custom/slides/two.xml", `<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" show="off"/>`},
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
	return data.Bytes()
}
func TestCodexPPTXManifest(t *testing.T) {
	dir, dest := os.Getenv("BDF_PPTX_FIXTURES"), os.Getenv("BDF_REFERENCE_OUTPUT")
	if dir == "" || dest == "" {
		t.Fatal("BDF_PPTX_FIXTURES and BDF_REFERENCE_OUTPUT required")
	}
	out, e := os.Create(dest)
	if e != nil {
		t.Fatal(e)
	}
	defer out.Close()
	names := []string{"basic.pptx", "features.pptx", "form-fixed.pptx", "form-pages.pptx", "form-rows.pptx", "math.pptx", "synthetic.pptx"}
	for idx, name := range names {
		var data []byte
		if name == "synthetic.pptx" {
			data = syntheticPPTX(t)
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
		part := "ppt/presentation.xml"
		if r, ok := p.RelOfType("", "/officeDocument"); ok {
			part = r.Target
		}
		root, e := p.XML(part)
		if e != nil {
			t.Fatal(e)
		}
		sz := root.Child("sldSz")
		w, h := sz.AttrEMU("cx", 720), sz.AttrEMU("cy", 540)
		if w <= 0 || h <= 0 || w > 20000 || h > 20000 {
			w, h = 720, 540
		}
		first := root.AttrInt("firstSlideNum", 1)
		var z bytes.Buffer
		gz := gzip.NewWriter(&z)
		gz.Write(data)
		gz.Close()
		fmt.Fprintf(out, "///|\ntest \"PPTX presentation matches upstream Go %d\" {\n check_pptx_manifest(%q,%s,%q,%#.17g,%#.17g,%dL,[\n", idx, name, manifestChunks(z.Bytes()), part, w, h, first)
		count := 0
		for _, slide := range root.Path("sldIdLst").Children("sldId") {
			if r, ok := p.Target(part, slide.RelID("id")); ok {
				sn, e := p.XML(r.Target)
				hidden := e == nil && !sn.AttrBool("show", true)
				fmt.Fprintf(out, "(%q,%t),\n", r.Target, hidden)
				count++
			}
		}
		fmt.Fprintln(out, "])\n}")
		t.Logf("%s: %d slides", name, count)
	}
}
