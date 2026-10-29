//go:build ignore

// Copy into upstream internal/otlayout and run TestCodexGSUBFixtures.
package otlayout

import (
	"bytes"
	"compress/gzip"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"sort"
	"testing"
)

func put16Fixture(b []byte, at, value int) { binary.BigEndian.PutUint16(b[at:], uint16(value)) }
func wordsFixture(values ...int) []byte {
	b := make([]byte, 2*len(values))
	for i, v := range values {
		put16Fixture(b, i*2, v)
	}
	return b
}
func singleFixture(src, dst []int, delta bool) []byte {
	var body []byte
	if delta {
		body = wordsFixture(1, 6, dst[0])
	} else {
		body = wordsFixture(2, 6+len(dst)*2, len(dst))
		for _, g := range dst {
			body = append(body, wordsFixture(g)...)
		}
	}
	body = append(body, wordsFixture(1, len(src))...)
	for _, g := range src {
		body = append(body, wordsFixture(g)...)
	}
	return body
}
func multiFixture(typ int) []byte {
	// Coverage [1,2], sequences [3,4] and [5].
	body := wordsFixture(1, 10, 2, 18, 24)
	body = append(body, wordsFixture(1, 2, 1, 2)...)
	body = append(body, wordsFixture(2, 3, 4, 1, 5)...)
	return body
}
func ligFixture() []byte {
	// Coverage 1, one ligature set with (1,2)->3 and (1,2,2)->4.
	body := wordsFixture(1, 8, 1, 14)
	body = append(body, wordsFixture(1, 1, 1)...)
	body = append(body, wordsFixture(2, 6, 12)...)
	body = append(body, wordsFixture(3, 2, 2, 4, 3, 2, 2)...)
	return body
}
func reverseFixture() []byte {
	// Empty context, coverage 1 and 2, substitutes 8 and 9.
	body := wordsFixture(1, 12, 0, 0, 2, 8, 9)
	put16Fixture(body, 2, len(body))
	body = append(body, wordsFixture(1, 2, 1, 2)...)
	return body
}
func lookupFixture(typ int, subtables ...[]byte) []byte {
	out := wordsFixture(typ, 0, len(subtables))
	out = append(out, make([]byte, 2*len(subtables))...)
	for i, sub := range subtables {
		put16Fixture(out, 6+2*i, len(out))
		out = append(out, sub...)
	}
	return out
}
func tableFixture(lookups ...[]byte) []byte {
	out := wordsFixture(1, 0, 0, 0, 10, len(lookups))
	out = append(out, make([]byte, 2*len(lookups))...)
	for i, lookup := range lookups {
		put16Fixture(out, 12+i*2, len(out)-10)
		out = append(out, lookup...)
	}
	return out
}
func extensionFixture(typ int, inner []byte) []byte {
	out := wordsFixture(1, typ, 0, 8)
	return append(out, inner...)
}
func oracleFixture(data []byte, roots []int) (bool, []int, bool) {
	table, e := ParseGSUB(data)
	kept := map[uint16]bool{}
	for _, g := range roots {
		if g >= 0 && g <= 65535 {
			kept[uint16(g)] = true
		}
	}
	if e != nil {
		out := []int{}
		for g := range kept {
			out = append(out, int(g))
		}
		sort.Ints(out)
		return false, out, false
	}
	subs := []Subst{}
	for i := range table.Lookups {
		table.Substs(i, func(s Subst) bool { subs = append(subs, s); return true })
	}
	changed := true
	for changed {
		changed = false
		for _, s := range subs {
			ready := true
			for _, g := range s.In {
				ready = ready && kept[g]
			}
			if ready {
				for _, g := range s.Out {
					if !kept[g] {
						kept[g] = true
						changed = true
					}
				}
			}
		}
	}
	out := []int{}
	for g := range kept {
		out = append(out, int(g))
	}
	sort.Ints(out)
	return true, out, table.Truncated()
}

