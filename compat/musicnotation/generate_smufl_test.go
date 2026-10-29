//go:build ignore

// Copy into upstream converter/internal/music/smufl and run TestCodexSMuFL.
package smufl

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"testing"
)

func TestCodexSMuFL(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	names := make([]string, 0, len(glyphs))
	for name := range glyphs {
		names = append(names, name)
	}
	sort.Strings(names)
	num := func(f float64) string {
		s := strconv.FormatFloat(f, 'f', -1, 64)
		if !strings.Contains(s, ".") {
			s += ".0"
		}
		return s
	}
	var b bytes.Buffer
	fmt.Fprintln(&b, "// Generated from upstream Bravura 1.482 SMuFL data; see licenses/Bravura-OFL.txt.\n\n///|\nlet smufl_glyphs : Map[String, SmuflSource] = {")
	for _, name := range names {
		g := glyphs[name]
		fmt.Fprintf(&b, "  %s: { codepoint: %d, advance: %d, bbox: (%s, %s, %s, %s), anchors: Map([", strconv.Quote(name), g.Rune, g.Advance, num(g.BBox[0]), num(g.BBox[1]), num(g.BBox[2]), num(g.BBox[3]))
		keys := make([]string, 0, len(g.Anchors))
		for k := range g.Anchors {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		for _, k := range keys {
			p := g.Anchors[k]
			fmt.Fprintf(&b, "(%s, (%s, %s)),", strconv.Quote(k), num(p[0]), num(p[1]))
		}
		fmt.Fprintf(&b, "]), path: %s },\n", strconv.Quote(g.Path))
	}
	fmt.Fprintln(&b, "}")
	if err := os.WriteFile(filepath.Join(root, "convert/music/smufl_data.mbt"), b.Bytes(), 0644); err != nil {
		t.Fatal(err)
	}
	encoded, err := json.Marshal(names)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/musicnotation/smufl_names.json"), encoded, 0644); err != nil {
		t.Fatal(err)
	}
}
