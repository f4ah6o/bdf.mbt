//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexIgnoredSheetFeatures.
package xlsx

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexIgnoredSheetFeatures(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	names := []string{"sheetProtection", "protectedRanges", "scenarios", "dataConsolidate", "customSheetViews", "phoneticPr", "dataValidations", "sortState", "ignoredErrors", "smartTags", "picture", "oleObjects", "controls", "webPublishItems", "legacyDrawingHF", "customProperties", "cellWatches", "sheetCalcPr", "customFilters", "futureMetadata"}
	out := []any{}
	for i := 0; i < 320; i++ {
		var b bytes.Buffer
		z := zip.NewWriter(&b)
		add := func(n, s string) {
			w, e := z.Create(n)
			if e != nil {
				t.Fatal(e)
			}
			if _, e = w.Write([]byte(s)); e != nil {
				t.Fatal(e)
			}
		}
		add("xl/workbook.xml", `<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet" r:id="r1"/></sheets></workbook>`)
		add("xl/_rels/workbook.xml.rels", `<Relationships><Relationship Id="r1" Type="x/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="r2" Type="x/styles" Target="styles.xml"/></Relationships>`)
		add("xl/styles.xml", `<styleSheet><fonts><font/><font><b/></font></fonts><cellXfs><xf/><xf fontId="1"/></cellXfs></styleSheet>`)
		first := names[i%len(names)]
		second := names[(i/len(names)+3)%len(names)]
		ignored := fmt.Sprintf(`<%s enabled="1"><item value="x"><nested>ignored</nested></item></%s><%s/>`, first, first, second)
		body := fmt.Sprintf(`<worksheet><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>Hello</t></is></c><c r="B1" s="1"><v>%d</v></c></row></sheetData>%s</worksheet>`, i, ignored)
		add("xl/worksheets/sheet1.xml", body)
		if e := z.Close(); e != nil {
			t.Fatal(e)
		}
		result, e := Convert(bytes.NewReader(b.Bytes()), int64(b.Len()), &Options{NoSystemFonts: true, SystemFonts: true, NoTextIndex: true, Data: "none"})
		if e != nil {
			t.Fatal(e)
		}
		var doc bytes.Buffer
		if e = result.Doc.WriteSingle(&doc); e != nil {
			t.Fatal(e)
		}
		out = append(out, map[string]any{"input": b.Bytes(), "bdf": doc.Bytes(), "warnings": result.Warnings, "mode": "none", "no_index": true})
	}
	data, e := json.Marshal(out)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/ignored-sheet-features.json"), data, 0644); e != nil {
		t.Fatal(e)
	}
}
