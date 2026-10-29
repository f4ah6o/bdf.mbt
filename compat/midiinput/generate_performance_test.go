//go:build ignore

// Copy into upstream converter/midi and run TestCodexMidiPerformance.
package midi

import (
	"encoding/binary"
	"encoding/json"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexMidiPerformance(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	type fixture struct {
		Input []byte `json:"input"`
		Want  any    `json:"want"`
	}
	data := []fixture{}
	add := func(file []byte) {
		result, err := Parse(file, nil)
		if err != nil {
			t.Fatal(err)
		}
		p := result.Perf
		tracks := []any{}
		for _, tr := range p.Tracks {
			notes := [][4]int{}
			for _, n := range tr.Notes {
				notes = append(notes, [4]int{n.Tick, n.Dur, n.Key, n.Vel})
			}
			controls := [][4]int{}
			for _, c := range tr.Controls {
				controls = append(controls, [4]int{c.Tick, int(c.Kind), c.Num, c.Value})
			}
			tracks = append(tracks, map[string]any{"name": tr.Name, "channel": tr.Channel, "program": tr.Program, "volume": tr.Volume, "pan": tr.Pan, "notes": notes, "controls": controls})
		}
		tempos := [][2]any{}
		for _, v := range p.Tempo {
			tempos = append(tempos, [2]any{v.Tick, v.BPM})
		}
		times := [][3]int{}
		for _, v := range p.Time {
			times = append(times, [3]int{v.Tick, v.Time.Beats, v.Time.BeatType})
		}
		keys := [][3]any{}
		for _, v := range p.Key {
			keys = append(keys, [3]any{v.Tick, v.Key.Fifths, v.Key.Minor})
		}
		w := result.Warnings
		if w == nil {
			w = []string{}
		}
		data = append(data, fixture{file, map[string]any{"tracks": tracks, "end": p.End, "division": p.Division, "warnings": w, "tempos": tempos, "times": times, "keys": keys}})
	}
	var previous []fixture
	raw, err := os.ReadFile(filepath.Join(root, "compat/midiinput/credits.json"))
	if err != nil {
		t.Fatal(err)
	}
	if err = json.Unmarshal(raw, &previous); err != nil {
		t.Fatal(err)
	}
	for _, f := range previous {
		add(f.Input)
	}
	rng := rand.New(rand.NewSource(22112))
	for i := 0; i < 1500; i++ {
		count := 1 + rng.Intn(3)
		divisions := []uint16{1, 96, 480, 960, 32767, 0xe350, 0xe728}
		file := fixtureHeader(uint16(rng.Intn(3)), uint16(count), divisions[rng.Intn(len(divisions))])[:14]
		for tr := 0; tr < count; tr++ {
			body := []byte{}
			for j := 0; j < 40; j++ {
				delta := byte(rng.Intn(8))
				ch := byte(rng.Intn(3))
				switch rng.Intn(10) {
				case 0, 1, 2:
					body = append(body, delta, 0x90|ch, byte(60+rng.Intn(4)), byte(1+rng.Intn(127)))
				case 3, 4:
					body = append(body, delta, 0x80|ch, byte(60+rng.Intn(4)), 0)
				case 5:
					body = append(body, delta, 0xb0|ch, []byte{7, 10, 11, 64, 70, 123}[rng.Intn(6)], byte(rng.Intn(128)))
				case 6:
					body = append(body, delta, 0xc0|ch, byte(rng.Intn(128)))
				case 7:
					body = append(body, delta, 0xff, 0x51, 3, byte(1+rng.Intn(20)), byte(rng.Intn(256)), byte(rng.Intn(256)))
				case 8:
					body = append(body, delta, 0xff, 0x58, 2, byte(1+rng.Intn(8)), byte(rng.Intn(5)))
				case 9:
					body = append(body, delta, 0xff, 0x59, 2, byte(int8(rng.Intn(15)-7)), byte(rng.Intn(2)))
				}
			}
			body = append(body, 0, 0xff, 0x2f, 0)
			file = append(file, []byte("MTrk\x00\x00\x00\x00")...)
			binary.BigEndian.PutUint32(file[len(file)-4:], uint32(len(body)))
			file = append(file, body...)
		}
		add(file)
	}
	out, err := json.Marshal(data)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/midiinput/performance.json"), out, 0644); err != nil {
		t.Fatal(err)
	}
}
