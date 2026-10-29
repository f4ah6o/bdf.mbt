//go:build ignore

// Generate CFF subsets and original glyph order from the upstream implementation.
package main

import (
	"encoding/json"
	"github.com/shibukawa/bdf/internal/cff"
	"github.com/shibukawa/bdf/internal/sfnt"
	"os"
	"path/filepath"
)

func main() {
	root := os.Args[1]
	file := "compat/font/fixtures/stix.otf"
	data, err := os.ReadFile(filepath.Join(root, file))
	if err != nil {
		panic(err)
	}
	face, err := sfnt.Parse(data)
	if err != nil {
		panic(err)
	}
	texts := []string{"", "A", "Hello, world 123!", "éÀçÅ ñ é", "漢字 😀", "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"}
	out := []any{}
	for _, text := range texts {
		keep := map[int]bool{}
		for _, r := range text {
			if gid := face.Cmap[uint32(r)]; gid != 0 {
				keep[int(gid)] = true
			}
		}
		program, order, err := cff.Subset(face.Tables["CFF "], keep)
		if err != nil {
			panic(err)
		}
		out = append(out, map[string]any{"file": file, "text": text, "program": program, "order": order})
	}
	if err = json.NewEncoder(os.Stdout).Encode(out); err != nil {
		panic(err)
	}
}
