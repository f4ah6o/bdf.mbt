//go:build ignore

// Generate whole and subset font programs with the upstream font database.
package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"github.com/shibukawa/bdf/internal/fontdb"
	"os"
	"path/filepath"
	"strings"
)

func main() {
	root := os.Args[1]
	db := fontdb.New(nil, []string{filepath.Join(root, "compat/font/fixtures"), filepath.Join(root, "compat/visual")}, false)
	specs := []struct {
		file  string
		index int
	}{
		{"compat/visual/synthetic.ttf", 0}, {"compat/font/fixtures/stix.ttf", 0}, {"compat/font/fixtures/bold.ttc", 0}, {"compat/font/fixtures/bold.ttc", 1}, {"compat/font/fixtures/features.ttf", 0}, {"compat/font/fixtures/restricted.ttf", 0}, {"compat/font/fixtures/variable.ttf", 0}, {"compat/font/fixtures/color.ttf", 0},
	}
	texts := []string{"", "A", "Name Amount Alice 123.45\néÀçÅ ñ é", "漢字😀𝄞", strings.Repeat("ABCDEFG abcdefg 0123456789", 200)}
	out := []any{}
	for _, spec := range specs {
		var face *fontdb.Face
		for _, f := range db.Faces {
			if f.Path == filepath.Join(root, spec.file) && f.Index == spec.index {
				face = f
				break
			}
		}
		if face == nil {
			panic("font not scanned: " + spec.file)
		}
		loaded, err := face.Load()
		if err != nil {
			panic(err)
		}
		for _, txt := range texts {
			program, ok := loaded.Program([]rune(txt), nil, false, true)
			if !ok {
				panic("program denied")
			}
			sum := sha256.Sum256(program)
			out = append(out, map[string]any{"file": spec.file, "index": spec.index, "text": txt, "program": program, "sha256": hex.EncodeToString(sum[:])})
		}
	}
	if err := json.NewEncoder(os.Stdout).Encode(out); err != nil {
		panic(err)
	}
}
