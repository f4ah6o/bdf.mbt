//go:build ignore

// Overlay into the upstream bdf package and set BDF_REFERENCE_OUTPUT.
package bdf

import (
	"fmt"
	"os"
	"strings"
	"testing"
)

func prefixGroupBytes(data []byte) string {
	var s strings.Builder
	s.WriteString(`b"`)
	for _, b := range data {
		fmt.Fprintf(&s, `\x%02x`, b)
	}
	s.WriteString(`"`)
	return s.String()
}
func TestCodexPrefixGroups(t *testing.T) {
	out, e := os.Create(os.Getenv("BDF_REFERENCE_OUTPUT"))
	if e != nil {
		t.Fatal(e)
	}
	defer out.Close()
	for n := 0; n < 33; n++ {
		count := 2 + n%5
		if n >= 30 {
			count = 2
		}
		objects := make([]*Object, count)
		for i := range objects {
			if n >= 30 {
				o := NewObject().SetBBox(0, 0, 100, 100)
				o.Ext(make([]byte, 506+n-30)).FillRect(float32(i), 0, 1, 1)
				objects[i] = o
				continue
			}
			variant := 0
			if n%6 == 1 && i == count-1 {
				variant = 1
			}
			if n%6 == 2 && i%2 == 1 {
				variant = 1
			}
			font := "serif"
			if n%6 == 3 && i == count-1 {
				font = "sans-serif"
			}
			var image, child Hash
			image[0] = 1
			child[0] = 9
			if n%6 == 4 && i == count-1 {
				image[0] = 2
			}
			if n%6 == 5 && i == count-1 {
				child[0] = 10
			}
			o := NewObject().SetBBox(0, 0, 400, 300)
			f := o.AddFont(SystemFont(font, 400, 0))
			p := o.AddPath((&Path{}).Rect(0, 0, float32(10+variant), 20))
			external := o.AddExtPath(child, uint32(variant))
			im := o.AddImage(image)
			ob := o.AddObject(child, Rect{W: 4, H: 4})
			paint := o.AddPaint(Pattern(im, 0))
			o.Font(f, 12).FillPath(p, 0).FillPaint(paint).FillPath(p, 0).Image(im, 1, 2, 3, 4).Use(ob)
			o.StrokePaint(paint).StrokePath(external).FillPathAt(p, 0, 1, 2).FillPathRun(0, []Glyph{{Path: p, X: 1, Y: 2}, {Path: external, X: 3, Y: 4}}).UseAt(ob, 1, 2)
			for j := 0; j < 32; j++ {
				o.FillRect(float32(j), 0, 1, 1)
			}
			if n%3 == 0 {
				if i < 3 {
					o.FillRect(7, 8, 9, 10)
				} else {
					o.FillRect(8, 8, 9, 10)
				}
			}
			text := "alpha"
			if i%2 == 1 {
				text = "beta"
			}
			o.FillText(text, 1, 2, 30)
			o.FillRect(float32(i), 0, 1, 1)
			objects[i] = o
		}
		threshold := []int{0, 511, 512, 513, 600, 10000}[n%6]
		if n >= 30 {
			threshold = 512
		}
		shares, err := SharePrefixes(objects, threshold)
		if err != nil {
			t.Fatal(err)
		}
		fmt.Fprintf(out, "///|\ntest \"BDF prefix selection matches Go %d\" {\n check_prefix_groups([", n)
		for _, o := range objects {
			fmt.Fprintf(out, "%s,", prefixGroupBytes(o.Encode()))
		}
		fmt.Fprint(out, "], [")
		for _, o := range objects {
			sp, part, err := o.decodeSpans()
			if err != nil {
				t.Fatal(err)
			}
			_, keys := o.prefixKeys(sp, part)
			fmt.Fprint(out, "[")
			for _, key := range keys {
				fmt.Fprintf(out, "\"%x\",", key)
			}
			fmt.Fprint(out, "],")
		}
		fmt.Fprintf(out, "], %d, [", threshold)
		for _, group := range shares {
			fmt.Fprint(out, "[")
			for _, m := range group.Members {
				sp, part, err := objects[m.Index].decodeSpans()
				if err != nil {
					t.Fatal(err)
				}
				points, _ := objects[m.Index].prefixKeys(sp, part)
				instr := -1
				for _, p := range points {
					if p.off == m.Saved {
						instr = p.instr
						break
					}
				}
				if instr < 0 {
					t.Fatal("missing point")
				}
				fmt.Fprintf(out, "(%d,%d,%d),", m.Index, instr, m.Saved)
			}
			fmt.Fprint(out, "],")
		}
		fmt.Fprint(out, "])\n}\n")
	}
}
