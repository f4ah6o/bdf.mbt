//go:build ignore

// Copy into upstream converter/internal/music and run TestCodexMusicKeys.
package music

import (
	"encoding/json"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexMusicKeys(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	type spelling struct {
		Key    int    `json:"key"`
		Fifths int    `json:"fifths"`
		Minor  bool   `json:"minor"`
		Hint   int    `json:"hint"`
		Want   [3]int `json:"want"`
	}
	type estimate struct {
		Hist  [12]float64 `json:"hist"`
		Flats int         `json:"flats"`
		Want  [2]any      `json:"want"`
	}
	type meter struct {
		Beats    int    `json:"beats"`
		BeatType int    `json:"beatType"`
		Want     [3]any `json:"want"`
	}
	spells := []spelling{}
	for key := -25; key <= 140; key++ {
		for fifths := -7; fifths <= 7; fifths++ {
			for _, minor := range []bool{false, true} {
				for hint := -1; hint <= 1; hint++ {
					p := spell(key, KeySig{Fifths: fifths, Minor: minor}, hint)
					spells = append(spells, spelling{key, fifths, minor, hint, [3]int{p.Step, p.Alter, p.Octave}})
				}
			}
		}
	}
	estimates := []estimate{}
	r := rand.New(rand.NewSource(91786))
	for i := 0; i < 5000; i++ {
		var h [12]float64
		for j := range h {
			h[j] = float64(r.Intn(10000))
			if r.Intn(3) == 0 {
				h[j] = 0
			}
		}
		if i == 0 {
			h = [12]float64{}
		}
		flats := r.Intn(5) - 2
		k := estimateKey(h, flats)
		estimates = append(estimates, estimate{h, flats, [2]any{k.Fifths, k.Minor}})
	}
	meters := []meter{}
	for beats := -1; beats <= 24; beats++ {
		for _, d := range []int{-1, 0, 1, 2, 4, 8, 16, 32, 64} {
			s := TimeSig{Beats: beats, BeatType: d}
			beat, compound := s.beat()
			meters = append(meters, meter{beats, d, [3]any{s.Length(), beat, compound}})
		}
	}
	out, err := json.Marshal(map[string]any{"spelling": spells, "estimate": estimates, "meter": meters})
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/musicnotation/upstream.json"), out, 0644); err != nil {
		t.Fatal(err)
	}
}
