//go:build ignore

// Copy alongside generate_prepare_test.go into upstream converter/internal/music.
package music

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/shibukawa/bdf/converter/internal/fontset"
	"github.com/shibukawa/bdf/internal/fontdb"
)

func TestCodexMusicRests(t *testing.T) {
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
		for _, part := range s.Parts {
			for _, m := range part.Measures {
				for _, ev := range m.Events {
					for _, l := range ev.Lyrics {
						widths[l.Text] = e.text.width(l.Text, e.lyricSize(), false, false) / e.sp
					}
				}
			}
		}
		width, indent := float64(40+(i%5)*12), float64(i%7)
		systems := e.breakSystems(width, indent)
		out := []any{}
		for _, sys := range systems {
			for si := range e.staves {
				for mi := sys.first; mi <= sys.last; mi++ {
					col := e.cols[mi]
					sm := e.sm[mi][si]
					for _, event := range sm.events {
						if !event.Rest {
							continue
						}
						found := false
						x := 0.0
						for _, slot := range col.slots {
							if slot.offset == event.Offset {
								found = true
								x = col.x + slot.x
								break
							}
						}
						if !found {
							continue
						}
						ctx := &staffCtx{e: e, sys: sys, si: si, c: newDrawing(), def: e.def, part: s.Parts[e.staves[si].part]}
						ctx.rest(mi, sm, event, x)
						l := ctx.evs[0]
						prims := []any{}
						for _, p := range ctx.c.prims {
							name := ""
							if p.g != nil {
								name = p.g.name
							}
							prims = append(prims, []any{int(p.kind), name, p.x, p.y, p.w, p.h, p.scale})
						}
						out = append(out, []any{mi, si, event.Offset, []float64{l.x, l.right, l.top, l.bottom}, prims})
					}
				}
			}
		}
		output = append(output, map[string]any{"input": sample.Input, "widths": widths, "width": width, "indent": indent, "want": out})
	}
	b, err := json.Marshal(output)
	if err != nil {
		t.Fatal(err)
	}
	var compressed bytes.Buffer
	writer := gzip.NewWriter(&compressed)
	if _, err = writer.Write(b); err != nil {
		t.Fatal(err)
	}
	if err = writer.Close(); err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/musicnotation/rests.json.gz"), compressed.Bytes(), 0644); err != nil {
		t.Fatal(err)
	}
}
