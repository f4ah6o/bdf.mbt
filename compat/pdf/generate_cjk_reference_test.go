//go:build ignore

// Copy without the build tag into upstream converter/internal/cjkcmap, then
// run TestCodexCJKReference with BDF_REFERENCE_OUTPUT set.
package cjkcmap

import (
	"fmt"
	"math/rand"
	"os"
	"sort"
	"testing"
	"unicode/utf16"
	"unicode/utf8"
)

func TestCodexCJKReference(t *testing.T) {
	loadOnce.Do(load)
	if loadErr != nil {
		t.Fatal(loadErr)
	}
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dest == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(dest)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	names := make([]string, 0, len(cmaps))
	for name := range cmaps {
		names = append(names, name)
	}
	sort.Strings(names)
	rng := rand.New(rand.NewSource(515004))
	fmt.Fprintln(out, "///|\n// Generated from the upstream predefined CJK CMaps.\ntest \"Adobe CJK CMaps match upstream Go\" {")
	for _, name := range names {
		m := cmaps[name]
		fmt.Fprintf(out, "  check_pdf_cjk_map(%q,%t,[", name, m.Vertical)
		// Upstream resolves one parent at a time while iterating a Go map, so
		// a grandchild can nondeterministically miss its inherited codespace.
		// Use the complete parent chain as the deterministic expectation.
		spaces := m.Codespace
		parent := m.parent
		for depth := 0; len(spaces) == 0 && parent != nil && depth < 8; depth++ {
			spaces = parent.Codespace
			parent = parent.parent
		}
		for _, s := range spaces {
			fmt.Fprintf(out, "{size:%d,low:%dL,high:%dL},", s.Bytes, s.Lo, s.Hi)
		}
		fmt.Fprintln(out, "],[")
		codes := []uint32{0, 1, 0x41, 0x3042, 0x4e2d, 0x82a0, 0x8141, 0xe38182, 0xd840dc0b, 0xfffd, 0xffffffff}
		for j := 0; j < 10 && len(m.ranges) > 0; j++ {
			r := m.ranges[rng.Intn(len(m.ranges))]
			cp := r.lo
			if r.hi > r.lo {
				cp += uint32(rng.Int63n(int64(r.hi-r.lo) + 1))
			}
			code := cp
			if m.form == formUTF16 && cp > 0xffff && cp <= utf8.MaxRune {
				a, b := utf16.EncodeRune(rune(cp))
				code = uint32(a)<<16 | uint32(b)
			} else if m.form == formUTF8 && cp <= utf8.MaxRune {
				bytes := []byte(string(rune(cp)))
				code = 0
				for _, b := range bytes {
					code = code<<8 | uint32(b)
				}
			}
			codes = append(codes, code)
		}
		for _, code := range codes {
			cid, ok := m.CID(code)
			val := "None"
			if ok {
				val = fmt.Sprintf("Some(%dL)", cid)
			}
			point, ok := m.CodePoint(code)
			unicode := "None"
			if ok {
				unicode = fmt.Sprintf("Some(%dL)", point)
			}
			fmt.Fprintf(out, "(%dL,%s,%s),", code, val, unicode)
		}
		fmt.Fprintln(out, "])")
	}
	fmt.Fprintln(out, `}

///|
fn check_pdf_cjk_map(name : String, vertical : Bool, spaces : Array[PdfCodeSpace], entries : Array[(Int64, Int64?, Int64?)]) -> Unit raise {
  let map = pdf_cjk_maps.get(name).unwrap()
  assert_eq(map.vertical, vertical)
  assert_eq(map.codespaces.length(), spaces.length())
  for i in 0..<spaces.length() {
    assert_eq(map.codespaces[i].size, spaces[i].size)
    assert_eq(map.codespaces[i].low, spaces[i].low)
    assert_eq(map.codespaces[i].high, spaces[i].high)
  }
  for (code, cid, unicode) in entries {
    assert_eq(pdf_cjk_cid(name, code, 0), cid)
    assert_eq(map.code_point(code), unicode)
  }
}`)
}

