//go:build ignore

// Copy into upstream converter/internal/music and run TestCodexMusicValues.
package music

import (
	"encoding/json"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexMusicValues(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	type sample struct {
		Start    int      `json:"start"`
		End      int      `json:"end"`
		Beat     int      `json:"beat"`
		Length   int      `json:"length"`
		Compound bool     `json:"compound"`
		Rest     bool     `json:"rest"`
		Want     [][4]int `json:"want"`
	}
	samples := []sample{}
	r := rand.New(rand.NewSource(41381))
	for i := 0; i < 8000; i++ {
		beat := []int{1, 5, 60, 120, 240, 480, 960, 1440, 1920, 3840}[r.Intn(10)]
		length := 1 + r.Intn(15000)
		a := r.Intn(length)
		b := a + r.Intn(length-a+1)
		compound := r.Intn(2) == 0
		rest := r.Intn(2) == 0
		out := [][4]int{}
		for _, v := range divide(a, b, beat, length, compound, rest) {
			out = append(out, [4]int{v.a, v.ticks, int(v.typ), v.dots})
		}
		samples = append(samples, sample{a, b, beat, length, compound, rest, out})
	}
	out, err := json.Marshal(samples)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/musicnotation/values.json"), out, 0644); err != nil {
		t.Fatal(err)
	}
}
