//go:build ignore

// Generate composite, cyclic and large TrueType subset cases upstream.
package main

import (
	"encoding/binary"
	"encoding/json"
	"github.com/shibukawa/bdf/internal/sfnt"
	"os"
)

func font(glyphs [][]byte, short bool, missingHhea bool) []byte {
	head := make([]byte, 54)
	binary.BigEndian.PutUint16(head[18:], 1000)
	if !short {
		binary.BigEndian.PutUint16(head[50:], 1)
	}
	maxp := make([]byte, 6)
	binary.BigEndian.PutUint16(maxp[4:], uint16(len(glyphs)))
	hhea := make([]byte, 36)
	binary.BigEndian.PutUint16(hhea[4:], 800)
	binary.BigEndian.PutUint16(hhea[6:], 65336)
	binary.BigEndian.PutUint16(hhea[34:], uint16(len(glyphs)))
	var glyf, loca, hmtx []byte
	for _, g := range glyphs {
		if short {
			loca = binary.BigEndian.AppendUint16(loca, uint16(len(glyf)/2))
		} else {
			loca = binary.BigEndian.AppendUint32(loca, uint32(len(glyf)))
		}
		glyf = append(glyf, g...)
		for len(glyf)%4 != 0 {
			glyf = append(glyf, 0)
		}
		hmtx = binary.BigEndian.AppendUint16(hmtx, 500)
		hmtx = binary.BigEndian.AppendUint16(hmtx, 20)
	}
	if short {
		loca = binary.BigEndian.AppendUint16(loca, uint16(len(glyf)/2))
	} else {
		loca = binary.BigEndian.AppendUint32(loca, uint32(len(glyf)))
	}
	tables := map[string][]byte{"head": head, "maxp": maxp, "glyf": glyf, "loca": loca, "hmtx": hmtx, "cmap": sfnt.BuildCmap(map[uint32]uint16{65: 1, 66: 2, 67: 3})}
	if !missingHhea {
		tables["hhea"] = hhea
	}
	return sfnt.Build(tables, false)
}

func damagedLoca(data []byte, descending bool) []byte {
	f, err := sfnt.Parse(data)
	if err != nil {
		panic(err)
	}
	tables := map[string][]byte{}
	for key, value := range f.Tables {
		tables[key] = append([]byte(nil), value...)
	}
	if descending {
		binary.BigEndian.PutUint16(tables["loca"], 100)
	} else {
		tables["loca"] = tables["loca"][:4]
	}
	return sfnt.Build(tables, false)
}

func main() {
	basic := make([]byte, 12)
	// Glyph 1 refers to 2 and invalid 99; glyph 2 refers back to 1.
	g1 := make([]byte, 26)
	binary.BigEndian.PutUint16(g1, 0xffff)
	binary.BigEndian.PutUint16(g1[10:], 0x21)
	binary.BigEndian.PutUint16(g1[12:], 2)
	binary.BigEndian.PutUint16(g1[18:], 0)
	binary.BigEndian.PutUint16(g1[20:], 99)
	g2 := make([]byte, 16)
	binary.BigEndian.PutUint16(g2, 0xffff)
	binary.BigEndian.PutUint16(g2[12:], 1)
	huge := make([]byte, 40000)
	specs := []struct {
		data []byte
		text string
	}{
		{font([][]byte{basic, g1, g2, basic}, true, false), "A"},
		{font([][]byte{huge, huge, huge, huge}, false, false), "ABC"},
		{font([][]byte{basic, g1, g2, basic}, true, true), "AB"},
		{damagedLoca(font([][]byte{basic, g1, g2, basic}, true, false), false), "ABC"},
		{damagedLoca(font([][]byte{basic, g1, g2, basic}, true, false), true), "ABC"},
	}
	out := []any{}
	for _, s := range specs {
		f, err := sfnt.Parse(s.data)
		if err != nil {
			panic(err)
		}
		gids := []uint16{}
		for _, r := range s.text {
			gids = append(gids, f.Cmap[uint32(r)])
		}
		sub, remap := f.Subset(gids)
		if sub == nil {
			panic("subset failed")
		}
		cmap := map[uint32]uint16{}
		for _, r := range s.text {
			cmap[uint32(r)] = remap[f.Cmap[uint32(r)]]
		}
		program := sub.Rebuild(cmap, sfnt.FontInfo{Family: "", Weight: 400, FSType: 4, Notices: f.Notices})
		out = append(out, map[string]any{"data": s.data, "text": s.text, "program": program})
	}
	if err := json.NewEncoder(os.Stdout).Encode(out); err != nil {
		panic(err)
	}
}
