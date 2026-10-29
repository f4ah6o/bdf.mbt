//go:build ignore

// Copy alongside generate_prepare_test.go into upstream converter/internal/music.
package music

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"os"
	"path/filepath"
	"strconv"
	"testing"

	"github.com/shibukawa/bdf/converter/internal/fontset"
	"github.com/shibukawa/bdf/internal/fontdb"
)

func TestCodexMusicSystemMarks(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	raw, err := os.ReadFile(filepath.Join(root, "compat/midiinput/score.json"))
	if err != nil {
		t.Fatal(err)
	}
	var prior []codexFixture
	if err = json.Unmarshal(raw, &prior); err != nil {
		t.Fatal(err)
	}
	output := []any{}
	for i, sample := range prior {
		s := codexScoreFromFixture(sample)
		e := &engraver{s: s, sp: defaultSp, def: fontDefaults(), text: &texter{set: fontset.New(fontdb.New(nil, nil, false), func(string) {})}}
		e.prepare()
		e.columns()
		widths := map[string]float64{}
		metrics := map[string][3]float64{}
		for _, part := range s.Parts {
			for _, m := range part.Measures {
				for _, ev := range m.Events {
					for _, l := range ev.Lyrics {
						t := e.text.line(l.Text, e.lyricSize(), false, false)
						widths[l.Text] = t.width / e.sp
						metrics[l.Text] = [3]float64{t.width / e.sp, t.asc / e.sp, t.desc / e.sp}
					}
				}
			}
		}
		width, indent := float64(40+(i%5)*12), float64(i%7)
		systems := e.breakSystems(width, indent)
		systemMetrics := map[string][3]float64{}
		for _, sys := range systems {
			if sys.first > 0 {
				v := strconv.Itoa(e.counts[sys.first])
				t := e.text.line(v, 1.6*e.sp, false, true)
				systemMetrics["i|"+v] = [3]float64{t.width / e.sp, t.asc / e.sp, t.desc / e.sp}
			}
			for mi := sys.first; mi <= sys.last; mi++ {
				for _, mark := range s.Measures[mi].Tempo {
					v := " = " + strconv.FormatFloat(mark.PerMinute, 'f', -1, 64)
					t := e.text.line(v, 2.4*e.sp, false, false)
					systemMetrics["n|"+v] = [3]float64{t.width / e.sp, t.asc / e.sp, t.desc / e.sp}
				}
			}
		}
		out := []any{}
		for _, sys := range systems {
			staves := []any{}
			for si := range e.staves {
				ctx := &staffCtx{e: e, sys: sys, si: si, c: newDrawing(), def: e.def, part: s.Parts[e.staves[si].part]}
				for k := 0; k < 5; k++ {
					ctx.c.rect(0, float64(k)-e.def.staffLine/2, sys.width, e.def.staffLine)
				}
				ctx.header()
				for mi := sys.first; mi <= sys.last; mi++ {
					ctx.measure(mi)
				}
				ctx.stemsAndBeams()
				ctx.dotsAndMarks()
				ctx.ties()
				ctx.slurs()
				ctx.tuplets()
				ctx.lyrics()
				if si == 0 {
					ctx.systemMarks()
				}
				prims := []any{}
				for _, p := range ctx.c.prims {
					name := ""
					if p.g != nil {
						name = p.g.name
					}
					var outline any
					if p.out != nil {
						outline = p.out.args
					}
					text := ""
					if p.text != nil {
						for _, run := range p.text.runs {
							text += run.s
						}
					}
					prims = append(prims, []any{int(p.kind), name, p.x, p.y, p.w, p.h, p.scale, p.width, p.dash, outline, text, p.align, int(p.mark), p.alt})
				}
				staves = append(staves, map[string]any{"primitives": prims, "above": ctx.c.top.at(-1e9, 1e9, 0), "below": ctx.c.bot.at(-1e9, 1e9, 4)})
			}
			out = append(out, staves)
		}
		output = append(output, map[string]any{"input": sample.Input, "widths": widths, "metrics": metrics, "systemMetrics": systemMetrics, "width": width, "indent": indent, "want": out})
	}
	b, err := json.Marshal(output)
	if err != nil {
		t.Fatal(err)
	}
	var compressed bytes.Buffer
	z := gzip.NewWriter(&compressed)
	if _, err = z.Write(b); err != nil {
		t.Fatal(err)
	}
	if err = z.Close(); err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/musicnotation/system_marks.json.gz"), compressed.Bytes(), 0644); err != nil {
		t.Fatal(err)
	}
}
