//go:build ignore

// Copy into upstream converter/internal/music and run TestCodexMusicPrepare.
package music

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

type codexPart struct {
	Name       string              `json:"name"`
	Percussion bool                `json:"percussion"`
	Clefs      [][2]int            `json:"clefs"`
	Measures   [][]json.RawMessage `json:"measures"`
}
type codexScore struct {
	Measures [][]json.RawMessage `json:"measures"`
	Parts    []codexPart         `json:"parts"`
}
type codexFixture struct {
	Input []byte     `json:"input"`
	Want  codexScore `json:"want"`
}

func codexDecode[T any](raw json.RawMessage) T {
	var x T
	if err := json.Unmarshal(raw, &x); err != nil {
		panic(err)
	}
	return x
}
func codexScoreFromFixture(sample codexFixture) *Score {
	s := &Score{}
	for _, v := range sample.Want.Measures {
		m := &Measure{Length: codexDecode[int](v[0])}
		if string(v[1]) != "null" {
			x := codexDecode[[]any](v[1])
			m.Time = &TimeSig{Beats: int(x[0].(float64)), BeatType: int(x[1].(float64)), Symbol: x[2].(string)}
		}
		s.Measures = append(s.Measures, m)
	}
	for _, p := range sample.Want.Parts {
		part := &Part{Name: p.Name, Staves: len(p.Clefs), Percussion: p.Percussion}
		activeTime := TimeSig{Beats: 4, BeatType: 4}
		for mi, m := range p.Measures {
			if s.Measures[mi].Time != nil {
				activeTime = *s.Measures[mi].Time
			}
			beat, _ := activeTime.beat()
			tuplets := map[[3]int]*Tuplet{}
			pm := &PartMeasure{}
			if string(m[0]) != "null" {
				x := codexDecode[[]any](m[0])
				pm.Key = &KeySig{Fifths: int(x[0].(float64)), Minor: x[1].(bool)}
			}
			if mi == 0 {
				for st, c := range p.Clefs {
					pm.Clefs = append(pm.Clefs, ClefChange{Staff: st, Clef: Clef{Sign: ClefSign(c[0]), Octave: c[1]}})
				}
			}
			for _, ev := range codexDecode[[][]json.RawMessage](m[1]) {
				e := &Event{Offset: codexDecode[int](ev[0]), Duration: codexDecode[int](ev[1]), Staff: codexDecode[int](ev[2]), Voice: codexDecode[int](ev[3]), Type: NoteType(codexDecode[int](ev[4])), Dots: codexDecode[int](ev[5]), Rest: codexDecode[bool](ev[6]), MeasureRest: codexDecode[bool](ev[7])}
				if codexDecode[bool](ev[8]) {
					id := [3]int{e.Staff, e.Voice, e.Offset / max(beat, 1)}
					if tuplets[id] == nil {
						tuplets[id] = &Tuplet{Actual: 3, Normal: 2, ShowNumber: true}
					}
					e.Tuplet = tuplets[id]
				}
				for _, nn := range codexDecode[[][]json.RawMessage](ev[9]) {
					e.Notes = append(e.Notes, &Note{Pitch: Pitch{Step: codexDecode[int](nn[0]), Alter: codexDecode[int](nn[1]), Octave: codexDecode[int](nn[2])}, Head: Notehead(codexDecode[int](nn[3])), TieStart: codexDecode[bool](nn[4]), TieStop: codexDecode[bool](nn[5])})
				}
				if string(ev[10]) != "null" {
					item := codexDecode[[]any](ev[10])
					e.Lyrics = []*LyricSyllable{{Text: item[0].(string), Syllabic: Syllabic(int(item[1].(float64)))}}
				}
				pm.Events = append(pm.Events, e)
			}
			part.Measures = append(part.Measures, pm)
		}
		s.Parts = append(s.Parts, part)
	}
	return s
}
func TestCodexMusicPrepare(t *testing.T) {
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
		e := &engraver{s: s}
		e.prepare()
		staves := [][2]int{}
		for _, v := range e.staves {
			staves = append(staves, [2]int{v.part, v.staff})
		}
		times := [][2]int{}
		for _, v := range e.times {
			times = append(times, [2]int{v.Beats, v.BeatType})
		}
		rows := []any{}
		for _, row := range e.sm {
			r := []any{}
			for _, m := range row {
				events := [][4]any{}
				signs := []any{}
				for _, ev := range m.events {
					events = append(events, [4]any{ev.Offset, ev.Voice, ev.Rest, ev.MeasureRest})
					ss := []any{}
					for _, n := range ev.Notes {
						if a, ok := m.acc[n]; ok {
							ss = append(ss, int(a))
						} else {
							ss = append(ss, nil)
						}
					}
					signs = append(signs, ss)
				}
				r = append(r, map[string]any{"clef": [3]int{int(m.clef.Sign), m.clef.Line, m.clef.Octave}, "clefChange": m.clefChange, "key": []any{m.key.Fifths, m.key.Minor}, "previousKey": []any{m.prevKey.Fifths, m.prevKey.Minor}, "keyChange": m.keyChange, "events": events, "signs": signs, "voices": m.voices})
			}
			rows = append(rows, r)
		}
		output = append(output, map[string]any{"input": sample.Input, "want": map[string]any{"staves": staves, "grand": e.grand, "starts": e.starts, "times": times, "counts": e.counts, "measures": rows}})
	}
	b, err := json.Marshal(output)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/musicnotation/prepare.json"), b, 0644); err != nil {
		t.Fatal(err)
	}
}
