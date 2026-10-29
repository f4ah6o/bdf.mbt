//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexXLSXLayout.
package xlsx

import (
	"bytes"
	"encoding/json"
	"math"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexXLSXLayout(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	data, e := os.ReadFile(filepath.Join(root, "compat/xlsx/geometry.json"))
	if e != nil {
		t.Fatal(e)
	}
	var samples []struct {
		Input []byte `json:"input"`
		Part  string `json:"part"`
	}
	if e = json.Unmarshal(data, &samples); e != nil {
		t.Fatal(e)
	}
	out := []any{}
	for i, sample := range samples {
		c, _, e := openWorkbook(bytes.NewReader(sample.Input), int64(len(sample.Input)), &Options{NoSystemFonts: true, SystemFonts: true})
		if e != nil {
			t.Fatal(e)
		}
		ws, e := c.readWorksheet(sample.Part)
		if e != nil {
			t.Fatal(e)
		}
		sc := &sheetCtx{c: c, ws: ws}
		sc.extent()
		mdw := []float64{5, 7, 8, 13.25}[i%4]
		ws.indexCols()
		sizes := map[int]float64{}
		def := ws.defaultColPt(mdw)
		for col, k := range ws.colLast {
			if k >= 0 {
				d := ws.cols[k]
				if d.hidden {
					sizes[col] = 0
				} else if d.width >= 0 {
					sizes[col] = colWidthPt(d.width, mdw)
				} else {
					sizes[col] = def
				}
			}
		}
		runs := newAxis(sc.nCols, def, sizes).runs()
		ws.sortRows()
		line := []float64{12.65, 17.25, 20}[i%3]
		rowDef := ws.defRowH
		if rowDef <= 0 {
			rowDef = autoRowHeight(line)
		}
		visibleDef := rowDef
		if ws.zeroH {
			visibleDef = 0
		}
		rowSizes := map[int]float64{}
		for _, rw := range ws.rows {
			if rw.idx >= sc.nRows {
				break
			}
			h := rowDef
			if rw.hidden {
				h = 0
			} else if rw.ht >= 0 {
				h = rw.ht
			} else if rw.idx%3 == 0 {
				h = math.Min(math.Max(h, 22.5+float64(rw.idx%5)*1.5), maxRowPt)
			}
			rowSizes[rw.idx] = h
		}
		rowRuns := newAxis(sc.nRows, visibleDef, rowSizes).runs()
		out = append(out, map[string]any{"input": sample.Input, "part": sample.Part, "mdw": mdw, "line": line, "want": []any{sc.nRows, sc.nCols, runs, rowRuns}})
	}
	b, e := json.Marshal(out)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/layout.json"), b, 0644); e != nil {
		t.Fatal(e)
	}
}
