//go:build ignore

// Copy into upstream converter/internal/music and run TestCodexMusicStaff.
package music

import (
	"encoding/json"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexMusicStaff(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	type sample struct {
		Keys    []int `json:"keys"`
		Channel int   `json:"channel"`
		Program int   `json:"program"`
		Want    any   `json:"want"`
	}
	data := []sample{}
	r := rand.New(rand.NewSource(190374))
	for i := 0; i < 3000; i++ {
		ch := 0
		if r.Intn(8) == 0 {
			ch = 9
		}
		program := r.Intn(128)
		keys := []int{}
		seen := map[int]bool{}
		notes := []PlayNote{}
		for j := 0; j < 1+r.Intn(24); j++ {
			k := r.Intn(128)
			if seen[k] {
				continue
			}
			seen[k] = true
			keys = append(keys, k)
			notes = append(notes, PlayNote{Tick: 0, Dur: 960, Key: k, Vel: 100})
		}
		p := &Performance{Tracks: []*Track{{Name: "part", Channel: ch, Program: program, Notes: notes}}}
		s := Notate(p, NotateOptions{})
		part := s.Parts[0]
		clefs := [][2]int{}
		for _, c := range part.Measures[0].Clefs {
			clefs = append(clefs, [2]int{int(c.Clef.Sign), c.Clef.Octave})
		}
		data = append(data, sample{keys, ch, program, map[string]any{"percussion": part.Percussion, "clefs": clefs}})
	}
	drums := [][4]int{}
	for i := 0; i < 128; i++ {
		d := drumOf(i)
		drums = append(drums, [4]int{d.pitch.Step, d.pitch.Octave, int(d.head), d.voice})
	}
	out, err := json.Marshal(map[string]any{"staff": data, "drums": drums})
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/musicnotation/staff.json"), out, 0644); err != nil {
		t.Fatal(err)
	}
}
