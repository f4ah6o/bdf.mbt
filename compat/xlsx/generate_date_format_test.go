//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexXLSXDateFormat.
package xlsx

import (
	"encoding/json"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexXLSXDateFormat(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	formats := []string{"yyyy-mm-dd", "m/d/yyyy h:mm", "ddd dddd mmm mmmm mmmmm yy yyyy", "h:mm:ss.000 AM/PM", "hh:mm:ss.0 A/P", "[h]:mm:ss", "[mm]:ss.000", "[ss]", "[$-411]ggge\"年\"m\"月\"d\"日\" aaaa", "[$-411]mmm ddd", "bbbb-bb", "mm:ss", "ss.00000", `hh_):mm*秒`, `g gg ggg e ee`}
	values := []float64{-1, -0.000001, 0, 0.5, 0.999999999, 1, 59, 60, 60.5, 61, 365, 10000, 2958465, 2958465.99999999, 2958466, 43586, 43587, 43588, 32515, 32516, 32517}
	r := rand.New(rand.NewSource(242288))
	out := []any{}
	add := func(code string, v float64, d1904 bool) {
		sec := parseNumFormat(code, defaultPalette).sections[0]
		pieces, ok := formatDate(sec, v, d1904)
		p := []any{}
		for _, x := range pieces {
			p = append(p, []any{int(x.kind), x.s})
		}
		out = append(out, map[string]any{"code": code, "value": v, "date1904": d1904, "pieces": p, "ok": ok})
	}
	for _, f := range formats {
		for _, v := range values {
			add(f, v, false)
			add(f, v, true)
		}
	}
	for i := 0; i < 20000; i++ {
		v := r.Float64() * 2958466
		add(formats[r.Intn(len(formats))], v, r.Intn(2) == 0)
	}
	b, e := json.Marshal(out)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/xlsx/date-format.json"), b, 0644); e != nil {
		t.Fatal(e)
	}
}
