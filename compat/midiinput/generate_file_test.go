//go:build ignore

// Copy into upstream converter/midi and run TestCodexMidiFile.
package midi

import (
	"encoding/json"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexMidiFile(t *testing.T) {
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
		result, err := Parse(b, nil)
		want := map[string]any{}
		if err != nil {
			want["error"] = err.Error()
		} else {
			w := []string{}
			for _, msg := range result.Warnings {
				if msg != "notes of no length are left out" {
					w = append(w, msg)
				}
			}
			want = map[string]any{"error": "", "format": result.Format, "tracks": countFixtureTracks(b), "smf": result.SMF, "warnings": w}
		}
		data = append(data, fixture{b, want})
	}
	base := fixtureHeader(0, 1, 480)
	for i := 0; i <= len(base); i++ {
		add(base[:i])
	}
	for _, b := range [][]byte{fixtureRiff(fixtureChunk("data", base)), fixtureRiff(), fixtureHeader(2, 1, 480), fixtureHeader(3, 1, 480), fixtureHeader(0, 1, 0xe350), append(append([]byte(nil), base...), 0, 0, 0), append(append([]byte(nil), base...), 1, 2, 3)} {
		add(b)
	}
	two := append(append([]byte(nil), base...), base[14:]...)
	add(two)
	smpteTwo := append(append([]byte(nil), fixtureHeader(1, 2, 0xe350)...), base[14:]...)
	add(smpteTwo)
	junk := append([]byte(nil), base[:14]...)
	junk = append(junk, 1, 2, 3)
	junk = append(junk, base[14:]...)
	add(junk)
	rng := rand.New(rand.NewSource(7741))
	for i := 0; i < 5000; i++ {
		b := append([]byte(nil), base...)
		for j := 0; j < 1+rng.Intn(5); j++ {
			b[rng.Intn(len(b))] = byte(rng.Intn(256))
		}
		if rng.Intn(5) == 0 {
			b = b[:rng.Intn(len(b)+1)]
		}
		add(b)
	}
	out, err := json.Marshal(data)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/midiinput/files.json"), out, 0644); err != nil {
		t.Fatal(err)
	}
}

// Determine the actual track count by the same chunk selection used by Parse;
// repaired non-SMPTE playback always contains exactly those chunks.
func countFixtureTracks(b []byte) int {
	p, err := Parse(b, nil)
	if err != nil {
		return 0
	}
	if p.SMF != nil {
		return int(p.SMF[10])<<8 | int(p.SMF[11])
	}
	smf, _, e := unwrapRMID(b)
	if e != nil {
		return 0
	}
	clone := append([]byte(nil), smf...)
	clone[12], clone[13] = 1, 224
	repaired, e := Parse(clone, nil)
	if e != nil {
		return 0
	}
	return int(repaired.SMF[10])<<8 | int(repaired.SMF[11])
}
