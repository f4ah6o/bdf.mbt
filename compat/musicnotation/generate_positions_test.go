//go:build ignore

// Copy into upstream converter/internal/music and run TestCodexMusicPositions.
package music

import (
	"encoding/json"
	"math/rand"
	"os"
	"path/filepath"
	"sort"
	"testing"
)

func TestCodexMusicPositions(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	type sample struct {
		Fifths int   `json:"fifths"`
		Sign   int   `json:"sign"`
		Line   int   `json:"line"`
		Octave int   `json:"octave"`
		Events []int `json:"events"`
		Notes  []int `json:"notes"`
		Want   any   `json:"want"`
	}
	data := []sample{}
	r := rand.New(rand.NewSource(718291))
	for i := 0; i < 3000; i++ {
		key := KeySig{Fifths: r.Intn(19) - 9}
		clef := Clef{Sign: ClefSign(r.Intn(5)), Line: r.Intn(6), Octave: r.Intn(5) - 2}
		events := []*Event{}
		rawEvents := []int{}
		rawNotes := []int{}
		count := 0
		for j := 0; j < 1+r.Intn(12); j++ {
			e := &Event{Offset: r.Intn(10) * 120, Voice: 1 + r.Intn(2), Grace: r.Intn(3) == 0}
			start := count
			for n := 0; n < 1+r.Intn(5); n++ {
				p := Pitch{Step: r.Intn(7), Alter: r.Intn(5) - 2, Octave: 2 + r.Intn(5)}
				acc := Accidental(r.Intn(7))
				caution := r.Intn(5) == 0
				tie := r.Intn(5) == 0
				e.Notes = append(e.Notes, &Note{Pitch: p, Accidental: acc, Cautionary: caution, TieStop: tie})
				c, tieI := 0, 0
				if caution {
					c = 1
				}
				if tie {
					tieI = 1
				}
				rawNotes = append(rawNotes, p.Step, p.Alter, p.Octave, int(acc), c, tieI)
				count++
			}
			grace := 0
			if e.Grace {
				grace = 1
			}
			rawEvents = append(rawEvents, e.Offset, e.Voice, grace, start, count)
			events = append(events, e)
		}
		ordered := append([]*Event(nil), events...)
		sort.SliceStable(ordered, func(i, j int) bool {
			a, b := ordered[i], ordered[j]
			if a.Offset != b.Offset {
				return a.Offset < b.Offset
			}
			if a.Grace != b.Grace {
				return a.Grace
			}
			return a.Voice < b.Voice
		})
		sm := &staffMeasure{key: key, clef: clef, events: ordered, acc: map[*Note]Accidental{}}
		(&engraver{}).accidentals(sm)
		signs := []any{}
		positions := []any{}
		placements := []any{}
		for _, e := range events {
			ss := []any{}
			pp := []int{}
			for _, n := range e.Notes {
				if a, ok := sm.acc[n]; ok {
					ss = append(ss, int(a))
				} else {
					ss = append(ss, nil)
				}
				pp = append(pp, staffPos(clef, n.Pitch))
			}
			placed := [][4]int{}
			for _, a := range placeAccidentals(sm, e) {
				idx := 0
				for e.Notes[idx] != a.note {
					idx++
				}
				placed = append(placed, [4]int{idx, int(a.acc), a.pos, a.col})
			}
			signs = append(signs, ss)
			positions = append(positions, pp)
			placements = append(placements, placed)
		}
		kp := keyPositions(clef, key)
		if kp == nil {
			kp = []int{}
		}
		alters := keyAlters(key)
		data = append(data, sample{key.Fifths, int(clef.Sign), clef.Line, clef.Octave, rawEvents, rawNotes, map[string]any{"signs": signs, "positions": positions, "placements": placements, "keyPositions": kp, "keyAlters": alters}})
	}
	out, err := json.Marshal(data)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/musicnotation/positions.json"), out, 0644); err != nil {
		t.Fatal(err)
	}
}
