//go:build ignore

// Copy into upstream converter/internal/music and run TestCodexMusicGlyphs.
package music

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/shibukawa/bdf/converter/internal/music/smufl"
)

func TestCodexMusicGlyphs(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	raw, err := os.ReadFile(filepath.Join(root, "compat/musicnotation/smufl_names.json"))
	if err != nil {
		t.Fatal(err)
	}
	var names []string
	if err = json.Unmarshal(raw, &names); err != nil {
		t.Fatal(err)
	}
	data := []any{}
	for _, name := range names {
		source := smufl.Lookup(name)
		g := sym(name)
		anchors := g.anchors
		if anchors == nil {
			anchors = map[string][2]float64{}
		}
		verbs := []int{}
		for _, v := range g.outline.verbs {
			verbs = append(verbs, int(v))
		}
		coords := g.outline.args
		if coords == nil {
			coords = []float64{}
		}
		data = append(data, map[string]any{"name": name, "codepoint": int(source.Rune), "advance": g.advance, "bbox": [4]float64{g.x0, g.y0, g.x1, g.y1}, "anchors": anchors, "verbs": verbs, "coordinates": coords})
	}
	out, err := json.Marshal(data)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/musicnotation/glyphs.json"), out, 0644); err != nil {
		t.Fatal(err)
	}
}
