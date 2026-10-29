//go:build ignore

// Copy into upstream font/woff2 and run TestCodexWOFF2EncodeInputs.
package woff2

import (
	"bytes"
	"compress/gzip"
	"encoding/binary"
	"encoding/json"
	"os"
	"path/filepath"
	"sort"
	"testing"
)

func TestCodexWOFF2EncodeInputs(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	inputs := map[string][]byte{}
	for _, name := range []string{"stix.ttf", "stix.otf", "features.ttf", "restricted.ttf", "variable.ttf", "color.ttf"} {
		data, err := os.ReadFile(filepath.Join(root, "compat/font/fixtures", name))
		if err != nil {
			t.Fatal(err)
		}
		inputs[name] = data
	}
	for name, data := range testFonts(t) {
		inputs[name] = data
	}
	inputs["short"] = []byte("hello")
	inputs["invalid"] = make([]byte, 20)
	inputs["truncated"] = append([]byte{0, 1, 0, 0, 0, 1}, make([]byte, 6)...)
	badTable := make([]byte, 28)
	copy(badTable, []byte{0, 1, 0, 0, 0, 1})
	copy(badTable[12:], "head")
	binary.BigEndian.PutUint32(badTable[20:], 29)
	inputs["bad-table"] = badTable
	keys := []string{}
	for name := range inputs {
		keys = append(keys, name)
	}
	sort.Strings(keys)
	cases := []any{}
	for _, name := range keys {
		input := inputs[name]
		_, err := Encode(input)
		message := ""
		var expected []byte
		if err != nil {
			message = err.Error()
		} else {
			expected = buildSFNT(binary.BigEndian.Uint32(input), sfntTables(input))
		}
		cases = append(cases, map[string]any{"name": name, "input": input, "error": message, "decoded": expected})
	}
	data, err := json.Marshal(cases)
	if err != nil {
		t.Fatal(err)
	}
	var out bytes.Buffer
	z := gzip.NewWriter(&out)
	if _, err = z.Write(data); err != nil {
		t.Fatal(err)
	}
	if err = z.Close(); err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/woff2/encode.json.gz"), out.Bytes(), 0644); err != nil {
		t.Fatal(err)
	}
}
