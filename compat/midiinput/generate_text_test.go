//go:build ignore

// Copy into upstream converter/midi and run TestCodexMidiText.
package midi

import (
	"encoding/binary"
	"encoding/json"
	"math/rand"
	"os"
	"path/filepath"
	"testing"

	"golang.org/x/text/encoding/japanese"
)

func TestCodexMidiText(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	type fixture struct {
		Input []byte `json:"input"`
		Want  any    `json:"want"`
	}
	data := []fixture{}
	add := func(fields [][]byte) {
		body := []byte{}
		for _, s := range fields {
			body = append(body, 0, 0xff, 1, byte(len(s)))
			body = append(body, s...)
		}
		body = append(body, 0, 0xff, 0x2f, 0)
		file := fixtureHeader(0, 1, 480)[:14]
		file = append(file, []byte("MTrk\x00\x00\x00\x00")...)
		binary.BigEndian.PutUint32(file[18:22], uint32(len(body)))
		file = append(file, body...)
		c := &chunk{body: body}
		p := &parser{o: &Options{}, warned: map[string]bool{}, maxTick: 1000000}
		if err := p.readTrack(c); err != nil {
			t.Fatal(err)
		}
		d := newDecoder([]*chunk{c}, riffInfo{})
		texts := []string{}
		names := []string{}
		for _, field := range c.texts {
			texts = append(texts, d.text(field.data))
			names = append(names, d.name(field.data))
		}
		data = append(data, fixture{file, map[string]any{"shiftJis": d.legacy == japanese.ShiftJIS, "texts": texts, "names": names}})
	}
	examples := [][]byte{nil, []byte(" abc \n"), []byte("\xef\xbb\xbfUTF8"), []byte("日本語"), {0x82, 0xb1, 0x82, 0xf1}, {0xe9}, {0x80}, {0x81}, {0xff}, {'a', 0, 'b'}, []byte("\xc2\x85 space \xe3\x80\x80")}
	for _, b := range examples {
		add([][]byte{b})
	}
	for _, a := range examples {
		for _, b := range examples {
			add([][]byte{a, b})
		}
	}
	for b := 0; b < 256; b++ {
		add([][]byte{{byte(b)}})
	}
	rng := rand.New(rand.NewSource(12309))
	for i := 0; i < 3000; i++ {
		fields := [][]byte{}
		for j := 0; j < 1+rng.Intn(4); j++ {
			b := make([]byte, rng.Intn(12))
			rng.Read(b)
			fields = append(fields, b)
		}
		add(fields)
	}
	out, err := json.Marshal(data)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/midiinput/text.json"), out, 0644); err != nil {
		t.Fatal(err)
	}
}
