//go:build ignore

// Generate name-keyed and CID CFF subsets with the upstream implementation.
package main

import (
	"encoding/json"
	"github.com/shibukawa/bdf/internal/cff"
	"os"
)

func num(v int) []byte { return []byte{29, byte(v >> 24), byte(v >> 16), byte(v >> 8), byte(v)} }
func entry(op int, values ...int) cff.DictEntry {
	var raw []byte
	var args []float64
	for _, v := range values {
		raw = append(raw, num(v)...)
		args = append(args, float64(v))
	}
	return cff.DictEntry{Op: op, Args: args, Raw: raw}
}
func encode(entries []cff.DictEntry, offsets map[int][]int) []byte {
	return cff.EncodeDict(entries, func(e cff.DictEntry) ([]int, bool) { v, ok := offsets[e.Op]; return v, ok })
}
func nameFont(gsubrs, chars [][]byte) []byte {
	header := []byte{1, 0, 4, 1}
	name := cff.Index([][]byte{[]byte("Synthetic")})
	strings := cff.Index(nil)
	global := cff.Index(gsubrs)
	top := []cff.DictEntry{entry(17, 0)}
	pos := len(header) + len(name) + len(cff.Index([][]byte{encode(top, map[int][]int{17: {0}})})) + len(strings) + len(global)
	out := append([]byte{}, header...)
	out = append(out, name...)
	out = append(out, cff.Index([][]byte{encode(top, map[int][]int{17: {pos}})})...)
	out = append(out, strings...)
	out = append(out, global...)
	return append(out, cff.Index(chars)...)
}
func cidFont(format byte) []byte {
	header := []byte{1, 0, 4, 1}
	name := cff.Index([][]byte{[]byte("SyntheticCID")})
	strings := cff.Index(nil)
	global := cff.Index([][]byte{{11}, {139, 11}})
	chars := cff.Index([][]byte{{14}, {32, 10, 14}, {33, 29, 14}, {32, 10, 14}})
	localA := cff.Index([][]byte{{139, 11}, {11}})
	localB := cff.Index([][]byte{{11}, {140, 11}})
	priv := encode([]cff.DictEntry{entry(19, 0)}, map[int][]int{19: {6}})
	blocks := [][]byte{append(append([]byte{}, priv...), localA...), append(append([]byte{}, priv...), localB...)}
	top := []cff.DictEntry{entry(1230, 0, 0, 0), entry(17, 0), entry(1236, 0), entry(1237, 0)}
	fd := []cff.DictEntry{entry(18, 0, 0)}
	fdIndex := func(a, b int) []byte {
		return cff.Index([][]byte{encode(fd, map[int][]int{18: {6, a}}), encode(fd, map[int][]int{18: {6, b}})})
	}
	sel := []byte{0, 0, 1, 1, 0}
	if format == 3 {
		sel = []byte{3, 0, 3, 0, 0, 0, 0, 1, 1, 0, 3, 0, 0, 4}
	}
	placeholder := map[int][]int{17: {0}, 1236: {0}, 1237: {0}}
	offset := len(header) + len(name) + len(cff.Index([][]byte{encode(top, placeholder)})) + len(strings) + len(global)
	selOff := offset
	offset += len(sel)
	csOff := offset
	offset += len(chars)
	fdOff := offset
	offset += len(fdIndex(0, 0))
	p0 := offset
	offset += len(blocks[0])
	p1 := offset
	topIdx := cff.Index([][]byte{encode(top, map[int][]int{17: {csOff}, 1236: {fdOff}, 1237: {selOff}})})
	var out []byte
	for _, part := range [][]byte{header, name, topIdx, strings, global, sel, chars, fdIndex(p0, p1), blocks[0], blocks[1]} {
		out = append(out, part...)
	}
	return out
}
func main() {
	chars := make([][]byte, 391)
	for i := range chars {
		chars[i] = []byte{14}
	}
	chars[1] = []byte{32, 29, 14}                 // global subr 0
	chars[2] = []byte{139, 139, 204, 247, 85, 14} // seac A + grave
	chars[3] = []byte{139, 139, 12, 10, 14}       // unsupported arithmetic
	global := [][]byte{{139, 11}, {140, 11}, {11}}
	cases := []struct {
		name string
		data []byte
		gids []int
	}{
		{"global", nameFont(global, chars), []int{1}},
		{"seac", nameFont(global, chars), []int{2}},
		{"arithmetic", nameFont(global, chars), []int{3}},
		{"cid-format0", cidFont(0), []int{1, 2}},
		{"cid-format3", cidFont(3), []int{2, 3}},
	}
	out := []any{}
	for _, s := range cases {
		keep := map[int]bool{}
		for _, g := range s.gids {
			keep[g] = true
		}
		data, order, err := cff.Subset(s.data, keep)
		if err != nil {
			panic(s.name + ": " + err.Error())
		}
		out = append(out, map[string]any{"name": s.name, "data": s.data, "gids": s.gids, "program": data, "order": order})
	}
	call := func(index int) []byte { return []byte{byte(index - 107 + 139), 29} }
	var explosive [][]byte
	for level := 0; level < 10; level++ {
		var routine []byte
		for n := 0; n < 8 && level < 9; n++ {
			routine = append(routine, call(level+1)...)
		}
		explosive = append(explosive, append(routine, 11))
	}
	bomb := nameFont(explosive, [][]byte{append(call(0), 14)})
	_, _, err := cff.Subset(bomb, map[int]bool{0: true})
	if err != cff.ErrTooLong {
		panic("expected execution budget failure")
	}
	out = append(out, map[string]any{"name": "execution-budget", "data": bomb, "gids": []int{0}, "error": err.Error()})
	push := make([]byte, 1000)
	for i := range push {
		push[i] = 139
	}
	push = append(push, 11)
	var calls []byte
	for i := 0; i < 20; i++ {
		calls = append(calls, call(1)...)
	}
	stack := nameFont([][]byte{append(calls, 11), push}, [][]byte{append(call(0), 14)})
	_, _, err = cff.Subset(stack, map[int]bool{0: true})
	if err != cff.ErrTooLong {
		panic("expected operand stack failure")
	}
	out = append(out, map[string]any{"name": "operand-stack", "data": stack, "gids": []int{0}, "error": err.Error()})
	if err := json.NewEncoder(os.Stdout).Encode(out); err != nil {
		panic(err)
	}
}
