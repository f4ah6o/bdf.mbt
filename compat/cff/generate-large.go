//go:build ignore

// Build a compressed, large CFF execution-limit fixture and upstream CSV output.
package main

import (
	"bytes"
	"compress/gzip"
	"encoding/binary"
	"encoding/json"
	"github.com/shibukawa/bdf/converter/csv"
	"github.com/shibukawa/bdf/internal/cff"
	"github.com/shibukawa/bdf/internal/sfnt"
	"os"
	"path/filepath"
)

func num(v int) []byte { return []byte{29, byte(v >> 24), byte(v >> 16), byte(v >> 8), byte(v)} }
func main() {
	root := os.Args[1]
	raw, e := os.ReadFile(filepath.Join(root, "compat/font/fixtures/stix.otf"))
	if e != nil {
		panic(e)
	}
	base, e := sfnt.Parse(raw)
	if e != nil {
		panic(e)
	}
	call := func(i int) []byte { return []byte{byte(i - 107 + 139), 29} }
	var calls []byte
	for i := 0; i < 20; i++ {
		calls = append(calls, call(1)...)
	}
	push := bytes.Repeat([]byte{139}, 1000)
	push = append(push, 11)
	header := []byte{1, 0, 4, 1}
	names := cff.Index([][]byte{[]byte("LargeCFF")})
	strings := cff.Index(nil)
	global := cff.Index([][]byte{append(calls, 11), push})
	top := []cff.DictEntry{{Op: 17, Args: []float64{0}, Raw: num(0)}}
	encode := func(n int) []byte {
		return cff.EncodeDict(top, func(e cff.DictEntry) ([]int, bool) { return []int{n}, true })
	}
	offset := len(header) + len(names) + len(cff.Index([][]byte{encode(0)})) + len(strings) + len(global)
	huge := make([]byte, 2*1024*1024)
	huge[0] = 14
	charstrings := cff.Index([][]byte{{14}, append(call(0), 14), huge})
	var cffData []byte
	for _, part := range [][]byte{header, names, cff.Index([][]byte{encode(offset)}), strings, global, charstrings} {
		cffData = append(cffData, part...)
	}
	tables := map[string][]byte{}
	for _, name := range []string{"head", "hhea", "maxp", "name", "OS/2", "post"} {
		tables[name] = append([]byte(nil), base.Tables[name]...)
	}
	binary.BigEndian.PutUint16(tables["maxp"][4:], 3)
	binary.BigEndian.PutUint16(tables["hhea"][34:], 3)
	tables["hmtx"] = []byte{1, 244, 0, 0, 1, 244, 0, 0, 1, 244, 0, 0}
	tables["cmap"] = sfnt.BuildCmap(map[uint32]uint16{'A': 1})
	tables["CFF "] = cffData
	font := sfnt.Build(tables, true)
	var compressed bytes.Buffer
	z := gzip.NewWriter(&compressed)
	if _, e = z.Write(font); e != nil {
		panic(e)
	}
	if e = z.Close(); e != nil {
		panic(e)
	}
	dir, e := os.MkdirTemp("", "bdf-large-cff-")
	if e != nil {
		panic(e)
	}
	defer os.RemoveAll(dir)
	if e = os.WriteFile(filepath.Join(dir, "large.otf"), font, 0600); e != nil {
		panic(e)
	}
	input := []byte("A")
	res, e := csv.Convert(bytes.NewReader(input), int64(len(input)), &csv.Options{FontDirs: []string{dir}, NoSystemFonts: true, NoWOFF2: true, Header: csv.HeaderNo, Data: "none", Name: "People", Title: "Report"})
	if e != nil {
		panic(e)
	}
	var doc bytes.Buffer
	if e = res.Doc.WriteSingle(&doc); e != nil {
		panic(e)
	}
	if e = json.NewEncoder(os.Stdout).Encode(map[string]any{"font_gzip": compressed.Bytes(), "input": string(input), "bdf": doc.Bytes(), "warnings": res.Warnings}); e != nil {
		panic(e)
	}
}