// manyElements creates a compact layout with repeated references whose
// aggregate script or feature elements exceed the parsing budget.
func manyElements(scripts bool) []byte {
	const n = 3000
	const m = 1000
	list := make([]byte, 2+n*6)
	put16Fixture(list, 0, n)
	shared := len(list)
	if scripts {
		body := make([]byte, 4+m*6)
		put16Fixture(body, 2, m)
		list = append(list, body...)
	} else {
		body := make([]byte, 4+m*2)
		put16Fixture(body, 2, m)
		list = append(list, body...)
	}
	for i := 0; i < n; i++ {
		rec := 2 + i*6
		copy(list[rec:], "test")
		put16Fixture(list, rec+4, shared)
	}
	header := wordsFixture(1, 0, 0, 0, 0)
	if scripts {
		put16Fixture(header, 4, len(header))
	} else {
		put16Fixture(header, 6, len(header))
	}
	return append(header, list...)
}

// Repeated character-variant parameters also count against the same limit.
func manyFeatureChars() []byte {
	const n = 1000
	const chars = 2000
	list := make([]byte, 2+n*6)
	put16Fixture(list, 0, n)
	shared := len(list)
	feature := make([]byte, 4+14+chars*3)
	put16Fixture(feature, 0, 4)
	put16Fixture(feature, 4+12, chars)
	list = append(list, feature...)
	for i := 0; i < n; i++ {
		rec := 2 + i*6
		copy(list[rec:], "cv01")
		put16Fixture(list, rec+4, shared)
	}
	header := wordsFixture(1, 0, 0, 10, 0)
	return append(header, list...)
}

func TestCodexGSUBFixtures(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	one := lookupFixture(1, singleFixture([]int{1, 2}, []int{2, 3}, false))
	delta := lookupFixture(1, singleFixture([]int{4, 5}, []int{-2}, true))
	multiple := lookupFixture(2, multiFixture(2))
	alternate := lookupFixture(3, multiFixture(3))
	lig := lookupFixture(4, ligFixture())
	reverse := lookupFixture(8, reverseFixture())
	extension := lookupFixture(7, extensionFixture(1, singleFixture([]int{1}, []int{7}, false)))
	duplicate := lookupFixture(1, singleFixture([]int{1}, []int{2}, false), singleFixture([]int{1}, []int{3}, false))
	// Coverage format 2 expands ranges in their listed order; the coverage
	// index field is deliberately ignored by upstream.
	coverageRanges := wordsFixture(1, 6, -2, 2, 2, 1, 3, 88, 7, 8, 99)
	ranges := lookupFixture(1, coverageRanges)
	// Many references to a 65,536-glyph coverage exhaust the shared work
	// budget while emitting no substitutions (format 0 is unsupported).
	largeCoverage := wordsFixture(0, 4, 2, 1, 0, 65535, 0)
	many := make([][]byte, 70)
	for i := range many {
		many[i] = largeCoverage
	}
	stress := lookupFixture(1, many...)
	originals := [][]byte{tableFixture(one), tableFixture(delta), tableFixture(multiple), tableFixture(alternate), tableFixture(lig), tableFixture(reverse), tableFixture(extension), tableFixture(duplicate), tableFixture(one, delta, multiple, lig, reverse, extension), tableFixture(ranges), tableFixture(stress), manyElements(true), manyElements(false), manyFeatureChars()}
	roots := [][]int{{}, {0}, {1}, {2}, {1, 2}, {4, 5}, {1, 1, 2}, {65535}}
	cases := []any{}
	add := func(name string, b []byte) {
		for _, r := range roots {
			valid, out, truncated := oracleFixture(b, r)
			cases = append(cases, map[string]any{"name": name, "data": b, "roots": r, "valid": valid, "result": out, "truncated": truncated})
		}
	}
	for i, b := range originals {
		add(fmt.Sprintf("original-%d", i), b)
	}
	rng := rand.New(rand.NewSource(7221))
	for i := 0; i < 500; i++ {
		b := append([]byte(nil), originals[i%11]...)
		for j := 0; j < 1+rng.Intn(3) && len(b) > 0; j++ {
			p := rng.Intn(len(b))
			b[p] ^= byte(1 + rng.Intn(255))
		}
		if rng.Intn(5) == 0 {
			b = b[:rng.Intn(len(b)+1)]
		}
		add(fmt.Sprintf("mutation-%d", i), b)
	}
	encoded, e := json.Marshal(cases)
	if e != nil {
		t.Fatal(e)
	}
	var out bytes.Buffer
	zw := gzip.NewWriter(&out)
	if _, e = zw.Write(encoded); e != nil {
		t.Fatal(e)
	}
	if e = zw.Close(); e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/gsub/upstream.json.gz"), out.Bytes(), 0644); e != nil {
		t.Fatal(e)
	}
}
