//go:build ignore

// Generate whole-font rebuilds with absent and truncated metric tables.
package main

import (
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"github.com/shibukawa/bdf/internal/sfnt"
	"os"
)

func main() {
	head := make([]byte, 54)
	binary.BigEndian.PutUint16(head[18:], 1000)
	hhea := make([]byte, 36)
	binary.BigEndian.PutUint16(hhea[4:], 800)
	binary.BigEndian.PutUint16(hhea[6:], 65336)
	binary.BigEndian.PutUint16(hhea[34:], 2)
	maxp := make([]byte, 6)
	binary.BigEndian.PutUint16(maxp[4:], 3)
	hmtx := make([]byte, 8)
	binary.BigEndian.PutUint16(hmtx, 400)
	binary.BigEndian.PutUint16(hmtx[4:], 600)
	inputs := []map[string][]byte{
		{"maxp": maxp, "hhea": hhea, "hmtx": hmtx},
		{"head": head, "maxp": maxp, "hmtx": hmtx},
		{"head": head, "maxp": maxp, "hhea": hhea},
		{"head": head, "hhea": hhea, "hmtx": hmtx},
		{"head": head, "maxp": maxp, "hhea": hhea[:10], "hmtx": hmtx},
		{"head": head, "maxp": maxp, "hhea": hhea, "hmtx": {}},
	}
	out := []any{}
	for _, tables := range inputs {
		data := sfnt.Build(tables, false)
		f, e := sfnt.Parse(data)
		if e != nil {
			panic(e)
		}
		fstype := uint16(4)
		if f.HasFSType {
			fstype = f.FSType
		}
		program := f.Rebuild(f.Cmap, sfnt.FontInfo{Family: "", Weight: 400, FSType: fstype, Notices: f.Notices})
		digest := sha256.Sum256(program)
		out = append(out, map[string]any{"data": data, "sha256": hex.EncodeToString(digest[:]), "program": program})
	}
	if e := json.NewEncoder(os.Stdout).Encode(out); e != nil {
		panic(e)
	}
}
