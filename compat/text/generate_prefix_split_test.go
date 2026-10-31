//go:build ignore

// Overlay in the upstream bdf package and set BDF_REFERENCE_OUTPUT.
package bdf

import (
	"fmt"
	"math"
	"os"
	"strings"
	"testing"
)

func splitBytes(data []byte) string {
	var s strings.Builder
	s.WriteString(`b"`)
	for _, b := range data {
		fmt.Fprintf(&s, `\x%02x`, b)
	}
	s.WriteString(`"`)
	return s.String()
}
func splitInts(out *os.File, refs []int) {
	fmt.Fprint(out, "[")
	for _, v := range refs {
		fmt.Fprintf(out, "%d,", v)
	}
	fmt.Fprint(out, "]")
}
func fontInts(values []FontRef) []int {
	out := make([]int, len(values))
	for i, v := range values {
		out[i] = int(v)
	}
	return out
}
func TestCodexPrefixSplits(t *testing.T) {
	out, e := os.Create(os.Getenv("BDF_REFERENCE_OUTPUT"))
	if e != nil {
		t.Fatal(e)
	}
	defer out.Close()
	state := uint64(0x920fc25b1)
	next := func() uint64 { state ^= state << 13; state ^= state >> 7; state ^= state << 17; return state }
	rnd := func() float32 { return float32(int32(next()%20001)-10000) / 100 }
	for n := 0; n < 124; n++ {
		o := NewObject().SetBBox(0, 0, 400, 300)
		p0 := o.AddPath((&Path{}).Rect(0, 0, 10, 10))
		p1 := o.AddPath((&Path{}).Rect(0, 0, 10, 10))
		var hash Hash
		hash[0] = 7
		external := o.AddExtPath(hash, 3)
		f0 := o.AddFont(SystemFont("serif", 400, 0))
		f1 := o.AddFont(SystemFont("serif", 400, 0))
		im0 := o.AddImage(hash)
		im1 := o.AddImage(hash)
		child0 := o.AddObject(hash, Rect{X: 1, Y: 2, W: 3, H: 4})
		child1 := o.AddObject(hash, Rect{X: 5, Y: 6, W: 7, H: 8})
		paint0 := o.AddPaint(Pattern(im0, 0))
		paint1 := o.AddPaint(Pattern(im1, 0))
		switch n {
		case 120:
			o.Transform(1, 0, 0, 1, math.Float32frombits(0x80000000), 0)
		case 121:
			o.Translate(5, -7).Translate(-5, 7)
		case 122:
			// No matrix: the split must not add an identity transform.
		case 123:
			o.Transform(0, -1, 1, 0, 0, 0).Transform(0, 1, -1, 0, 0, 0)
		default:
			o.Transform(rnd(), rnd(), rnd(), rnd(), rnd(), rnd()).Translate(rnd(), rnd()).Scale(rnd(), rnd()).Transform(rnd(), rnd(), rnd(), rnd(), rnd(), rnd())
		}
		o.FillColor(RGB(1, 2, 3)).FillPaint(paint1).StrokeColor(RGB(2, 3, 4)).StrokePaint(paint0).Line(2, 1, 2, 5).Dash([]float32{1, 2, 3}, 0.5).Alpha(0.7).Blend(2)
		o.Font(f1, 12).TextStyle(1, 2, 0, 0.25).Smoothing(true, 2)
		o.FillPath(p1, 0).StrokePath(p0).FillPathAt(external, 1, 2, 3).FillPathRun(0, []Glyph{{Path: p0, X: 1, Y: 2}, {Path: p1, X: 3, Y: 4}})
		o.FillRect(1, 2, 3, 4).StrokeRect(1, 2, 3, 4).ClearRect(1, 2, 3, 4)
		o.FillText("one", 1, 2, 10).StrokeText("two", 1, 2, 10).Image(im1, 1, 2, 3, 4).ImageSub(im0, 0, 1, 2, 3, 4, 5, 6, 7).UseAt(child1, 1, 2).Use(child0)
		o.Save().ClipPath(p0, 0).ClipRect(1, 2, 3, 4).Shadow(RGB(3, 2, 1), 1, 2, 3).Filter("blur(1px)").Restore()
		o.GroupBegin(0.8, 2, 1, 2, 3, 4).MaskBegin(1, RGB(1, 2, 3), []byte{1, 2, 3}).FillRect(1, 1, 1, 1).MaskEnd().GroupEnd()
		o.Link(1, 2, 3, 4, "https://example.org/").Mark(MarkAltText, "alternate").FillText("three", 1, 2, 10).Ext([]byte{1, 2, 3})
		o.Font(f0, 14).FillText("tail", 10, 20, 30)
		spans, part, e := o.decodeSpans()
		if e != nil {
			t.Fatal(e)
		}
		points, _ := o.prefixKeys(spans, part)
		if len(points) == 0 {
			t.Fatal("no cuts")
		}
		chosen := points[(n*7)%len(points)]
		if n >= 120 {
			chosen = points[len(points)-2]
		}
		split, e := o.splitAt(spans, part, chosen.instr)
		if e != nil {
			t.Fatal(e)
		}
		fmt.Fprintf(out, "///|\ntest \"BDF prefix split matches upstream Go %d\" {\n check_prefix_split(%s,%d,%d,%s,%s,", n, splitBytes(o.Encode()), chosen.instr, chosen.off, splitBytes(split.Prefix.Encode()), splitBytes(split.Rest.Encode()))
		splitInts(out, fontInts(split.PrefixFonts))
		fmt.Fprint(out, ",")
		splitInts(out, fontInts(split.RestFonts))
		fmt.Fprint(out, ",")
		splitInts(out, split.PrefixObjects)
		fmt.Fprint(out, ",")
		splitInts(out, split.RestObjects)
		fmt.Fprint(out, ")\n}\n")
	}
}
