//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexXLSXFormatted.
package xlsx

import (
	"encoding/json"
	"math"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexXLSXFormatted(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	formats := []string{"General", "0", "0.00", "#,##0.00", "0%", "0.00E+00", "# ?/?", `0;[Red](0);"zero";"text:"@`, `[>=100]0;[<0](0);"other"`, `[DBNum1]0.00`, `[DBNum2]0`, `[DBNum3]0`, `"prefix"@"suffix"`, `0;0;0;"always"`, `0;;0;@`, `@`, `""`, `yyyy-mm-dd`, `[$-411]ggge"年"m"月"d"日"`, `[h]:mm:ss.000`, `0_);[Color10](0)`}
	values := []float64{-100, -1, -0.5, 0, 0.5, 1, 1.25, 2.675, 100, 1000, 60, 43587, 2958466}
	texts := []string{"", "abc", "日本語123", "hello world"}
	r := rand.New(rand.NewSource(611289))
	out := []any{}
	encode := func(f formatted) any {
		p := []any{}
		for _, x := range f.pieces {
			p = append(p, []any{int(x.kind), x.s})
		}
		var color any = nil
		if f.color != nil {
			color = int(math.Round(f.color.R*255))<<16 | int(math.Round(f.color.G*255))<<8 | int(math.Round(f.color.B*255))
		}
		return []any{p, color, f.general, f.number}
	}
	for _, code := range formats {
		nf := parseNumFormat(code, defaultPalette)
		for _, text := range texts {
			out = append(out, map[string]any{"code": code, "text": text, "kind": "text", "want": encode(nf.formatText(text))})
		}
		for _, v := range values {
			out = append(out, map[string]any{"code": code, "value": v, "date1904": false, "kind": "number", "want": encode(nf.formatNumber(v, false))})
		}
	}
	for i := 0; i < 10000; i++ {
		code := formats[r.Intn(len(formats))]
		v := r.Float64()*100000 - 30000
		d := r.Intn(2) == 0
		nf := parseNumFormat(code, defaultPalette)
		out = append(out, map[string]any{"code": code, "value": v, "date1904": d, "kind": "number", "want": encode(nf.formatNumber(v, d))})
	}
	b, e := json.Marshal(out)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/formatted.json"), b, 0644); e != nil {
		t.Fatal(e)
	}
}
