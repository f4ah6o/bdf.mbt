//go:build ignore

// Copy into upstream converter/font alongside generate_test.go.
package font

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"testing"

	"github.com/shibukawa/bdf"
)

func TestCodexSpecimenPaths(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	unpack := func(data []byte) []byte {
		z, err := gzip.NewReader(bytes.NewReader(data))
		if err != nil {
			t.Fatal(err)
		}
		defer z.Close()
		out, err := io.ReadAll(z)
		if err != nil {
			t.Fatal(err)
		}
		return out
	}
	type item struct {
		Name  string `json:"name"`
		Input []byte `json:"input"`
		Index int    `json:"index"`
		Cases []struct {
			Glyph int `json:"glyph"`
		} `json:"cases"`
	}
	results := []any{}
	for _, file := range []string{"outlines.json.gz", "cff-outlines.json.gz"} {
		packed, err := os.ReadFile(filepath.Join(root, "compat/font", file))
		if err != nil {
			t.Fatal(err)
		}
		var fonts []item
		if err = json.Unmarshal(unpack(packed), &fonts); err != nil {
			t.Fatal(err)
		}
		for _, font := range fonts {
			if len(font.Cases) == 0 {
				results = append(results, []any{})
				continue
			}
			fl, err := load(unpack(font.Input))
			if err != nil {
				t.Fatal(font.Name, err)
			}
			var fc *face
			for _, face := range fl.faces {
				if face.index == font.Index {
					fc = face
					break
				}
			}
			if fc == nil {
				t.Fatal(font.Name, "face missing")
			}
			fc.prepare()
			output := []any{}
			for _, test := range font.Cases {
				path := &bdf.Path{}
				ok := fc.out.Outline(uint16(test.Glyph), &pathPen{p: path})
				var value any
				if ok && len(path.Verbs) > 0 {
					value = bdf.EncodePathCollection([]*bdf.Path{path})
				}
				output = append(output, value)
			}
			results = append(results, output)
		}
	}
	data, err := json.Marshal(results)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/specimen/paths.json.gz"), packFixture(data), 0644); err != nil {
		t.Fatal(err)
	}
}
