//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexXLSXStoreSheet.
package xlsx

import (
	"bytes"
	"encoding/json"
	"github.com/shibukawa/bdf"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexXLSXStoreSheet(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	var samples []struct {
		Input  []byte `json:"input"`
		Part   string `json:"part"`
		Locale string `json:"locale"`
	}
	for _, file := range []string{"table-values.json", "list-tables.json"} {
		b, e := os.ReadFile(filepath.Join(root, "compat/xlsx", file))
		if e != nil {
			t.Fatal(e)
		}
		var v []struct {
			Input  []byte `json:"input"`
			Part   string `json:"part"`
			Locale string `json:"locale"`
		}
		if e = json.Unmarshal(b, &v); e != nil {
			t.Fatal(e)
		}
		samples = append(samples, v...)
	}
	out := []any{}
	for i, s := range samples {
		mode := []string{"", "none", "all"}[i%3]
		opts := &Options{NoSystemFonts: true, SystemFonts: true, Data: mode}
		c, _, e := openWorkbook(bytes.NewReader(s.Input), int64(len(s.Input)), opts)
		if e != nil {
			t.Fatal(e)
		}
		c.locale = s.Locale
		ws, e := c.readWorksheet(s.Part)
		if e != nil {
			t.Fatal(e)
		}
		ws.name = "sheet \"日\""
		ws.sortRows()
		skip := false
		for _, tab := range c.listTables(ws) {
			rows := int64(tab.ref.r1 - tab.ref.r0 + 1)
			cols := int64(tab.ref.c1 - tab.ref.c0 + 1)
			if rows > 5000 && rows*cols <= 1<<26 && mode != "none" {
				skip = true
			}
		}
		if skip {
			continue
		}
		c.warnings = nil
		c.nTables = 3
		c.storeSheetTables(ws, 2, "v1")
		tables := c.doc.Tables
		if tables == nil {
			tables = []*bdf.Table{}
		}
		warnings := c.warnings
		if warnings == nil {
			warnings = []string{}
		}
		out = append(out, map[string]any{"input": s.Input, "part": s.Part, "locale": s.Locale, "mode": mode, "tables": tables, "warnings": warnings, "counter": c.nTables})
	}
	b, e := json.Marshal(out)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/store-sheet.json"), b, 0644); e != nil {
		t.Fatal(e)
	}
}
