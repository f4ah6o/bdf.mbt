//go:build ignore

// Copy into upstream converter/midi and run TestCodexMidiTrackNotes.
package midi

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexMidiTrackNotes(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	type fixture struct {
		Input   []byte `json:"input"`
		MaxTick int    `json:"maxTick"`
		Want    any    `json:"want"`
	}
	var data []fixture
	raw, err := os.ReadFile(filepath.Join(root, "compat/midiinput/tracks.json"))
	if err != nil {
		t.Fatal(err)
	}
	if err = json.Unmarshal(raw, &data); err != nil {
		t.Fatal(err)
	}
	for _, b := range [][]byte{
		{0, 0x90, 60, 100, 0, 0x90, 60, 80, 10, 0x80, 60, 0, 10, 0x80, 60, 0, 0, 0xff, 0x2f, 0},
		{0, 0x91, 70, 127, 0, 0x91, 40, 90, 10, 0xb1, 123, 0, 0, 0xff, 0x2f, 0},
		{0, 0xb0, 7, 80, 0, 0xb0, 10, 50, 0, 0xc0, 9, 0, 0xe0, 0, 64, 0, 0xff, 0x2f, 0},
		{0, 0x90, 0xfe, 0xff, 0, 0xff, 0x58, 2, 0, 9, 0, 0xff, 0x59, 2, 8, 0, 0, 0xf8, 0, 0xff, 0x2f, 0},
	} {
		data = append(data, fixture{Input: b, MaxTick: 100000})
	}
	for i := range data {
		f := &data[i]
		p := &parser{o: &Options{}, warned: map[string]bool{}, maxTick: int64(f.MaxTick)}
		c := &chunk{body: f.Input}
		err := p.readTrack(c)
		if err != nil {
			f.Want = map[string]any{"error": err.Error()}
			continue
		}
		notes := [][5]int64{}
		controls := [][5]int64{}
		for ch := 0; ch < 16; ch++ {
			for _, n := range c.notes[ch] {
				notes = append(notes, [5]int64{int64(ch), n.on, n.off, int64(n.key), int64(n.vel)})
			}
			for _, e := range c.controls[ch] {
				controls = append(controls, [5]int64{int64(ch), e.tick, int64(e.kind), int64(e.num), int64(e.value)})
			}
		}
		w := p.warnings
		if w == nil {
			w = []string{}
		}
		f.Want = map[string]any{"error": "", "notes": notes, "controls": controls, "warnings": w}
	}
	out, err := json.Marshal(data)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/midiinput/notes.json"), out, 0644); err != nil {
		t.Fatal(err)
	}
}
