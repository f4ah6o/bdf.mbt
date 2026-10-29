//go:build ignore

// Copy into upstream converter/internal/music and run TestCodexMusicVoices.
package music

import (
	"encoding/json"
	"math/rand"
	"os"
	"path/filepath"
	"sort"
	"testing"
)

// This copies the grouping stage of staffNotator.run and calls its actual
// swapVoices method. The downstream event construction is tested separately.
func fixtureVoices(notes []qnote, spans []measureSpan, beats []beatGrid, percussion bool) [2][]*chord {
	for i := range notes {
		if percussion {
			break
		}
		q := &notes[i]
		for k := i + 1; k < len(notes); k++ {
			if notes[k].on > q.on {
				if over := q.off - notes[k].on; over > 0 && over <= max(gridAt(beats, q.on).grid, (q.off-q.on)/4) {
					q.off = notes[k].on
				}
				break
			}
		}
	}
	var chords []*chord
	for _, q := range notes {
		if len(chords) > 0 {
			c := chords[len(chords)-1]
			if c.on == q.on && c.off == q.off && c.notes[0].voiceHint == q.voiceHint {
				c.notes = append(c.notes, q)
				continue
			}
		}
		chords = append(chords, &chord{on: q.on, off: q.off, notes: []qnote{q}})
	}
	var voices [2][]*chord
	var busy [2]int
	for _, c := range chords {
		pref := []int{0, 1}
		if c.notes[0].voiceHint == 2 {
			pref = []int{1, 0}
		}
		placed := false
		for _, v := range pref {
			if busy[v] <= c.on {
				voices[v] = append(voices[v], c)
				busy[v] = c.off
				placed = true
				break
			}
		}
		if placed {
			continue
		}
		joined := false
		for v := range voices {
			if k := len(voices[v]); k > 0 && voices[v][k-1].on == c.on {
				last := voices[v][k-1]
				last.notes = append(last.notes, c.notes...)
				last.off = max(last.off, c.off)
				busy[v] = last.off
				joined = true
				break
			}
		}
		if joined {
			continue
		}
		v := pref[0]
		k := len(voices[v])
		voices[v][k-1].off = c.on
		voices[v] = append(voices[v], c)
		busy[v] = c.off
	}
	n := &staffNotator{spans: spans, percussion: percussion, measureAt: func(tick int) int {
		return max(sort.Search(len(spans), func(i int) bool { return spans[i].start > tick })-1, 0)
	}}
	n.swapVoices(&voices)
	return voices
}
func TestCodexMusicVoices(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	type sample struct {
		Measures   []int `json:"measures"`
		Beats      []int `json:"beats"`
		Notes      []int `json:"notes"`
		Percussion bool  `json:"percussion"`
		Want       any   `json:"want"`
	}
	samples := []sample{}
	r := rand.New(rand.NewSource(199522))
	for i := 0; i < 3000; i++ {
		spans := []measureSpan{{start: 0, length: 3840}, {start: 3840, length: 3840}}
		bs := []beatGrid{}
		rawbeats := []int{}
		for j := 0; j < 8; j++ {
			grid := []int{80, 120, 160, 240, 320, 480}[r.Intn(6)]
			bs = append(bs, beatGrid{start: j * 960, length: 960, grid: grid})
			rawbeats = append(rawbeats, j*960, 960, grid)
		}
		notes := []qnote{}
		for j := 0; j < r.Intn(30); j++ {
			on := r.Intn(24) * 240
			notes = append(notes, qnote{on: on, off: on + 240 + r.Intn(12)*120, key: r.Intn(128), vel: r.Intn(128), spell: r.Intn(3) - 1, voiceHint: r.Intn(3)})
		}
		sort.SliceStable(notes, func(i, j int) bool {
			if notes[i].on != notes[j].on {
				return notes[i].on < notes[j].on
			}
			return notes[i].key > notes[j].key
		})
		raw := []int{}
		for _, n := range notes {
			raw = append(raw, n.on, n.off, n.key, n.vel, n.spell, n.voiceHint)
		}
		percussion := r.Intn(2) == 0
		voices := fixtureVoices(notes, spans, bs, percussion)
		out := []any{}
		for _, voice := range voices {
			chords := []any{}
			for _, c := range voice {
				nn := [][6]int{}
				for _, n := range c.notes {
					nn = append(nn, [6]int{n.on, n.off, n.key, n.vel, n.spell, n.voiceHint})
				}
				chords = append(chords, []any{c.on, c.off, nn})
			}
			out = append(out, chords)
		}
		samples = append(samples, sample{[]int{0, 3840, 3840, 3840}, rawbeats, raw, percussion, out})
	}
	out, err := json.Marshal(samples)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/musicnotation/voices.json"), out, 0644); err != nil {
		t.Fatal(err)
	}
}
