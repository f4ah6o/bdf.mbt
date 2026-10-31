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
	"github.com/shibukawa/bdf/converter/internal/ooxml/drawingml"
	"os"
	"path/filepath"
	"sort"
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
		{"custom/slides/_rels/one.xml.rels", `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="l1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../layouts/one.xml"/></Relationships>`},
		{"custom/slides/_rels/two.xml.rels", `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="l1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../layouts/one.xml"/></Relationships>`},
		{"custom/layouts/one.xml", `<p:sldLayout xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" showMasterSp="false"><p:clrMapOvr><p:overrideClrMapping accent1="accent3"/></p:clrMapOvr><p:cSld><p:spTree><p:sp><p:nvSpPr><p:nvPr><p:ph type="ctrTitle" idx="1"/></p:nvPr></p:nvSpPr></p:sp></p:spTree></p:cSld></p:sldLayout>`},
		{"custom/layouts/_rels/one.xml.rels", `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="m1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../masters/one.xml"/></Relationships>`},
		{"custom/masters/one.xml", `<p:sldMaster xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:clrMap bg1="lt1" tx1="dk1" accent1="accent2"/><p:cSld><p:spTree><p:sp><p:nvSpPr><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr></p:sp></p:spTree></p:cSld></p:sldMaster>`},
		{"custom/slides/one.xml", `<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><p:clrMapOvr><p:overrideClrMapping tx1="dk2"/></p:clrMapOvr><p:cSld><p:spTree><p:sp><p:nvSpPr><p:nvPr><p:ph type="title" idx="1"/></p:nvPr></p:nvSpPr><p:spPr><p:xfrm rot="5400000" flipH="1"><p:off x="12700" y="25400"/><p:ext cx="127000" cy="254000"/></p:xfrm></p:spPr></p:sp><p:sp><p:nvSpPr><p:nvPr><p:ph/></p:nvPr></p:nvSpPr></p:sp><p:sp><p:nvPicPr><p:nvPr><p:ph type="pic" idx="3"/></p:nvPr></p:nvPicPr><p:nvSpPr><p:nvPr><p:ph type="body" idx="4"/></p:nvPr></p:nvSpPr></p:sp><mc:AlternateContent><mc:Choice Requires="x"><p:pic/></mc:Choice><mc:Fallback><p:sp><p:spPr><p:xfrm><p:off x="12700" y="25400"/></p:xfrm></p:spPr><p:nvSpPr><p:nvPr><p:ph type="body" idx="9"/></p:nvPr></p:nvSpPr></p:sp></mc:Fallback></mc:AlternateContent><mc:AlternateContent><mc:Choice Requires="x"><p:pic/></mc:Choice><mc:Choice Requires="y"><p:sp/></mc:Choice></mc:AlternateContent><p:AlternateContent/><p:sp><p:nvSpPr/><p:nvSpPr><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr></p:sp><p:sp><p:nvSpPr><p:nvPr/><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr></p:sp></p:spTree></p:cSld></p:sld>`},
		{"custom/slides/two.xml", `<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" show="off" showMasterSp="false"><p:clrMapOvr/><p:clrMapOvr><p:overrideClrMapping bg1="dk2"/></p:clrMapOvr></p:sld>`},
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
		var contexts []string
		var placeholdersData []string
		var shapeTransforms []string
		for _, slide := range root.Path("sldIdLst").Children("sldId") {
			if r, ok := p.Target(part, slide.RelID("id")); ok {
				sn, e := p.XML(r.Target)
				hidden := e == nil && !sn.AttrBool("show", true)
				fmt.Fprintf(out, "(%q,%t),\n", r.Target, hidden)
				layoutPart, masterPart := "", ""
				var layout, master *ooxml.Node
				if rel, ok := p.RelOfType(r.Target, "/slideLayout"); ok {
					layoutPart = rel.Target
					layout, _ = p.XML(rel.Target)
				}
				if layout != nil {
					if rel, ok := p.RelOfType(layoutPart, "/slideMaster"); ok {
						masterPart = rel.Target
						master, _ = p.XML(rel.Target)
					}
				}
				show := sn.AttrBool("showMasterSp", true)
				colorMap := map[string]string{}
				if cm := master.Child("clrMap"); cm != nil {
					for _, a := range cm.Attrs {
						colorMap[a.Name.Local] = a.Value
					}
				}
				for _, src := range []*ooxml.Node{layout, sn} {
					if ov := src.Path("clrMapOvr", "overrideClrMapping"); ov != nil {
						for _, a := range ov.Attrs {
							colorMap[a.Name.Local] = a.Value
						}
					}
				}
				keys := make([]string, 0, len(colorMap))
				for key := range colorMap {
					keys = append(keys, key)
				}
				sort.Strings(keys)
				var colors strings.Builder
				for _, key := range keys {
					fmt.Fprintf(&colors, "(%q,%q),", key, colorMap[key])
				}
				var transforms []string
				for _, shape := range sn.Path("cSld", "spTree").Elements() {
					x, y, w, h, rot, fh, fv, ok := drawingml.CodexShapeTransform(shape)
					xf := "None"
					if ok {
						xf = fmt.Sprintf("Some((%#.17g,%#.17g,%#.17g,%#.17g,%#.17g,%t,%t))", x, y, w, h, rot, fh, fv)
					}
					transforms = append(transforms, fmt.Sprintf("(%q,%s)", shape.Name, xf))
				}
				shapeTransforms = append(shapeTransforms, "["+strings.Join(transforms, ",")+"],")
				var groups []string
				for _, root := range []*ooxml.Node{sn, layout, master} {
					var values []string
					for _, shape := range placeholders(root) {
						ph := phOf(shape)
						index := "None"
						if value, ok := ph.Attr("idx"); ok {
							index = fmt.Sprintf("Some(%q)", value)
						}
						values = append(values, fmt.Sprintf("(%q,%s)", phType(ph), index))
					}
					groups = append(groups, "["+strings.Join(values, ",")+"]")
				}
				placeholdersData = append(placeholdersData, "("+strings.Join(groups, ",")+"),")
				contexts = append(contexts, fmt.Sprintf("(%q,%q,%t,%t,[%s]),", layoutPart, masterPart, show && layout != nil, show && layout != nil && layout.AttrBool("showMasterSp", true) && master != nil, colors.String()))
				count++
			}
		}
		fmt.Fprintln(out, "],[")
		for _, context := range contexts {
			fmt.Fprintln(out, context)
		}
		fmt.Fprintln(out, "],[")
		for _, transforms := range shapeTransforms {
			fmt.Fprintln(out, transforms)
		}
		fmt.Fprintln(out, "],[")
		for _, placeholders := range placeholdersData {
			fmt.Fprintln(out, placeholders)
		}
		fmt.Fprintln(out, "])\n}")
		t.Logf("%s: %d slides", name, count)
	}
}
