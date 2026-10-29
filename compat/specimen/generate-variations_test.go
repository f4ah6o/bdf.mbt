//go:build ignore

// Copy into the upstream converter/font package with generate_test.go.
package font

import (
	"encoding/binary"
	"encoding/json"
	"github.com/shibukawa/bdf/internal/sfnt"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexVariations(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	source, e := os.ReadFile(filepath.Join(root, "compat/font/fixtures/variable.ttf"))
	if e != nil {
		t.Fatal(e)
	}
	f, e := sfnt.Parse(source)
	if e != nil {
		t.Fatal(e)
	}
	names := f.Tables["name"]
	results := []any{}
	add := func(name string, data []byte) {
		n, _ := parseNames(names)
		face := face{f: &sfnt.Font{Tables: map[string][]byte{"fvar": data}}, names: n}
		a, i := face.fvar()
		axes := []any{}
		instances := []any{}
		for _, v := range a {
			axes = append(axes, map[string]any{"tag": v.tag, "name": v.name, "min": v.min, "default": v.def, "max": v.max, "hidden": v.hidden})
		}
		for _, v := range i {
			instances = append(instances, map[string]any{"name": v.name, "postscript": v.ps, "coordinates": append([]float64{}, v.coords...)})
		}
		results = append(results, map[string]any{"name": name, "data": data, "axes": axes, "instances": instances})
	}
	original := f.Tables["fvar"]
	add("real", original)
	for i := 0; i < len(original); i++ {
		add("truncated", original[:i])
	}
	base := make([]byte, 16+2*20+3*14)
	binary.BigEndian.PutUint16(base, 1)
	binary.BigEndian.PutUint16(base[4:], 16)
	binary.BigEndian.PutUint16(base[8:], 2)
	binary.BigEndian.PutUint16(base[10:], 20)
	binary.BigEndian.PutUint16(base[12:], 3)
	binary.BigEndian.PutUint16(base[14:], 14)
	copy(base[16:], "wght")
	binary.BigEndian.PutUint32(base[20:], uint32(100*65536))
	binary.BigEndian.PutUint32(base[24:], uint32(400*65536))
	binary.BigEndian.PutUint32(base[28:], uint32(900*65536))
	binary.BigEndian.PutUint16(base[34:], 256)
	copy(base[36:], "slnt")
	binary.BigEndian.PutUint32(base[40:], 0xfff60000)
	binary.BigEndian.PutUint32(base[48:], uint32(30*65536))
	binary.BigEndian.PutUint16(base[52:], 1)
	binary.BigEndian.PutUint16(base[54:], 257)
	for i := 0; i < 3; i++ {
		p := 56 + 14*i
		binary.BigEndian.PutUint16(base[p:], uint16(258+i))
		binary.BigEndian.PutUint32(base[p+4:], uint32((300+i*100)*65536))
		binary.BigEndian.PutUint32(base[p+8:], uint32(i*65536))
		binary.BigEndian.PutUint16(base[p+12:], uint16(270+i))
	}
	add("synthetic", base)
	rng := rand.New(rand.NewSource(73574))
	for i := 0; i < 700; i++ {
		data := append([]byte(nil), base...)
		switch i % 5 {
		case 0:
			data = data[:rng.Intn(len(data)+1)]
		case 1:
			binary.BigEndian.PutUint16(data[4:], uint16(rng.Intn(65536)))
		case 2:
			binary.BigEndian.PutUint16(data[8:], uint16(rng.Intn(65536)))
		case 3:
			binary.BigEndian.PutUint16(data[10:], uint16(rng.Intn(100)))
		default:
			for j := 0; j < 1+rng.Intn(6); j++ {
				data[rng.Intn(len(data))] = byte(rng.Intn(256))
			}
		}
		add("mutation", data)
	}
	out, e := json.Marshal(map[string]any{"names": names, "cases": results})
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/specimen/variations.json.gz"), packFixture(out), 0644); e != nil {
		t.Fatal(e)
	}
}
