//go:build ignore

// Copy into upstream converter/font and run TestCodexScroll.
package font

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"

	"github.com/shibukawa/bdf"
	"github.com/shibukawa/bdf/converter/internal/canvas"
)

type scrollEvent struct {
	Kind  int     `json:"kind"`
	Value float64 `json:"value"`
	Name  string  `json:"name"`
}

func TestCodexScroll(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	results := []any{}
	add := func(events []scrollEvent) {
		doc := bdf.NewDocument()
		c := &converter{cvs: canvas.NewBuilder(doc, nil)}
		s := newScroll(c)
		rows := []any{}
		anchors := map[string]string{}
		pageFor := map[*canvas.Canvas]int{}
		for _, event := range events {
			switch event.Kind {
			case 0, 1:
				idx := len(s.rows)
				band := s.add(event.Value, func(p *pen, y float64) {
					page, ok := pageFor[p.cv]
					if !ok {
						page = len(pageFor) + 1
						pageFor[p.cv] = page
					}
					rows = append(rows, map[string]any{"index": idx, "page": page, "y": y})
					for name := range s.anchors {
						anchors[name] = p.link(name)
					}
				})
				band.keep = event.Kind == 1
			case 2:
				s.space(event.Value)
			case 3:
				s.anchor(event.Name)
			}
		}
		// With no rows there is no callback from which to ask for links.
		v := doc.NewView("test", bdf.ViewScroll, "Test")
		strips := s.finish(v)
		pages := []float64{}
		for _, strip := range strips {
			pages = append(pages, float64(strip.page.H))
		}
		anchorPages := map[string]any{}
		for name, link := range anchors {
			n, err := strconv.Atoi(strings.TrimPrefix(link, "#page="))
			if err != nil {
				t.Fatal(err)
			}
			anchorPages[name] = n
		}
		results = append(results, map[string]any{"events": events, "pages": pages, "rows": rows, "anchors": anchorPages})
	}
	add([]scrollEvent{})
	add([]scrollEvent{{Kind: 3, Name: "first"}, {Kind: 0, Value: 988}, {Kind: 3, Name: "at-cut"}, {Kind: 0, Value: 300}, {Kind: 3, Name: "end"}})
	add([]scrollEvent{{Kind: 1, Value: 988}, {Kind: 3, Name: "kept"}, {Kind: 0, Value: 300}, {Kind: 0, Value: 300}})
	rng := rand.New(rand.NewSource(98221))
	for n := 0; n < 220; n++ {
		events := []scrollEvent{}
		for i := 0; i < rng.Intn(100)+1; i++ {
			kind := rng.Intn(12)
			if kind < 8 {
				keep := 0
				if kind == 0 {
					keep = 1
				}
				events = append(events, scrollEvent{Kind: keep, Value: float64(rng.Intn(1601)) / 4})
			} else if kind < 10 {
				events = append(events, scrollEvent{Kind: 2, Value: float64(rng.Intn(241)) / 4})
			} else {
				events = append(events, scrollEvent{Kind: 3, Name: fmt.Sprintf("a%d", rng.Intn(12))})
			}
		}
		add(events)
	}
	raw, err := json.Marshal(results)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/specimen/scroll.json.gz"), packFixture(raw), 0644); err != nil {
		t.Fatal(err)
	}
}
