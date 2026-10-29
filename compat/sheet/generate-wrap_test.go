package xlsx

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"github.com/shibukawa/bdf/converter/internal/linebreak"
	"math/rand"
	"os"
	"strings"
	"testing"
)

func TestCodexGenerateWrap(t *testing.T) {
	path := os.Getenv("BDF_SHEET_WRAP_FIXTURE")
	if path == "" {
		t.Skip("fixture path not set")
	}
	type line struct {
		Text                   string
		Width                  float64
		Explicit, Wrapped, CJK bool
	}
	type entry struct {
		Text  string
		Width float64
		Lines []line
	}
	cases := []entry{
		{Text: "one two three", Width: 5}, {Text: "\nA\n\n", Width: 4},
		{Text: "日本語、括弧（テスト）かなぁ", Width: 4},
		{Text: "abc-def ghi", Width: 4}, {Text: "a\u00a0b c", Width: 2},
		{Text: "  abc   def  ", Width: 2}, {Text: "x\r\ny\rz", Width: 0},
		{Text: "foo\u200bbar", Width: 3}, {Text: "", Width: 1},
		{Text: strings.Repeat("a", 1023) + "\r\nlater", Width: 100},
	}
	rng := rand.New(rand.NewSource(51))
	alphabet := []rune("abc-‐ 　\u00a0日本語「」ぁ、\t\n\r")
	for i := 0; i < 500; i++ {
		var s strings.Builder
		for j := 0; j < rng.Intn(25); j++ {
			s.WriteRune(alphabet[rng.Intn(len(alphabet))])
		}
		cases = append(cases, entry{Text: s.String(), Width: float64(rng.Intn(10))})
	}
	for i := range cases {
		text := strings.ReplaceAll(strings.ReplaceAll(cases[i].Text, "\r\n", "\n"), "\r", "\n")
		items := []titem{}
		shown := 0
		for _, r := range text {
			if r == '\n' {
				items = append(items, titem{r: r, kind: itemBreak})
				shown++
			} else {
				if r == '\t' {
					r = ' '
				}
				if r < 0x20 {
					continue
				}
				items = append(items, titem{r: r, kind: itemChar, w: 1})
				shown++
			}
			if shown >= maxShown {
				break
			}
		}
		for _, l := range wrapItems(items, cases[i].Width) {
			var text strings.Builder
			width, visible := 0.0, 0.0
			for _, it := range l.items {
				text.WriteRune(it.r)
				width += it.w
				if !linebreak.IsSpace(it.r) {
					visible = width
				}
			}
			cases[i].Lines = append(cases[i].Lines, line{Text: text.String(), Width: visible, Explicit: l.explicit, Wrapped: l.wrapped, CJK: l.cjkWrap})
		}
	}
	f, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	if err := json.NewEncoder(f).Encode(cases); err != nil {
		t.Fatal(err)
	}
	if hashPath := os.Getenv("BDF_SHEET_BREAK_FIXTURE"); hashPath != "" {
		var hashes strings.Builder
		for mode := 0; mode < 4; mode++ {
			data := make([]byte, 0x110000)
			for code := range data {
				r := rune(code)
				var allowed bool
				switch mode {
				case 0:
					allowed = linebreak.Allowed('-', r)
				case 1:
					allowed = linebreak.Allowed('x', r)
				case 2:
					allowed = linebreak.Allowed(r, 'x')
				case 3:
					allowed = linebreak.Joins('x', r)
				}
				if allowed {
					data[code] = 1
				}
			}
			sum := sha256.Sum256(data)
			fmt.Fprintf(&hashes, "%x\n", sum)
		}
		if err := os.WriteFile(hashPath, []byte(hashes.String()), 0644); err != nil {
			t.Fatal(err)
		}
	}
}
