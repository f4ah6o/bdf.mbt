//go:build ignore

// Copy into upstream converter/internal/music and run TestCodexMusicEvents.
package music

import (
	"encoding/json"
	"math/rand"
	"os"
	"path/filepath"
	"sort"
	"testing"
)

func TestCodexMusicEvents(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	type sample struct {
		Measures   []int    `json:"measures"`
		Beats      []int    `json:"beats"`
		Notes      []int    `json:"notes"`
		LyricTicks []int    `json:"lyricTicks"`
		LyricTexts []string `json:"lyricTexts"`
		Staff      int      `json:"staff"`
		Percussion bool     `json:"percussion"`
		Want       any      `json:"want"`
	}
	samples := []sample{}
	r := rand.New(rand.NewSource(66433))
	words := []string{"a", "Twin-", "kle", "/hey", "あ", " x ", ""}
	for i := 0; i < 2400; i++ {
		times := []TimeSig{{Beats: 4, BeatType: 4}, {Beats: 4, BeatType: 4}}
		if i%3 == 0 {
			times[1] = TimeSig{Beats: 6, BeatType: 8}
		}
		spans := []measureSpan{{start: 0, length: 3840, time: times[0]}, {start: 3840, length: times[1].Length(), time: times[1]}}
		end := 3840 + times[1].Length()
		ks := []KeySig{{Fifths: r.Intn(15) - 7, Minor: r.Intn(2) == 0}, {Fifths: r.Intn(15) - 7, Minor: r.Intn(2) == 0}}
		ms := []int{}
		for j, sp := range spans {
			minor := 0
			if ks[j].Minor {
				minor = 1
			}
			ms = append(ms, sp.start, sp.length, sp.time.Beats, sp.time.BeatType, ks[j].Fifths, minor)
		}
		beats := []beatGrid{}
		bs := []int{}
		for _, sp := range spans {
			length, compound := sp.time.beat()
			for start := sp.start; start < sp.start+sp.length; start += length {
				trip := !compound && r.Intn(3) == 0
				grid := length / 2
				if trip || compound {
					grid = length / 3
				}
				beat := beatGrid{start: start, length: min(length, sp.start+sp.length-start), grid: grid, compound: compound, triplet: trip}
				beats = append(beats, beat)
				cp, tp := 0, 0
				if compound {
					cp = 1
				}
				if trip {
					tp = 1
				}
				bs = append(bs, beat.start, beat.length, beat.grid, cp, tp)
			}
		}
		percussion := r.Intn(4) == 0
		staff := r.Intn(2)
		notes := []qnote{}
		count := r.Intn(14)
		if i >= 2000 {
			count = 20 + r.Intn(45)
		}
		for j := 0; j < count; j++ {
			on := r.Intn(end/240) * 240
			off := min(on+(1+r.Intn(8))*240, end)
			key := 40 + r.Intn(50)
			q := qnote{on: on, off: off, key: key, vel: 90, spell: r.Intn(3) - 1}
			if percussion {
				d := drumOf(key)
				q.pitch = &d.pitch
				q.head = d.head
				q.voiceHint = d.voice
			}
			notes = append(notes, q)
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
		lyricTicks := []int{}
		lyricTexts := []string{}
		lyricMap := map[int]string{}
		for j := 0; j < r.Intn(6); j++ {
			tick := r.Intn(end/240) * 240
			text := words[r.Intn(len(words))]
			lyricTicks = append(lyricTicks, tick)
			lyricTexts = append(lyricTexts, text)
			on := gridAt(beats, tick).snap(tick)
			lyricMap[on] += text
		}
		part := &Part{Measures: []*PartMeasure{{}, {}}}
		n := &staffNotator{part: part, staff: staff, spans: spans, beats: beats, keys: ks, measureAt: func(tick int) int {
			return max(sort.Search(len(spans), func(i int) bool { return spans[i].start > tick })-1, 0)
		}, lyrics: lyricMap, percussion: percussion}
		n.run(notes, end)
		all := []any{}
		for m, pm := range part.Measures {
			evs := []any{}
			for _, e := range pm.Events {
				var tup any
				if e.Tuplet != nil {
					tup = gridAt(beats, spans[m].start+e.Offset).start
				}
				ns := [][6]any{}
				for _, note := range e.Notes {
					ns = append(ns, [6]any{note.Pitch.Step, note.Pitch.Alter, note.Pitch.Octave, int(note.Head), note.TieStart, note.TieStop})
				}
				var ly any
				if len(e.Lyrics) > 0 {
					ly = []any{e.Lyrics[0].Text, int(e.Lyrics[0].Syllabic)}
				}
				evs = append(evs, []any{e.Offset, e.Duration, e.Staff, e.Voice, int(e.Type), e.Dots, e.Rest, e.MeasureRest, tup, ns, ly})
			}
			all = append(all, evs)
		}
		samples = append(samples, sample{ms, bs, raw, lyricTicks, lyricTexts, staff, percussion, all})
	}
	out, err := json.Marshal(samples)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/musicnotation/events.json"), out, 0644); err != nil {
		t.Fatal(err)
	}
}
