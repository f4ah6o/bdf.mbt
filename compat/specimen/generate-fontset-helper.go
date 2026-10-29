//go:build ignore

// Copy into upstream converter/internal/fontset for TestCodexSpecimenTexter.
package fontset

import "sort"

// CodexFixtureUsage exposes the measurements collected by the upstream set.
func CodexFixtureUsage(s *Set) ([]any, []int) {
	rows := []struct {
		Path  string
		Index int
		Codes []int
	}{}
	for face, runes := range s.runes {
		codes := []int{}
		for r := range runes {
			codes = append(codes, int(r))
		}
		sort.Ints(codes)
		rows = append(rows, struct {
			Path  string
			Index int
			Codes []int
		}{face.Path, face.Index, codes})
	}
	sort.Slice(rows, func(i, j int) bool {
		if rows[i].Path == rows[j].Path {
			return rows[i].Index < rows[j].Index
		}
		return rows[i].Path < rows[j].Path
	})
	result := []any{}
	for _, r := range rows {
		result = append(result, map[string]any{"path": r.Path, "index": r.Index, "codes": r.Codes})
	}
	missing := []int{}
	for r := range s.missing {
		missing = append(missing, int(r))
	}
	sort.Ints(missing)
	return result, missing
}
