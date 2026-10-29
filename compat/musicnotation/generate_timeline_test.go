//go:build ignore

// Copy into upstream converter/internal/music and run TestCodexMusicTimeline.
package music

import (
	"encoding/json"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexMusicTimeline(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	type sample struct {
		End          int         `json:"end"`
		Times        []int       `json:"times"`
		Keys         []int       `json:"keys"`
		Tempos       []float64   `json:"tempos"`
		Histogram    [12]float64 `json:"histogram"`
		TimeOverride []int       `json:"timeOverride"`
		KeyOverride  []int       `json:"keyOverride"`
		Want         any         `json:"want"`
	}
	samples := []sample{}
	r := rand.New(rand.NewSource(199320))
	for i := 0; i < 1200; i++ {
		end := 1 + r.Intn(30000)
		p := &Performance{Tracks: []*Track{{Channel: 0, Notes: []PlayNote{{Tick: 0, Dur: end, Key: 60, Vel: 100}}}}, End: end}
		o := NotateOptions{}
		x := sample{End: end, Times: []int{}, Keys: []int{}, Tempos: []float64{}, TimeOverride: []int{}, KeyOverride: []int{}}
		x.Histogram[0] = float64(end)
		for j := 0; j < r.Intn(6); j++ {
			tick := r.Intn(end + 1000)
			beats := r.Intn(9)
			bt := []int{0, 1, 2, 4, 8, 16}[r.Intn(6)]
			p.Time = append(p.Time, TimeChange{Tick: tick, Time: TimeSig{Beats: beats, BeatType: bt}})
			x.Times = append(x.Times, tick, beats, bt)
		}
		for j := 0; j < r.Intn(5); j++ {
			tick := r.Intn(end + 1000)
			fifths := r.Intn(21) - 10
			minor := r.Intn(2)
			p.Key = append(p.Key, KeyChange{Tick: tick, Key: KeySig{Fifths: fifths, Minor: minor != 0}})
			x.Keys = append(x.Keys, tick, fifths, minor)
		}
		for j := 0; j < r.Intn(7); j++ {
			tick := r.Intn(end + 1000)
			bpm := float64(r.Intn(250))
			p.Tempo = append(p.Tempo, Tempo{Tick: tick, BPM: bpm})
			x.Tempos = append(x.Tempos, float64(tick), bpm)
		}
		if r.Intn(5) == 0 {
			b := 1 + r.Intn(9)
			d := []int{2, 4, 8, 16}[r.Intn(4)]
			o.Time = &TimeSig{Beats: b, BeatType: d}
			x.TimeOverride = []int{b, d}
		}
		if r.Intn(5) == 0 {
			f := r.Intn(19) - 9
			m := r.Intn(2)
			o.Key = &KeySig{Fifths: f, Minor: m != 0}
			x.KeyOverride = []int{f, m}
		}
		score := Notate(p, o)
		spans := []any{}
		start := 0
		current := TimeSig{Beats: 4, BeatType: 4}
		active := KeySig{}
		for m, measure := range score.Measures {
			if measure.Time != nil {
				current = *measure.Time
			}
			var k any
			if score.Parts[0].Measures[m].Key != nil {
				v := *score.Parts[0].Measures[m].Key
				k = []any{v.Fifths, v.Minor}
				active = v
			}
			marks := [][3]any{}
			for _, v := range measure.Tempo {
				marks = append(marks, [3]any{v.Offset, v.Dots, v.PerMinute})
			}
			spans = append(spans, map[string]any{"start": start, "length": measure.Length, "time": []int{current.Beats, current.BeatType}, "showTime": measure.Time != nil, "key": k, "effectiveKey": []any{active.Fifths, active.Minor}, "tempos": marks})
			start += measure.Length
		}
		w := score.warnings
		if w == nil {
			w = []string{}
		}
		x.Want = map[string]any{"measures": spans, "warnings": w}
		samples = append(samples, x)
	}
	out, err := json.Marshal(samples)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/musicnotation/timeline.json"), out, 0644); err != nil {
		t.Fatal(err)
	}
}