func TestCodexCJKUnicode(t *testing.T) {
	loadOnce.Do(load)
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dest == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(dest)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	collections := []string{"Adobe-Japan1", "Adobe-Japan2", "Adobe-GB1", "Adobe-CNS1", "Adobe-Korea1", "Adobe-Identity"}
	rng := rand.New(rand.NewSource(45127))
	fmt.Fprintln(out, "///|\n// Generated from upstream CID-to-Unicode and vertical-form tables.\ntest \"Adobe CID to Unicode matches upstream Go\" {")
	for _, collection := range collections {
		cids := []uint32{0, 1, 231, 264, 323, 843, 1086, 1125, 4559, 7887, 7891, 131071, 131072}
		for i := 0; i < 512; i++ {
			cids = append(cids, uint32(rng.Intn(65536)))
		}
		for _, cid := range cids {
			code, vertical, ok := Unicode(collection, cid)
			unicode := "None"
			if ok {
				unicode = fmt.Sprintf("Some((%dL,%t))", code, vertical)
			}
			form, ok := VerticalForm(collection, cid)
			verticalForm := "None"
			if ok {
				verticalForm = fmt.Sprintf("Some(%dL)", form)
			}
			fmt.Fprintf(out, "  check_pdf_cjk_unicode(%q,%dL,%s,%s)\n", collection, cid, unicode, verticalForm)
		}
	}
	fmt.Fprintln(out, `}

///|
fn check_pdf_cjk_unicode(collection : String, cid : Int64, unicode : (Int64, Bool)?, vertical : Int64?) -> Unit raise {
  assert_eq(pdf_cjk_unicode(collection, cid), unicode)
  assert_eq(pdf_cjk_vertical_form(collection, cid), vertical)
}`)
}

func TestCodexCJKRangeDigests(t *testing.T) {
	loadOnce.Do(load)
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dest == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(dest)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	names := make([]string, 0, len(cmaps))
	for name := range cmaps {
		names = append(names, name)
	}
	sort.Strings(names)
	fmt.Fprintln(out, "///|\n// Every stored CJK range boundary, midpoint and adjacent code compared to upstream.\ntest \"Adobe CJK range digests match upstream Go\" {")
	var rangeCount int
	for _, name := range names {
		m := cmaps[name]
		rangeCount += len(m.ranges)
		digest := uint64(14695981039346656037)
		for _, r := range m.ranges {
			previous := r.lo
			if previous > 0 {
				previous--
			}
			next := r.hi
			if next < ^uint32(0) {
				next++
			}
			for _, key := range []uint32{previous, r.lo, r.lo + (r.hi-r.lo)/2, r.hi, next} {
				code := key
				if m.form == formUTF16 && key > 0xffff && key <= utf8.MaxRune {
					a, b := utf16.EncodeRune(rune(key))
					code = uint32(a)<<16 | uint32(b)
				} else if m.form == formUTF8 && key <= utf8.MaxRune {
					code = 0
					for _, b := range []byte(string(rune(key))) {
						code = code<<8 | uint32(b)
					}
				}
				cid, ok := m.CID(code)
				digest = (digest ^ uint64(code)) * 1099511628211
				val := uint64(0)
				if ok {
					val = uint64(cid) + 1
				}
				digest = (digest ^ val) * 1099511628211
			}
		}
		fmt.Fprintf(out, "  assert_eq(pdf_cjk_range_digest(%q), %dUL)\n", name, digest)
	}
	fmt.Fprintln(out, `}`)
	t.Logf("%d CMaps, %d ranges, %d boundary and midpoint lookups", len(names), rangeCount, 5*rangeCount)
}

func TestCodexCJKUnicodeDigests(t *testing.T) {
	loadOnce.Do(load)
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dest == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(dest)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	collections := []string{"Adobe-Japan1", "Adobe-Japan2", "Adobe-GB1", "Adobe-CNS1", "Adobe-Korea1"}
	fmt.Fprintln(out, "///|\n// Every CID in each upstream collection's supported range.\ntest \"Adobe CID Unicode digests match upstream Go\" {")
	for _, collection := range collections {
		digest := uint64(14695981039346656037)
		for cid := uint32(0); cid < 1<<17; cid++ {
			code, vertical, ok := Unicode(collection, cid)
			value := uint64(0)
			if ok {
				value = uint64(code) + 1
				if vertical {
					value |= 1 << 21
				}
			}
			digest = (digest ^ value) * 1099511628211
			form, ok := VerticalForm(collection, cid)
			value = 0
			if ok {
				value = uint64(form) + 1
			}
			digest = (digest ^ value) * 1099511628211
		}
		fmt.Fprintf(out, "  assert_eq(pdf_cjk_unicode_digest(%q), %dUL)\n", collection, digest)
	}
	fmt.Fprintln(out, `}`)
}
