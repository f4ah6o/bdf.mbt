//go:build ignore

// Copy into upstream converter/midi and run TestCodexMidiTrackScan.
package midi

import (
	"encoding/json"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexMidiTrackScan(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	type fixture struct {
		Input   []byte `json:"input"`
		MaxTick int    `json:"maxTick"`
		Want    any    `json:"want"`
	}
	data := []fixture{}
	add := func(b []byte, max int) {
		p := &parser{o: &Options{}, warned: map[string]bool{}, maxTick: int64(max)}
		c := &chunk{index: 0, body: b}
		if err := p.readTrack(c); err != nil {
			t.Fatal(err)
		}
		problem := ""
		if p.warned["long"] {
			problem = "long"
		} else if p.warned["damaged"] {
			for _, w := range p.warnings {
				switch w {
				case "track 1 is damaged (a data byte without a status); it is read up to the damage":
					problem = "a data byte without a status"
				case "track 1 is damaged (a delta time longer than 4 bytes); it is read up to the damage":
					problem = "a delta time longer than 4 bytes"
				}
			}
		}
		data = append(data, fixture{b, max, map[string]any{"parsed": c.parsed, "sawEnd": c.sawEnd, "damaged": c.damaged, "endTick": c.end, "problem": problem}})
	}
	samples := [][]byte{
		{}, {0, 0xff, 0x2f, 0}, {0, 0x90, 60, 100, 0x60, 60, 0, 0, 0xff, 0x2f, 0},
		{0, 0x90, 60, 100, 0, 0xf0, 1, 0x7f, 0, 60, 0, 0, 0xff, 0x2f, 0},
		{0, 0xc0, 2, 0, 3, 0, 0xff, 3, 1, 'x', 0, 4, 0, 0xff, 0x2f, 0},
		{0, 0xf1, 7, 0, 0xf2, 1, 2, 0, 0xf8, 0, 0xff, 0x2f, 0},
		{0x81, 0x80, 0x80, 0x80, 0}, {0, 60}, {0, 0xff, 0x2f, 4, 1, 2},
	}
	for _, b := range samples {
		for i := 0; i <= len(b); i++ {
			add(b[:i], 100000)
		}
		add(b, 0)
	}
	r := rand.New(rand.NewSource(7150))
	base := []byte{0, 0x90, 60, 100, 0x83, 0x60, 0x80, 60, 0, 0, 0xff, 3, 4, 'n', 'a', 'm', 'e', 0, 0xf0, 2, 1, 2, 0, 0xff, 0x2f, 0}
	for i := 0; i < 6000; i++ {
		b := append([]byte(nil), base...)
		for j := 0; j < 1+r.Intn(6); j++ {
			b[r.Intn(len(b))] = byte(r.Intn(256))
		}
		if r.Intn(5) == 0 {
			b = b[:r.Intn(len(b)+1)]
		}
		max := 100000
		if r.Intn(10) == 0 {
			max = r.Intn(1000)
		}
		add(b, max)
	}
	for i := 0; i < 2000; i++ {
		b := make([]byte, r.Intn(50))
		r.Read(b)
		add(b, 100000)
	}
	out, err := json.Marshal(data)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/midiinput/tracks.json"), out, 0644); err != nil {
		t.Fatal(err)
	}
}
