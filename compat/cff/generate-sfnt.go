//go:build ignore

// Wrap synthetic CFF fixtures in OpenType and compare upstream SFNT rebuilding.
package main

import (
	"encoding/binary"
	"encoding/json"
	"github.com/shibukawa/bdf/internal/cff"
	"github.com/shibukawa/bdf/internal/sfnt"
	"os"
	"path/filepath"
)

type input struct {
	Name  string `json:"name"`
	Data  []byte `json:"data"`
	Gids  []int  `json:"gids"`
	Error string `json:"error"`
}

func main() {
	root := os.Args[1]
	raw, e := os.ReadFile(filepath.Join(root, "compat/cff/synthetic.json"))
	if e != nil {
		panic(e)
	}
	var cases []input
	if e = json.Unmarshal(raw, &cases); e != nil {
		panic(e)
	}
	origin, e := os.ReadFile(filepath.Join(root, "compat/font/fixtures/stix.otf"))
	if e != nil {
		panic(e)
	}
	base, e := sfnt.Parse(origin)
	if e != nil {
		panic(e)
	}
	out := []any{}
	for _, sample := range cases {
		cf, err := cff.Parse(sample.Data)
		if err != nil {
			panic(err)
		}
		tables := map[string][]byte{}
		for _, name := range []string{"head", "hhea", "maxp", "name", "OS/2", "post"} {
			tables[name] = append([]byte(nil), base.Tables[name]...)
		}
		binary.BigEndian.PutUint16(tables["maxp"][4:], uint16(cf.NumGlyphs))
		binary.BigEndian.PutUint16(tables["hhea"][34:], uint16(cf.NumGlyphs))
		hmtx := make([]byte, 4*cf.NumGlyphs)
		for i := 0; i < cf.NumGlyphs; i++ {
			binary.BigEndian.PutUint16(hmtx[i*4:], uint16(450+i%100))
			binary.BigEndian.PutUint16(hmtx[i*4+2:], uint16(20+i%20))
		}
		tables["hmtx"] = hmtx
		tables["CFF "] = sample.Data
		cm := map[uint32]uint16{}
		text := []rune{}
		for i, gid := range sample.Gids {
			if gid > 0 {
				r := rune('A' + i)
				cm[uint32(r)] = uint16(gid)
				text = append(text, r)
			}
		}
		tables["cmap"] = sfnt.BuildCmap(cm)
		data := sfnt.Build(tables, true)
		font, err := sfnt.Parse(data)
		if err != nil {
			panic(err)
		}
		gids := []uint16{}
		for _, r := range text {
			gids = append(gids, font.Cmap[uint32(r)])
		}
		sub, remap := font.SubsetCFF(gids)
		info := sfnt.FontInfo{Family: "STIX Two Text", Weight: 400, FSType: font.FSType, Notices: font.Notices}
		mapped := map[uint32]uint16{}
		for _, r := range text {
			g := font.Cmap[uint32(r)]
			if sub != nil {
				mapped[uint32(r)] = remap[g]
			} else {
				mapped[uint32(r)] = g
			}
		}
		result := map[string]any{"name": sample.Name, "data": data, "text": string(text), "supported": sub != nil}
		if sub != nil {
			result["program"] = sub.Rebuild(mapped, info)
		} else {
			result["program"] = font.Rebuild(mapped, info)
		}
		out = append(out, result)
	}
	if err := json.NewEncoder(os.Stdout).Encode(out); err != nil {
		panic(err)
	}
}
