//go:build ignore

// Remove the build tag and overlay into upstream package bdf.
package bdf

import (
	"fmt"
	"os"
	"strings"
	"testing"
)

func cutFixtureBytes(data []byte) string {
	var s strings.Builder
	s.WriteString(`b"`)
	for _, v := range data {
		fmt.Fprintf(&s, `\x%02x`, v)
	}
	s.WriteString(`"`)
	return s.String()
}
func TestCodexPrefixCuts(t *testing.T) {
	out, e := os.Create(os.Getenv("BDF_REFERENCE_OUTPUT"))
	if e != nil {
		t.Fatal(e)
	}
	defer out.Close()
	state := uint64(0x8a52e4)
	next := func() uint64 { state ^= state << 13; state ^= state >> 7; state ^= state << 17; return state }
	for i := 0; i < 192; i++ {
		o := NewObject().SetBBox(0, 0, 400, 300)
		switch i {
		case 1:
			o.Save().ClipRect(1, 2, 3, 4).Restore().Mark(MarkAltText, "alt").FillText("hello", 1, 2, 3).GroupBegin(1, 0, 0, 0, 1, 1).MaskBegin(0, RGB(0, 0, 0), nil).FillRect(0, 0, 1, 1).MaskEnd().GroupEnd().FillRect(1, 2, 3, 4)
		case 2:
			o.FillRect(1, 2, 3, 4).ClipRect(1, 2, 3, 4).FillRect(2, 3, 4, 5)
		case 3:
			o.Save().Shadow(RGB(1, 2, 3), 1, 1, 1).Restore().FillRect(0, 0, 1, 1).Filter("blur(1px)").FillRect(0, 0, 2, 2)
		}
		for j := 0; i >= 4 && j < 32; j++ {
			switch next() % 20 {
			case 0:
				o.Save()
			case 1:
				o.Restore()
			case 2:
				o.ClipRect(1, 2, 30, 40)
			case 3:
				o.FillColor(RGB(1, 2, 3))
			case 4:
				o.FillRect(2, 3, 40, 50)
			case 5:
				o.Mark(MarkAltText, "alternate")
			case 6:
				o.FillText("hello", 2, 3, 20)
			case 7:
				o.GroupBegin(1, 0, 0, 0, 20, 20)
			case 8:
				o.GroupEnd()
			case 9:
				o.MaskBegin(0, RGB(0, 0, 0), []byte{1, 2, 3})
			case 10:
				o.MaskEnd()
			case 11:
				o.Shadow(RGB(1, 2, 3), 1, 2, 3)
			case 12:
				o.Filter("blur(1px)")
			case 13:
				o.Transform(1, 0, 0, 1, 5, 6)
			case 14:
				o.Translate(3, 4)
			case 15:
				o.Scale(2, 3)
			case 16:
				o.Dash([]float32{1, 2, 3}, 0.5)
			case 17:
				o.StrokeRect(1, 2, 3, 4)
			case 18:
				o.TextStyle(0, 0, 0, 0.2)
			case 19:
				o.Ext([]byte{1, 2, 3, 4})
			}
		}
		spans, part, e := o.decodeSpans()
		if e != nil {
			t.Fatal(e)
		}
		points, _ := o.prefixKeys(spans, part)
		fmt.Fprintf(out, "///|\ntest \"BDF prefix cut points match Go %d\" {\n check_prefix_cuts(%s, [", i, cutFixtureBytes(o.Encode()))
		for _, sp := range spans {
			fmt.Fprintf(out, "(%d,%d),", sp.start, sp.end)
		}
		fmt.Fprint(out, "], [")
		for _, p := range points {
			fmt.Fprintf(out, "(%d,%d),", p.instr, p.off)
		}
		fmt.Fprint(out, "])\n}\n")
	}
}
func TestCodexShareStringIndex(t *testing.T) {
	for _, threshold := range []int{0, 512} {
		doc := NewDocument()
		makeObj := func(text string) *Object {
			o := NewObject().SetBBox(0, 0, 100, 100)
			if threshold > 0 {
				for i := 0; i < 32; i++ {
					o.FillRect(float32(i), 0, 1, 1)
				}
			}
			o.FillText(text, 1, 2, 30).FillRect(1, 2, 3, 4)
			return o
		}
		pages := []*Object{makeObj("alpha"), makeObj("beta")}
		shares, e := SharePrefixes(pages, threshold)
		if e != nil || len(shares) != 1 {
			t.Fatalf("threshold %d sharing: %v %+v", threshold, e, shares)
		}
		h, _ := doc.AddObject(shares[0].Prefix)
		second := shares[0].Members[1].Rest
		second.UpdateObject(0, h)
		obj, e := DecodeObject(second.Encode())
		if e != nil {
			t.Fatal(e)
		}
		text, e := ExtractText(obj, func(h Hash) *ObjectPart {
			p := doc.Part(h)
			if p == nil {
				return nil
			}
			o, _ := DecodeObject(p.Data)
			return o
		})
		if e != nil {
			t.Fatal(e)
		}
		if len(text) != 1 || text[0].Text != "alpha" {
			t.Fatalf("threshold %d second page: %+v", threshold, text)
		}
		t.Logf("confirmed: threshold %d, second page beta becomes %q", threshold, text[0].Text)
	}
}
