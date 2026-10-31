//go:build ignore

// Remove the build tag and overlay this file in the upstream bdf package.
package bdf

import (
	"fmt"
	"os"
	"strings"
	"testing"
)

func budgetBytes(data []byte) string {
	var s strings.Builder
	s.WriteString(`b"`)
	for _, v := range data {
		fmt.Fprintf(&s, `\x%02x`, v)
	}
	s.WriteString(`"`)
	return s.String()
}

func TestCodexTextUseLimits(t *testing.T) {
	out, err := os.Create(os.Getenv("BDF_REFERENCE_OUTPUT"))
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	d := NewDocument()
	child := NewObject()
	child.FillText("child", 0, 0, 10)
	hash, bbox := d.AddObject(child)
	resolve := func(h Hash) *ObjectPart {
		p := d.Part(h)
		if p == nil {
			return nil
		}
		o, e := DecodeObject(p.Data)
		if e != nil {
			t.Fatal(e)
		}
		return o
	}
	for _, alt := range []bool{false, true} {
		p := NewObject()
		ref := p.AddObject(hash, bbox)
		if alt {
			p.Mark(MarkAltText, "alternate")
		}
		p.Use(ref)
		parent, e := DecodeObject(p.Encode())
		if e != nil {
			t.Fatal(e)
		}
		p2 := NewObject()
		p2.Use(p2.AddObject(hash, bbox))
		secondParent, e := DecodeObject(p2.Encode())
		if e != nil {
			t.Fatal(e)
		}
		for _, seed := range []int{0, MaxReusedInstructions - 1, MaxReusedInstructions} {
			limits := &useLimits{reused: seed}
			first, e1 := extractText(parent, resolve, limits)
			second, e2 := extractText(secondParent, resolve, limits)
			_, e3 := extractText(secondParent, resolve, limits)
			var left, right string
			for _, r := range first {
				left += r.Text
			}
			for _, r := range second {
				right += r.Text
			}
			fail1, fail2, fail3 := e1 != nil, e2 != nil, e3 != nil
			fmt.Fprintf(out, "///|\ntest \"Go shared text budget alt=%t seed=%d\" {\n check_shared_budget(%s,%s,%s,%q,%d,%t,%t,%t,%q,%q)\n}\n", alt, seed, budgetBytes(p.Encode()), budgetBytes(p2.Encode()), budgetBytes(child.Encode()), hash.String(), seed, fail1, fail2, fail3, left, right)
		}
	}
}
