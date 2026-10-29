//go:build ignore

// Copy into the upstream module to generate synthetic cmap fixtures.
package main

import (
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"os"

	"github.com/shibukawa/bdf/internal/sfnt"
)

func put16(b []byte, at int, v uint16) { binary.BigEndian.PutUint16(b[at:], v) }
func put32(b []byte, at int, v uint32) { binary.BigEndian.PutUint32(b[at:], v) }

type subtable struct {
	platform, encoding uint16
	data               []byte
}

func cmap(tables ...subtable) []byte {
	b := make([]byte, 4+8*len(tables))
	put16(b, 2, uint16(len(tables)))
	for i, t := range tables {
		rec := 4 + i*8
		put16(b, rec, t.platform)
		put16(b, rec+2, t.encoding)
		put32(b, rec+4, uint32(len(b)))
		b = append(b, t.data...)
	}
	return b
}
func format0() []byte { b := make([]byte, 262); put16(b, 2, 262); b[6+65] = 7; b[6+255] = 8; return b }
func format6() []byte {
	b := make([]byte, 18)
	put16(b, 0, 6)
	put16(b, 2, uint16(len(b)))
	put16(b, 6, 0x41)
	put16(b, 8, 4)
	put16(b, 10, 3)
	put16(b, 14, 12)
	put16(b, 16, 65535)
	return b
}
func format12(groups ...[3]uint32) []byte {
	b := make([]byte, 16+12*len(groups))
	put16(b, 0, 12)
	put32(b, 4, uint32(len(b)))
	put32(b, 12, uint32(len(groups)))
	for i, g := range groups {
		off := 16 + 12*i
		put32(b, off, g[0])
		put32(b, off+4, g[1])
		put32(b, off+8, g[2])
	}
	return b
}
func format4() []byte {
	// Two non-overlapping segments using delta and idRangeOffset, plus sentinel.
	b := make([]byte, 44)
	put16(b, 0, 4)
	put16(b, 2, uint16(len(b)))
	put16(b, 6, 6)
	put16(b, 14, 0x43)
	put16(b, 16, 0x62)
	put16(b, 18, 0xffff)
	put16(b, 22, 0x41)
	put16(b, 24, 0x61)
	put16(b, 26, 0xffff)
	put16(b, 28, 0xffc2)
	put16(b, 30, 1)
	put16(b, 32, 1)
	put16(b, 36, 4)
	put16(b, 40, 9)
	return b
}
func font(cm []byte) []byte {
	head := make([]byte, 54)
	put16(head, 18, 1000)
	maxp := make([]byte, 6)
	put16(maxp, 4, 300)
	hhea := make([]byte, 36)
	put16(hhea, 4, 800)
	put16(hhea, 6, uint16(65536-200))
	put16(hhea, 8, 50)
	put16(hhea, 34, 4)
	hmtx := make([]byte, 16)
	for i, v := range []uint16{400, 500, 600, 700} {
		put16(hmtx, i*4, v)
	}
	return sfnt.Build(map[string][]byte{"head": head, "maxp": maxp, "hhea": hhea, "hmtx": hmtx, "cmap": cm}, false)
}
func main() {
	f0, f4, f6 := format0(), format4(), format6()
	f12 := format12([3]uint32{0x41, 0x43, 20}, [3]uint32{0x1f600, 0x1f602, 65535}, [3]uint32{0x10ffff, 0x110002, 7})
	overlap := format12([3]uint32{0x41, 0x44, 5}, [3]uint32{0x42, 0x43, 9}, [3]uint32{0x10ffff, 0x10ffff, 8})
	cases := [][]byte{
		cmap(subtable{3, 1, f0}), cmap(subtable{3, 1, f4}), cmap(subtable{0, 3, f6}), cmap(subtable{3, 10, f12}),
		cmap(subtable{0, 3, f0}, subtable{3, 1, f6}, subtable{3, 10, f12}),
		cmap(subtable{3, 1, f0}, subtable{3, 1, f6}), cmap(subtable{3, 0, f0}), cmap(subtable{3, 10, overlap}),
		cmap(subtable{3, 1, f4[:12]}), cmap(subtable{3, 1, []byte{0, 13, 0, 0}}),
	}
	out := []any{}
	for _, cm := range cases {
		data := font(cm)
		f, err := sfnt.Parse(data)
		if err != nil {
			panic(err)
		}
		hash := sha256.New()
		var word [2]byte
		for code := 0; code <= 0x10ffff; code++ {
			binary.BigEndian.PutUint16(word[:], f.Cmap[uint32(code)])
			hash.Write(word[:])
		}
		out = append(out, map[string]any{"data": data, "cmapHash": hex.EncodeToString(hash.Sum(nil))})
	}
	if err := json.NewEncoder(os.Stdout).Encode(out); err != nil {
		panic(err)
	}
}
