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

func TestCodexMusicBeams(t *testing.T) {
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
					voices := []int{}
					seen := map[int]bool{}
					for _, ev := range sm.events {
						if !ev.Rest && !seen[ev.Voice] {
							voices = append(voices, ev.Voice)
							seen[ev.Voice] = true
						}
					}
					for _, voice := range voices {
						ctx := &staffCtx{e: e, sys: sys, si: si, c: newDrawing(), def: e.def, part: s.Parts[e.staves[si].part]}
						entries := []*evLayout{}
						for _, ev := range sm.events {
							if ev.Rest || ev.Voice != voice {
								continue
							}
							x := 0.0
							for _, slot := range col.slots {
								if slot.offset == ev.Offset {
									x = col.x + slot.x
									break
								}
							}
							entries = append(entries, ctx.place(mi, sm, sm.clef, ev, x, 1))
						}
						for _, g := range ctx.beamGroups(mi, entries) {
							ctx.c = newDrawing()
							ctx.beamDirection(g)
							indexes := []int{}
							for _, l := range g.evs {
								idx := 0
								for entries[idx] != l {
									idx++
								}
								indexes = append(indexes, idx)
								l.up = g.up
								l.beam = g
								ctx.arrange(l)
								ctx.stemBase(l)
							}
							ctx.drawBeam(g)
							y := []float64{}
							for _, l := range g.evs {
								y = append(y, l.stemY1)
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
								prims = append(prims, []any{int(p.kind), name, p.x, p.y, p.w, p.h, p.scale, outline})
							}
							out = append(out, []any{mi, si, voice, indexes, g.up, y, prims})
						}
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
	z := gzip.NewWriter(&compressed)
	if _, err = z.Write(b); err != nil {
		t.Fatal(err)
	}
	if err = z.Close(); err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/musicnotation/beams.json.gz"), compressed.Bytes(), 0644); err != nil {
		t.Fatal(err)
	}
}
