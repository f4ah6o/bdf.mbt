//go:build ignore

// Copy into upstream converter/midi and run TestCodexMidiTrackMeta.
package midi

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexMidiTrackMeta(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	type fixture struct {
		Input []byte `json:"input"`
		Want  any    `json:"want"`
	}
	data := []fixture{}
	add := func(b []byte) {
		p := &parser{o: &Options{}, warned: map[string]bool{}, maxTick: 1000000}
		c := &chunk{body: b}
		if err := p.readTrack(c); err != nil {
			t.Fatal(err)
		}
		channels := []string{}
		for _, v := range c.chanNames {
			channels = append(channels, fmt.Sprintf("%x", v))
		}
		texts := [][3]any{}
		for _, v := range c.texts {
			texts = append(texts, [3]any{v.tick, v.typ, fmt.Sprintf("%x", v.data)})
		}
		tempos := [][2]any{}
		for _, v := range c.tempo {
			tempos = append(tempos, [2]any{v.tick, v.v})
		}
		times := [][3]any{}
		for _, v := range c.times {
			times = append(times, [3]any{v.tick, v.v.Beats, v.v.BeatType})
		}
		keys := [][3]any{}
		for _, v := range c.keys {
			keys = append(keys, [3]any{v.tick, v.v.Fifths, v.v.Minor})
		}
		w := p.warnings
		if w == nil {
			w = []string{}
		}
		data = append(data, fixture{b, map[string]any{"name": fmt.Sprintf("%x", c.name), "instrument": fmt.Sprintf("%x", c.instrument), "copyright": fmt.Sprintf("%x", c.copyright), "channels": channels, "texts": texts, "tempos": tempos, "times": times, "keys": keys, "warnings": w}})
	}
	r := rand.New(rand.NewSource(91313))
	kinds := []byte{1, 2, 3, 4, 5, 0x20, 0x51, 0x58, 0x59, 0x7f}
	for i := 0; i < 3000; i++ {
		b := []byte{}
		for j := 0; j < 20; j++ {
			switch r.Intn(12) {
			case 0:
				b = append(b, byte(r.Intn(10)), 0xc0, byte(r.Intn(128)))
			case 1:
				b = append(b, byte(r.Intn(10)), 0xf0, 1, 0x7f)
			default:
				kind := kinds[r.Intn(len(kinds))]
				var payload []byte
				if kind == 0x51 {
					payload = make([]byte, 3)
					r.Read(payload)
				} else {
					payload = make([]byte, r.Intn(6))
					r.Read(payload)
					if kind == 0x58 && r.Intn(2) == 0 {
						payload = []byte{byte(1 + r.Intn(12)), byte(r.Intn(8))}
					}
					if kind == 0x59 && r.Intn(2) == 0 {
						payload = []byte{byte(int8(r.Intn(19) - 9)), byte(r.Intn(3))}
					}
				}
				b = append(b, byte(r.Intn(10)), 0xff, kind, byte(len(payload)))
				b = append(b, payload...)
			}
		}
		b = append(b, 0, 0xff, 0x2f, 0)
		add(b)
	}
	out, err := json.Marshal(data)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/midiinput/meta.json"), out, 0644); err != nil {
		t.Fatal(err)
	}
}
