//go:build ignore

// Copy into upstream internal/sfnt alongside generate-outline_test.go.
package sfnt

import (
	"encoding/binary"
	"encoding/json"
	"github.com/shibukawa/bdf/internal/cff"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexCFFOutlines(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	results := []any{}
	add := func(name string, raw []byte, all bool) {
		f, err := Parse(raw)
		if err != nil {
			t.Fatal(name, err)
		}
		o := NewOutlines(f)
		cases := []any{}
		if o.cff != nil {
			n := len(o.cff.charStrings)
			if !all && n > 40 {
				n = 40
			}
			for g := 0; g < n; g++ {
				p := &codexOutlinePen{cmds: [][]any{}}
				ok := o.Outline(uint16(g), p)
				cases = append(cases, map[string]any{"glyph": g, "ok": ok, "commands": p.cmds})
			}
		}
		results = append(results, map[string]any{"name": name, "input": codexOutlinePack(raw), "valid": o.cff != nil, "cases": cases})
	}
	stix, err := os.ReadFile(filepath.Join(root, "compat/font/fixtures/stix.otf"))
	if err != nil {
		t.Fatal(err)
	}
	add("stix.otf", stix, true)
	mathFont, err := os.ReadFile("testdata/STIXTwoMath-cff-subset.otf")
	if err != nil {
		t.Fatal(err)
	}
	add("math.otf", mathFont, true)
	raw, err := os.ReadFile(filepath.Join(root, "compat/cff/sfnt.json"))
	if err != nil {
		t.Fatal(err)
	}
	var synthetic []struct {
		Name string `json:"name"`
		Data []byte `json:"data"`
	}
	if err = json.Unmarshal(raw, &synthetic); err != nil {
		t.Fatal(err)
	}
	for _, v := range synthetic {
		add(v.Name, v.Data, false)
	}

	// Many short programs deliberately exercise Type 2 operators, width operands,
	// hint masks, subroutines and incomplete input in one small font.
	rngPrograms := rand.New(rand.NewSource(34781))
	programs := [][]byte{{14}, {139, 139, 21, 149, 139, 5, 14}, {139, 139, 21, 139, 149, 149, 139, 139, 129, 8, 14}}
	ops := []byte{1, 3, 18, 19, 20, 21, 22, 4, 5, 6, 7, 8, 24, 25, 26, 27, 30, 31, 10, 29, 11, 14, 12}
	for n := 0; n < 700; n++ {
		cs := []byte{}
		for step := 0; step < 3+rngPrograms.Intn(12); step++ {
			for i := 0; i < rngPrograms.Intn(15); i++ {
				cs = append(cs, byte(90+rngPrograms.Intn(100)))
			}
			op := ops[rngPrograms.Intn(len(ops))]
			cs = append(cs, op)
			if op == 12 && rngPrograms.Intn(5) != 0 {
				cs = append(cs, byte(34+rngPrograms.Intn(4)))
			}
		}
		programs = append(programs, cs)
	}
	header := []byte{1, 0, 4, 1}
	names := cff.Index([][]byte{[]byte("Outline")})
	strings := cff.Index(nil)
	global := cff.Index([][]byte{{139, 139, 21, 149, 139, 5, 11}, {32, 29, 11}})
	top := func(offset int) []byte {
		return cff.Index([][]byte{{29, byte(offset >> 24), byte(offset >> 16), byte(offset >> 8), byte(offset), 17}})
	}
	offset := len(header) + len(names) + len(top(0)) + len(strings) + len(global)
	cffdata := []byte{}
	for _, part := range [][]byte{header, names, top(offset), strings, global, cff.Index(programs)} {
		cffdata = append(cffdata, part...)
	}
	maxp := []byte{0, 1, 0, 0, 0, 0}
	binary.BigEndian.PutUint16(maxp[4:], uint16(len(programs)))
	add("operators", Build(map[string][]byte{"maxp": maxp, "CFF ": cffdata}, true), true)
	base, err := Parse(stix)
	if err != nil {
		t.Fatal(err)
	}
	rng := rand.New(rand.NewSource(882155))
	for n := 0; n < 20; n++ {
		tables := map[string][]byte{}
		for k, v := range base.Tables {
			tables[k] = v
		}
		cff := append([]byte(nil), tables["CFF "]...)
		if n%4 == 0 {
			cff = cff[:rng.Intn(len(cff)+1)]
		} else {
			for j := 0; j < 1+rng.Intn(8); j++ {
				cff[rng.Intn(len(cff))] = byte(rng.Intn(256))
			}
		}
		tables["CFF "] = cff
		add("mutation", Build(tables, true), false)
	}
	out, err := json.Marshal(results)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/font/cff-outlines.json.gz"), codexOutlinePack(out), 0644); err != nil {
		t.Fatal(err)
	}
}
