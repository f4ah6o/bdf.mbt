//go:build ignore

// Copy into upstream converter/font alongside generate_test.go.
package font

import (
	"encoding/json"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
	"testing/fstest"

	"github.com/shibukawa/bdf/converter/internal/fontset"
	"github.com/shibukawa/bdf/internal/fontdb"
)

func TestCodexSpecimenTexter(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	names := []string{"stix.ttf", "stix.otf", "bold.ttc", "features.ttf"}
	files := map[string][]byte{}
	for _, name := range names {
		raw, err := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if err != nil {
			t.Fatal(err)
		}
		files[name] = raw
	}
	rng := rand.New(rand.NewSource(919933))
	result := []any{}
	texts := []string{"", "Hello world", "Alpha/beta-gamma,delta", "カタカナ 日本語 한글", "A漢B", "e\u0301😀⚑", "long-url-without-spaces", "line one\nline two\r\n  third", "中文， punctuation", "     ", "a b c", "tab\ttext", "ſßẞKİ"}
	for _, config := range [][]string{{}, {"stix.ttf"}, {"stix.otf", "stix.ttf"}, {"bold.ttc", "features.ttf", "stix.ttf"}} {
		fsys := fstest.MapFS{}
		for _, name := range config {
			fsys[name] = &fstest.MapFile{Data: files[name]}
		}
		set := fontset.New(fontdb.New(fsys, nil, false), nil)
		texter := &texter{set: set}
		cases := []any{}
		for i := 0; i < 260; i++ {
			text := texts[rng.Intn(len(texts))]
			size := float64(6 + rng.Intn(30))
			bold := rng.Intn(2) == 0
			width := float64(rng.Intn(200)) / 2
			line := texter.line(text, size, bold)
			runs := []any{}
			for _, r := range line.runs {
				var face any
				index := -1
				if r.fc.Use.Face != nil {
					face = r.fc.Use.Face.Path
					index = r.fc.Use.Face.Index
				}
				runs = append(runs, map[string]any{"text": r.s, "lang": r.lang, "x": r.x, "width": r.w, "face": face, "index": index, "requested": r.fc.Use.Requested, "generic": r.fc.Use.Generic, "bold": r.fc.Use.Bold, "italic": r.fc.Use.Italic, "synthBold": r.fc.Use.SynthBold, "synthItalic": r.fc.Use.SynthItalic})
			}
			wrap := texter.wrap(text, size, bold, width)
			if wrap == nil {
				wrap = []string{}
			}
			cases = append(cases, map[string]any{"text": text, "size": size, "bold": bold, "maxWidth": width, "width": line.width, "runs": runs, "fit": texter.fit(text, size, bold, width), "wrap": wrap})
		}
		paths := append([]string{}, config...)
		used, missing := fontset.CodexFixtureUsage(set)
		result = append(result, map[string]any{"fonts": paths, "cases": cases, "used": used, "missing": missing})
	}
	packed := map[string][]byte{}
	for name, data := range files {
		packed[name] = packFixture(data)
	}
	out, err := json.Marshal(map[string]any{"files": packed, "configurations": result})
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/specimen/texter.json.gz"), packFixture(out), 0644); err != nil {
		t.Fatal(err)
	}
}
