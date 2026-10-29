//go:build ignore

// Copy alongside generate_prepare_test.go into upstream converter/internal/music.
package music

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/shibukawa/bdf/converter/internal/fontset"
	"github.com/shibukawa/bdf/internal/fontdb"
)

func TestCodexMusicSystems(t *testing.T) {
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
		e := &engraver{s: s, sp: defaultSp, text: &texter{set: fontset.New(fontdb.New(nil, nil, false), func(string) {})}}
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
			cols := []any{}
			for m := sys.first; m <= sys.last; m++ {
				c := e.cols[m]
				slots := []float64{}
				for _, slot := range c.slots {
					slots = append(slots, slot.x)
				}
				cols = append(cols, []any{m, c.x, c.width, c.bodyStart, slots})
			}
			out = append(out, []any{sys.first, sys.last, sys.header, sys.width, cols})
		}
		output = append(output, map[string]any{"input": sample.Input, "widths": widths, "width": width, "indent": indent, "want": out})
	}
	b, err := json.Marshal(output)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/musicnotation/systems.json"), b, 0644); err != nil {
		t.Fatal(err)
	}
}
