//go:build ignore

// Overlay beside the upstream pptx package and set BDF_REFERENCE_OUTPUT.
package pptx

import (
	"fmt"
	"github.com/shibukawa/bdf/converter/internal/ooxml"
	"math/rand"
	"os"
	"strings"
	"testing"
)

func codexPlaceholder(kind string, index *string, shape bool) *ooxml.Node {
	attr := fmt.Sprintf("type=%q", kind)
	if index != nil {
		attr += fmt.Sprintf(" idx=%q", *index)
	}
	content := "<ph " + attr + "/>"
	if shape {
		content = "<sp><nvSpPr><nvPr>" + content + "</nvPr></nvSpPr></sp>"
	}
	n, err := ooxml.Parse([]byte(content))
	if err != nil {
		panic(err)
	}
	return n
}
func codexPlaceholderText(kind string, index *string) string {
	i := "None"
	if index != nil {
		i = fmt.Sprintf("Some(%q)", *index)
	}
	return fmt.Sprintf("(%q,%s)", kind, i)
}
func TestCodexPPTXPlaceholders(t *testing.T) {
	out, err := os.Create(os.Getenv("BDF_REFERENCE_OUTPUT"))
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	kinds := []string{"obj", "title", "ctrTitle", "body", "dt", "ftr", "sldNum", "hdr", "chart", "pic", ""}
	indices := []string{"", "0", "1", "2", "01", "alpha"}
	rng := rand.New(rand.NewSource(81739))
	fmt.Fprintln(out, "///|\ntest \"PPTX placeholder matching agrees with upstream Go\" {\n let cases : Array[(Array[(String, String?)], (String, String?), Int32, Int32)] = [")
	for sample := 0; sample < 512; sample++ {
		count := rng.Intn(9)
		var shapes []*ooxml.Node
		var entries []string
		for i := 0; i < count; i++ {
			kind := kinds[rng.Intn(len(kinds))]
			var index *string
			if rng.Intn(3) != 0 {
				value := indices[rng.Intn(len(indices))]
				index = &value
			}
			shapes = append(shapes, codexPlaceholder(kind, index, true))
			entries = append(entries, codexPlaceholderText(kind, index))
		}
		targetKind := kinds[rng.Intn(len(kinds))]
		var targetIndex *string
		if rng.Intn(3) != 0 {
			value := indices[rng.Intn(len(indices))]
			targetIndex = &value
		}
		target := codexPlaceholder(targetKind, targetIndex, false)
		position := func(master bool) int {
			found := findPh(shapes, target, master)
			for i, shape := range shapes {
				if shape == found {
					return i
				}
			}
			return -1
		}
		fmt.Fprintf(out, "([%s],%s,%d,%d),\n", strings.Join(entries, ","), codexPlaceholderText(targetKind, targetIndex), position(false), position(true))
	}
	fmt.Fprintln(out, "]\n for (entries, target, layout, master) in cases {\n  let list = entries.map(fn(v) { PptxPlaceholder::{ kind: v.0, index: v.1 } })\n  let ph = PptxPlaceholder::{ kind: target.0, index: target.1 }\n  assert_eq(pptx_find_placeholder(list, ph, false), layout)\n  assert_eq(pptx_find_placeholder(list, ph, true), master)\n }\n}")
}
