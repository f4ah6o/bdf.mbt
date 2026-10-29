//go:build ignore

// Copy into the upstream converter/font package with generate_test.go.
package font

import (
	"encoding/binary"
	"encoding/json"
	"github.com/shibukawa/bdf/internal/sfnt"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexInfoTables(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	results := []any{}
	add := func(name string, tables map[string][]byte) {
		fc := face{f: &sfnt.Font{Tables: tables}}
		count, more := variationSequences(tables["cmap"])
		d, s := metaLangs(tables["meta"])
		pal := [][]uint32{}
		for _, p := range fc.palettes() {
			pal = append(pal, append([]uint32{}, p...))
		}
		results = append(results, map[string]any{"name": name, "tables": tables, "count": count, "more": more, "design": d, "supported": s, "color": colorFormats(tables), "palettes": pal})
	}
	for _, name := range []string{"stix.ttf", "stix.otf", "variable.ttf", "color.ttf"} {
		b, e := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if e != nil {
			t.Fatal(e)
		}
		f, e := sfnt.Parse(b)
		if e != nil {
			t.Fatal(e)
		}
		tables := map[string][]byte{}
		for _, tag := range []string{"cmap", "meta", "COLR", "CPAL", "sbix", "CBLC", "SVG "} {
			if f.Tables[tag] != nil {
				tables[tag] = f.Tables[tag]
			}
		}
		add(name, tables)
	}
	cmap := make([]byte, 12+10+2*11+4+2*4+4)
	binary.BigEndian.PutUint16(cmap[2:], 1)
	binary.BigEndian.PutUint16(cmap[6:], 5)
	binary.BigEndian.PutUint32(cmap[8:], 12)
	st := cmap[12:]
	binary.BigEndian.PutUint16(st, 14)
	binary.BigEndian.PutUint32(st[6:], 2)
	binary.BigEndian.PutUint32(st[13:], 32)
	binary.BigEndian.PutUint32(st[17:], 44)
	binary.BigEndian.PutUint32(st[24:], 32)
	binary.BigEndian.PutUint32(st[28:], 44)
	binary.BigEndian.PutUint32(st[32:], 2)
	st[39] = 2
	st[43] = 4
	binary.BigEndian.PutUint32(st[44:], 9)
	colr := make([]byte, 38)
	binary.BigEndian.PutUint16(colr, 1)
	binary.BigEndian.PutUint16(colr[2:], 2)
	binary.BigEndian.PutUint32(colr[14:], 34)
	binary.BigEndian.PutUint32(colr[34:], 12345)
	cpal := make([]byte, 24)
	binary.BigEndian.PutUint16(cpal[2:], 2)
	binary.BigEndian.PutUint16(cpal[4:], 1)
	binary.BigEndian.PutUint16(cpal[6:], 2)
	binary.BigEndian.PutUint32(cpal[8:], 16)
	copy(cpal[16:], []byte{1, 2, 3, 255, 4, 5, 6, 128})
	sbix := make([]byte, 20)
	binary.BigEndian.PutUint32(sbix[4:], 2)
	binary.BigEndian.PutUint32(sbix[8:], 16)
	binary.BigEndian.PutUint32(sbix[12:], 18)
	binary.BigEndian.PutUint16(sbix[16:], 16)
	binary.BigEndian.PutUint16(sbix[18:], 32)
	cblc := make([]byte, 104)
	binary.BigEndian.PutUint32(cblc[4:], 2)
	cblc[52] = 12
	cblc[100] = 24
	svg := make([]byte, 12)
	binary.BigEndian.PutUint32(svg[2:], 10)
	binary.BigEndian.PutUint16(svg[10:], 31415)
	meta := make([]byte, 40)
	binary.BigEndian.PutUint32(meta, 1)
	binary.BigEndian.PutUint32(meta[12:], 1)
	copy(meta[16:], "dlng")
	binary.BigEndian.PutUint32(meta[20:], 28)
	binary.BigEndian.PutUint32(meta[24:], 12)
	copy(meta[28:], "en-Latn,Arab")
	base := map[string][]byte{"cmap": cmap, "COLR": colr, "CPAL": cpal, "sbix": sbix, "CBLC": cblc, "SVG ": svg, "meta": meta}
	add("synthetic", base)
	rng := rand.New(rand.NewSource(22529))
	tags := []string{"cmap", "COLR", "CPAL", "sbix", "CBLC", "SVG ", "meta"}
	for i := 0; i < 700; i++ {
		tables := map[string][]byte{}
		for k, v := range base {
			tables[k] = append([]byte(nil), v...)
		}
		tag := tags[i%len(tags)]
		b := tables[tag]
		if i%3 == 0 {
			b = b[:rng.Intn(len(b)+1)]
		} else {
			for j := 0; j < 1+rng.Intn(5); j++ {
				b[rng.Intn(len(b))] = byte(rng.Intn(256))
			}
		}
		tables[tag] = b
		add("mutation", tables)
	}
	// One over-budget range table. Its large zero-filled payload compresses well.
	ranges := (1 << 22) + 1
	huge := make([]byte, 12+10+11+4+4*ranges)
	binary.BigEndian.PutUint16(huge[2:], 1)
	binary.BigEndian.PutUint16(huge[6:], 5)
	binary.BigEndian.PutUint32(huge[8:], 12)
	h := huge[12:]
	binary.BigEndian.PutUint16(h, 14)
	binary.BigEndian.PutUint32(h[6:], 1)
	binary.BigEndian.PutUint32(h[13:], 21)
	binary.BigEndian.PutUint32(h[21:], uint32(ranges))
	add("range-budget", map[string][]byte{"cmap": huge})
	out, e := json.Marshal(results)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/specimen/info.json.gz"), packFixture(out), 0644); e != nil {
		t.Fatal(e)
	}
}
