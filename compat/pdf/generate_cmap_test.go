//go:build ignore

// Copy beside upstream converter/pdf/cmap.go and run TestCodexCMap.
package pdf

import (
	"fmt"
	"os"
	"strings"
	"testing"
)

func cmapBytes(b []byte) string {
	var out strings.Builder
	out.WriteString(`b"`)
	for _, c := range b {
		fmt.Fprintf(&out, `\x%02x`, c)
	}
	out.WriteString(`"`)
	return out.String()
}

func TestCodexCMap(t *testing.T) {
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dest == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	f, err := os.Create(dest)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	inputs := []string{
		"",
		`1 begincodespacerange <00> <ff> endcodespacerange 2 beginbfchar <03> <0041> <04> <00660069> endbfchar 1 beginbfrange <10> <12> <0061> endbfrange 1 beginbfrange <20> <21> [<0078> <0079>] endbfrange`,
		`1 begincodespacerange <00> <80> <8140> <9ffc> endcodespacerange 1 begincidrange <8140> <8150> 633 endcidrange`,
		`2 begincidrange <10> <20> 10 <15> <25> 40 endcidrange 1 begincidchar <18> 123 endcidchar`,
		`1 beginbfchar <03> /Aacute <04> /uni03A9 <05> /u1F600 <06> /A.alt endbfchar`,
		`1 beginbfchar <03> <d83dde00> <04> <d8000041> <05> <dfff> <06> <41> endbfchar`,
		`/Identity-H usecmap`, `/Identity-V usecmap`, `/Identity-V usecmap /WMode 0 def`,
		`/90ms-RKSJ-H usecmap`, `/90ms-RKSJ-V usecmap`, `/UniJIS-UTF8-H usecmap`, `/UniJIS-UTF16-V usecmap`, `/UniGB-UCS2-H usecmap`,
		`1 beginbfchar <0003> <0041> endbfchar`,
		`2 begincidchar <00> 1 <1000> 22 endcidchar`,
		`1 beginbfrange <01> <03> <0041> endbfrange`,
		`1 beginbfrange <01> <01> [<0041> <0042> <0043>] endbfrange`,
		`1 begincodespacerange <0000> <ffff> endcodespacerange`,
		`1 begincodespacerange <0000000000> <ffffffffff> endcodespacerange`,
		`2 begincidchar <01> -1 <02> 4294967297 endcidchar`,
	}
	codes := []uint32{0, 1, 2, 3, 4, 5, 6, 0x10, 0x11, 0x12, 0x18, 0x20, 0x21, 0x8142, 0xffff}
	samples := [][]byte{{0, 3, 0x10, 0x11, 0x81, 0x42}, {0x81}, {0, 3, 0, 4}, {0xff, 0xff, 0xff}, {1, 2, 3, 4, 5}}
	fmt.Fprintln(f, "///|\n// Generated from the upstream PDF CMap parser.\ntest \"PDF CMaps match upstream Go\" {")
	for _, src := range inputs {
		cm := parseCMap([]byte(src))
		fmt.Fprintf(f, "  check_pdf_cmap(%s, %t, [", cmapBytes([]byte(src)), cm.vertical)
		for _, code := range codes {
			cid, ok := cm.lookup(code, 0)
			found := "None"
			if ok {
				found = fmt.Sprintf("Some(%dL)", cid)
			}
			fmt.Fprintf(f, "(%dL,%s,%q),", code, found, cm.toUnicode(code))
		}
		fmt.Fprintln(f, "], [")
		for _, s := range samples {
			fmt.Fprintf(f, "(%s,[", cmapBytes(s))
			for _, g := range cm.decode(s) {
				fmt.Fprintf(f, "{code:%dL,size:%d,cid:%dL},", g.code, g.nbytes, g.cid)
			}
			fmt.Fprintln(f, "]),")
		}
		fmt.Fprintln(f, "])")
	}
	fmt.Fprintln(f, `}

///|
test "PDF CMap parents match upstream Go" {`)
	parents := []string{
		`2 begincidchar <01> 17 <02> 30 endcidchar /WMode 1 def`,
		`/Identity-V usecmap`,
		`/90ms-RKSJ-H usecmap`,
	}
	children := []string{
		`1 begincidchar <01> 44 endcidchar`,
		`/WMode 0 def`,
		`1 begincidrange <10> <20> 80 endcidrange`,
		``,
	}
	for _, parent := range parents {
		for _, child := range children {
			cm := parseCMapParent([]byte(child), parseCMap([]byte(parent)))
			fmt.Fprintf(f, "  check_pdf_cmap_parent(%s,%s,%t,[", cmapBytes([]byte(parent)), cmapBytes([]byte(child)), cm.vertical)
			for _, code := range codes {
				cid, ok := cm.lookup(code, 0)
				found := "None"
				if ok {
					found = fmt.Sprintf("Some(%dL)", cid)
				}
				fmt.Fprintf(f, "(%dL,%s),", code, found)
			}
			fmt.Fprintln(f, "])")
		}
	}
	fmt.Fprintln(f, `}

///|
fn check_pdf_cmap_parent(parent_input : Bytes, input : Bytes, vertical : Bool, entries : Array[(Int64, Int64?)]) -> Unit raise {
  let parent = pdf_parse_cmap(parent_input, None)
  let map = pdf_parse_cmap(input, Some(parent))
  assert_eq(map.vertical, vertical)
  for (code, cid) in entries { assert_eq(map.lookup(code, 0), cid) }
}

///|
fn check_pdf_cmap(input : Bytes, vertical : Bool, entries : Array[(Int64, Int64?, String)], samples : Array[(Bytes, Array[PdfGlyphCode])]) -> Unit raise {
  let map = pdf_parse_cmap(input, None)
  assert_eq(map.vertical, vertical)
  for (code, cid, value) in entries {
    assert_eq(map.lookup(code, 0), cid)
    assert_eq(map.to_unicode(code), value)
  }
  for (input, expected) in samples { assert_eq(map.decode(input), expected) }
}`)
}
