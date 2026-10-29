//go:build ignore

// Copy into upstream converter/internal/music and run TestCodexMusicQuantize.
package music

import (
	"encoding/json"
	"math/rand"
	"os"
	"path/filepath"
	"slices"
	"sort"
	"testing"
)

func TestCodexMusicQuantize(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	type sample struct {
		Measures []int `json:"measures"`
		Notes    []int `json:"notes"`
		Want     any   `json:"want"`
	}
	samples := []sample{}
	r := rand.New(rand.NewSource(112633))
	for i := 0; i < 3000; i++ {
		var spans []measureSpan
		input := sample{Measures: []int{}, Notes: []int{}}
		start := 0
		for j := 0; j < 1+r.Intn(4); j++ {
			beats := 1 + r.Intn(9)
			beatType := []int{2, 4, 8, 16}[r.Intn(4)]
			tm := TimeSig{Beats: beats, BeatType: beatType}
			length := tm.Length()
			if r.Intn(4) == 0 {
				length = 1 + r.Intn(length)
			}
			spans = append(spans, measureSpan{start: start, length: length, time: tm})
			input.Measures = append(input.Measures, start, length, beats, beatType)
			start += length
		}
		notes := []PlayNote{}
		onsets := []int{}
		for j := 0; j < r.Intn(35); j++ {
			tick := r.Intn(start+300) - 100
			dur := r.Intn(3000)
			key := r.Intn(135) - 3
			vel := r.Intn(128)
			spell := r.Intn(3) - 1
			notes = append(notes, PlayNote{Tick: tick, Dur: dur, Key: key, Vel: vel, Spell: spell})
			input.Notes = append(input.Notes, tick, dur, key, vel, spell)
			onsets = append(onsets, tick)
		}
		beats := grids(spans, onsets)
		b := [][5]any{}
		for _, v := range beats {
			b = append(b, [5]any{v.start, v.length, v.compound, v.grid, v.triplet})
		}
		end := start
		q := []qnote{}
		for _, n := range notes {
			if n.Tick >= end || n.Key < 0 || n.Key > 127 {
				continue
			}
			on := gridAt(beats, n.Tick).snap(n.Tick)
			off := gridAt(beats, n.Tick+max(n.Dur, 1)).snap(n.Tick + max(n.Dur, 1))
			if off <= on {
				off = on + max(gridAt(beats, on).grid, 1)
			}
			off = min(off, end)
			if on >= end {
				continue
			}
			q = append(q, qnote{on: on, off: off, key: n.Key, vel: n.Vel, spell: n.Spell})
		}
		sort.SliceStable(q, func(i, j int) bool {
			if q[i].on != q[j].on {
				return q[i].on < q[j].on
			}
			return q[i].key > q[j].key
		})
		q = slices.CompactFunc(q, func(a, b qnote) bool { return a.on == b.on && a.key == b.key })
		out := [][5]int{}
		for _, n := range q {
			out = append(out, [5]int{n.on, n.off, n.key, n.vel, n.spell})
		}
		input.Want = map[string]any{"beats": b, "notes": out}
		samples = append(samples, input)
	}
	out, err := json.Marshal(samples)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/musicnotation/quantize.json"), out, 0644); err != nil {
		t.Fatal(err)
	}
}
