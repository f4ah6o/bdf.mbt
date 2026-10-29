//go:build ignore

// Run from inside the upstream converter tree to compare font embedding order.
package main

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"github.com/shibukawa/bdf/converter/csv"
	"io"
	"os"
	"path/filepath"
	"sort"
	"testing/fstest"
)

func main() {
	root := os.Args[1]
	raw, err := os.ReadFile(filepath.Join(root, "compat/fontdb/upstream.json"))
	if err != nil {
		panic(err)
	}
	var src struct {
		Files []struct {
			Gzip []byte `json:"gzip"`
		} `json:"files"`
	}
	if err = json.Unmarshal(raw, &src); err != nil {
		panic(err)
	}
	get := func(i int) []byte {
		z, e := gzip.NewReader(bytes.NewReader(src.Files[i].Gzip))
		if e != nil {
			panic(e)
		}
		b, e := io.ReadAll(z)
		if e != nil {
			panic(e)
		}
		return b
	}
	type file struct {
		Path  string `json:"path"`
		Index int    `json:"index"`
	}
	configs := [][]file{
		{{"a-long-latin.ttf", 0}, {"z.ttf", 4}, {"zz.ttf", 8}},
		{{"a.ttf", 0}, {"b-a-very-long.ttf", 4}, {"z.ttf", 8}},
		{{"a-latin.ttf", 0}, {"z-cjk.ttf", 4}, {"é.ttf", 8}},
	}
	out := []any{}
	input := "Name,Text\nAlice,Hello ★\nBob,漢字かな 😀\n"
	for n, files := range configs {
		sort.Slice(files, func(i, j int) bool { return files[i].Path < files[j].Path })
		fs := fstest.MapFS{}
		for _, f := range files {
			fs[f.Path] = &fstest.MapFile{Data: get(f.Index)}
		}
		for mode := 0; mode < 2; mode++ {
			opt := &csv.Options{FontFS: fs, NoSystemFonts: true, NoWOFF2: true, Header: csv.HeaderYes, Name: "People", Title: "Report", NoSubset: mode == 0}
			res, e := csv.Convert(bytes.NewReader([]byte(input)), int64(len(input)), opt)
			if e != nil {
				panic(e)
			}
			parts := []any{}
			for _, p := range res.Doc.Parts() {
				parts = append(parts, map[string]any{"type": p.Type, "hash": p.Hash.String()})
			}
			out = append(out, map[string]any{"case": n, "files": files, "input": input, "mode": mode, "parts": parts, "views": res.Doc.Views, "warnings": res.Warnings})
		}
	}
	if e := json.NewEncoder(os.Stdout).Encode(out); e != nil {
		panic(e)
	}
}
