//go:build ignore

// Copy into a directory under the upstream module to access its fontdb.
// Run with the bdf.mbt repository path as the first argument.
package main

import (
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"github.com/shibukawa/bdf/internal/fontdb"
)

func main() {
	root := os.Args[1]
	db := fontdb.New(nil, []string{filepath.Join(root, "compat/font/fixtures"), filepath.Join(root, "compat/visual")}, false)
	specs := []struct {
		file  string
		index int
	}{
		{"compat/visual/synthetic.ttf", 0},
		{"compat/font/fixtures/stix.ttf", 0},
		{"compat/font/fixtures/stix.otf", 0},
		{"compat/font/fixtures/bold.ttc", 0},
		{"compat/font/fixtures/bold.ttc", 1},
		{"compat/font/fixtures/features.ttf", 0},
		{"compat/font/fixtures/restricted.ttf", 0},
		{"compat/font/fixtures/variable.ttf", 0},
		{"compat/font/fixtures/color.ttf", 0},
	}
	result := []any{}
	for _, spec := range specs {
		var face *fontdb.Face
		for _, candidate := range db.Faces {
			if candidate.Path == filepath.Join(root, spec.file) && candidate.Index == spec.index {
				face = candidate
				break
			}
		}
		if face == nil {
			panic("font not scanned: " + spec.file)
		}
		loaded, err := face.Load()
		if err != nil {
			panic(fmt.Sprintf("%s: %v", spec.file, err))
		}
		cmap := sha256.New()
		var word [2]byte
		for code := 0; code <= 0x10ffff; code++ {
			glyph, _ := loaded.Glyph(rune(code))
			binary.BigEndian.PutUint16(word[:], glyph)
			cmap.Write(word[:])
		}
		advances := sha256.New()
		for gid := 0; gid < loaded.Font.NumGlyphs+3 && gid <= 65535; gid++ {
			binary.BigEndian.PutUint16(word[:], uint16(loaded.Font.Advance(uint16(gid))))
			advances.Write(word[:])
		}
		embed, subset := loaded.Embeddable()
		result = append(result, map[string]any{
			"file": spec.file, "index": spec.index, "count": loaded.Font.NumGlyphs, "upem": loaded.Font.UnitsPerEm,
			"cff": loaded.Font.IsCFF, "ascent": loaded.Ascent, "descent": loaded.Descent,
			"underlinePos": loaded.UnderlinePos, "underlineThick": loaded.UnderTh, "capHeight": loaded.CapHeight,
			"embeddable": embed, "subsettable": subset, "cmapHash": hex.EncodeToString(cmap.Sum(nil)), "advanceHash": hex.EncodeToString(advances.Sum(nil)),
			"family": face.Family, "style": face.Style, "weight": face.Weight, "italic": face.Italic, "monospace": face.Mono, "math": face.Math,
		})
	}
	if err := json.NewEncoder(os.Stdout).Encode(result); err != nil {
		panic(err)
	}
}
