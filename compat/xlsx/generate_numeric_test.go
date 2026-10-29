//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexXLSXNumeric.
package xlsx

import (
	"encoding/json"
	"math"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexXLSXNumeric(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	formats := []string{"General", "0", "0.00", "#,##0", "#,##0.00", "0%", "0.00%", "0.00E+00", "##0.0E+0", "# ?/?", "# ??/??", "?/8", "# ?/16", `"$"#,##0_);`, `0.##`, `0.??`, `#.###`, `.00`, `0.`, `#,##0,,`, `0.0,,`, `0.0%%%`, `*x0.00_)","`, `0E-0`, `???0.000#`}
	values := []float64{0, 1, -1, 0.5, -0.5, 1.25, 1.005, 2.675, 12.3456, 999.999, 1000, 123456789.12, 1e-9, 1e15}
	r := rand.New(rand.NewSource(40111))

	out := []any{}
	add := func(code string, v float64) {
		s := parseNumFormat(code, defaultPalette).sections[0]
		pieces, general := formatNumeric(s, v)
		p := []any{}
		for _, x := range pieces {
			p = append(p, []any{int(x.kind), x.s})
		}
		out = append(out, map[string]any{"code": code, "value": v, "pieces": p, "general": general})
	}
	for _, code := range formats {
		for _, v := range values {
			add(code, v)
		}
	}
	for i := 0; i < 20000; i++ {
		v := math.Copysign(r.Float64()*math.Pow(10, float64(r.Intn(16)-6)), float64(r.Intn(2)*2-1))
		add(formats[r.Intn(len(formats))], v)
	}
	b, e := json.Marshal(out)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/numeric.json"), b, 0644); e != nil {
		t.Fatal(e)
	}
}
