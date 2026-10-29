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

func TestCodexMusicColumns(t *testing.T) {
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
	for _, sample := range prior {
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
		cols := []any{}
		for _, c := range e.cols {
			slots := [][8]any{}
			for _, sl := range c.slots {
				slots = append(slots, [8]any{sl.offset, sl.dur, sl.pre, sl.head, sl.post, sl.lyric, sl.ideal, sl.min})
			}
			cols = append(cols, map[string]any{"header": c.header, "lead": c.lead, "slots": slots})
		}
		output = append(output, map[string]any{"input": sample.Input, "widths": widths, "want": cols})
	}
	b, err := json.Marshal(output)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/musicnotation/columns.json"), b, 0644); err != nil {
		t.Fatal(err)
	}
}
