//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexXLSXFormats.
package xlsx

import (
	"encoding/json"
	"math"
	"math/rand"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCodexXLSXFormats(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	codes := []string{"", `0;[Red]-0;0;"text: "@`, `[>=100]0;[<0](0);0`, `[$€-407]0.00`, `yyyy-mm-dd h:mm:ss.000`, `# ?/?`, `General`, `[$-411]ggge"年"m"月"d"日"`}
	codes = append(codes, strings.Repeat("0", 600), strings.Repeat("x", 600), `[>]0`, `[<=>2]0`, `[ $€-407]0`, `[color 55]0`, `[DBNum-2]0`, `aab aaa AAA`, `ss_ ".".000`, `# ?/1234567891234`, `# ?/9223372036854775807`, `# ?/9223372036854775808`)
	r := rand.New(rand.NewSource(133178))
	parts := []string{"0", "#", "?", ".", ",", "%", "@", "E+", "e-", "/", "yyyy", "mm", "s", "AM/PM", "a/p", "aaa", "General", "[h]", "[mm]", "[Red]", "[COLOR10]", "[>=100]", "[<>-12.5]", "[DBNum2]", "[$€-407]", `"literal"`, `\x`, `_🦊`, `*x`, " ", "年", ";", "[bogus]"}
	for i := 0; i < 6000; i++ {
		s := ""
		for j := 0; j < r.Intn(15); j++ {
			s += parts[r.Intn(len(parts))]
		}
		codes = append(codes, s)
	}
	out := []any{}
	for _, code := range codes {
		nf := parseNumFormat(code, defaultPalette)
		sections := []any{}
		layouts := []any{}
		for _, s := range nf.sections {
			l := analyze(s.toks)
			layouts = append(layouts, []any{string(l.intPh), string(l.fracPh), l.point, l.thousands, l.scale, l.percent, l.exp, string(l.expPh), string(l.numPh), string(l.denPh), l.denFixed, l.fraction, l.general})
			tokens := []any{}
			for _, t := range s.toks {
				tokens = append(tokens, []any{int(t.kind), t.s})
			}
			var color any = nil
			if s.color != nil {
				color = int(math.Round(s.color.R*255))<<16 | int(math.Round(s.color.G*255))<<8 | int(math.Round(s.color.B*255))
			}
			op := ""
			val := 0.0
			if s.cond != nil {
				op = s.cond.op
				val = s.cond.val
			}
			sections = append(sections, []any{tokens, color, op, val, s.date, s.text, s.locale, s.dbnum})
		}
		picks := []any{}
		for _, v := range []float64{-1000, -12.5, -1, 0, 1, 100, 101} {
			chosen, unsigned := nf.pick(v)
			index := 0
			for i, sec := range nf.sections {
				if sec == chosen {
					index = i
					break
				}
			}
			picks = append(picks, []any{index, unsigned})
		}
		out = append(out, map[string]any{"code": code, "want": sections, "picks": picks, "layouts": layouts})
	}
	b, err := json.Marshal(out)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/xlsx/formats.json"), b, 0644); err != nil {
		t.Fatal(err)
	}
}
