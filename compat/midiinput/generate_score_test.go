//go:build ignore

// Copy into upstream converter/midi and run TestCodexMidiScore.
package midi

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/shibukawa/bdf/converter/internal/music"
)

func TestCodexMidiScore(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	type fixture struct {
		Input []byte `json:"input"`
		Want  any    `json:"want"`
	}
	data := []fixture{}
	add := func(file []byte) {
		p, err := Parse(file, nil)
		if err != nil {
			t.Fatal(err)
		}
		s := music.Notate(p.Perf, music.NotateOptions{})
		measures := []any{}
		for _, m := range s.Measures {
			var time any
			if m.Time != nil {
				time = []any{m.Time.Beats, m.Time.BeatType, m.Time.Symbol}
			}
			tempos := [][3]any{}
			for _, t := range m.Tempo {
				tempos = append(tempos, [3]any{t.Offset, t.Dots, t.PerMinute})
			}
			measures = append(measures, []any{m.Length, time, tempos})
		}
		parts := []any{}
		for _, part := range s.Parts {
			clefs := [][2]int{}
			for _, c := range part.Measures[0].Clefs {
				clefs = append(clefs, [2]int{int(c.Clef.Sign), c.Clef.Octave})
			}
			pms := []any{}
			for _, m := range part.Measures {
				var key any
				if m.Key != nil {
					key = []any{m.Key.Fifths, m.Key.Minor}
				}
				events := []any{}
				for _, e := range m.Events {
					notes := [][6]any{}
					for _, n := range e.Notes {
						notes = append(notes, [6]any{n.Pitch.Step, n.Pitch.Alter, n.Pitch.Octave, int(n.Head), n.TieStart, n.TieStop})
					}
					var lyric any
					if len(e.Lyrics) > 0 {
						lyric = []any{e.Lyrics[0].Text, int(e.Lyrics[0].Syllabic)}
					}
					events = append(events, []any{e.Offset, e.Duration, e.Staff, e.Voice, int(e.Type), e.Dots, e.Rest, e.MeasureRest, e.Tuplet != nil, notes, lyric})
				}
				pms = append(pms, []any{key, events})
			}
			parts = append(parts, map[string]any{"name": part.Name, "percussion": part.Percussion, "clefs": clefs, "measures": pms})
		}
		data = append(data, fixture{file, map[string]any{"title": s.Title, "composer": s.Composer, "lyricist": s.Lyricist, "arranger": s.Arranger, "copyright": s.Rights, "error": "", "warnings": []string{}, "measures": measures, "parts": parts}})
	}
	for _, name := range []string{"twinkle.kar", "twinkle.mid", "ode.mid", "ode.rmi"} {
		file, err := os.ReadFile(filepath.Join("testdata", name))
		if err != nil {
			t.Fatal(err)
		}
		add(file)
	}
	for _, source := range []string{"performance.json", "lyrics.json"} {
		var prior []fixture
		b, err := os.ReadFile(filepath.Join(root, "compat/midiinput", source))
		if err != nil {
			t.Fatal(err)
		}
		if err = json.Unmarshal(b, &prior); err != nil {
			t.Fatal(err)
		}
		for i, f := range prior {
			if i%8 == 0 {
				add(f.Input)
			}
		}
	}
	out, err := json.Marshal(data)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/midiinput/score.json"), out, 0644); err != nil {
		t.Fatal(err)
	}
}
