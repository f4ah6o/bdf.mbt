//go:build ignore

// Generate retained-glyph-number CFF programs from upstream.
package main

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"github.com/shibukawa/bdf/internal/cff"
	"github.com/shibukawa/bdf/internal/sfnt"
)

func main() {
	root := os.Args[1]
	var synthetic []struct {
		Name string `json:"name"`
		Data []byte `json:"data"`
		Gids []int  `json:"gids"`
	}
	raw, e := os.ReadFile(filepath.Join(root, "compat/cff/synthetic.json"))
	if e != nil {
		panic(e)
	}
	if e = json.Unmarshal(raw, &synthetic); e != nil {
		panic(e)
	}
	results := []any{}
	add := func(source, name string, data []byte, glyphs []int) {
		keep := map[int]bool{}
		for _, g := range glyphs {
			keep[g] = true
		}
		out, err := cff.Prune(data, keep)
		msg := ""
		if err != nil {
			msg = err.Error()
		}
		sum := sha256.Sum256(out)
		entry := map[string]any{"source": source, "name": name, "glyphs": glyphs, "error": msg, "size": len(out), "hash": fmt.Sprintf("%x", sum)}
		if name == "cid-format0" && len(glyphs) == 2 {
			entry["program"] = out
		}
		results = append(results, entry)
	}
	for _, s := range synthetic {
		for _, glyphs := range [][]int{s.Gids, {}, {0}, {1, 2, 3}, {0, 65535}, {2, 3}} {
			add("synthetic", s.Name, s.Data, glyphs)
		}
	}
	data, e := os.ReadFile(filepath.Join(root, "compat/font/fixtures/stix.otf"))
	if e != nil {
		panic(e)
	}
	font, e := sfnt.Parse(data)
	if e != nil {
		panic(e)
	}
	for _, text := range []string{"", "Hello", "ffi", "漢字", "ABC ◌ -", "Résumé", "0123456789"} {
		glyphs := []int{}
		for _, r := range text {
			glyphs = append(glyphs, int(font.Cmap[uint32(r)]))
		}
		add("real", "stix.otf", font.Tables["CFF "], glyphs)
	}
	if e = json.NewEncoder(os.Stdout).Encode(results); e != nil {
		panic(e)
	}
}
