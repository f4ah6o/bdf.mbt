//go:build ignore

// Copy into upstream converter/midi and run TestCodexMidiInput.
package midi

import (
	"bytes"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

type inputCase struct {
	Input  []byte `json:"input"`
	Detect bool   `json:"detect"`
	Unwrap any    `json:"unwrap"`
}
type headerCase struct {
	Input []byte `json:"input"`
	Tick  int    `json:"tick"`
	Want  any    `json:"want"`
}
type varCase struct {
	Input []byte `json:"input"`
	Want  [2]int `json:"want"`
}

func fixtureChunk(id string, body []byte) []byte {
	var b bytes.Buffer
	b.WriteString(id)
	binary.Write(&b, binary.LittleEndian, uint32(len(body)))
	b.Write(body)
	if len(body)%2 != 0 {
		b.WriteByte(0)
	}
	return b.Bytes()
}
func fixtureRiff(chunks ...[]byte) []byte {
	data := []byte("RIFF\x00\x00\x00\x00RMID")
	for _, c := range chunks {
		data = append(data, c...)
	}
	return data
}
func fixtureHeader(format, tracks, division uint16) []byte {
	b := []byte("MThd\x00\x00\x00\x06\x00\x00\x00\x00\x00\x00MTrk\x00\x00\x00\x04\x00\xff\x2f\x00")
	binary.BigEndian.PutUint16(b[8:], format)
	binary.BigEndian.PutUint16(b[10:], tracks)
	binary.BigEndian.PutUint16(b[12:], division)
	return b
}
func TestCodexMidiInput(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	rng := rand.New(rand.NewSource(6323))
	inputs := []inputCase{}
	addInput := func(b []byte) {
		smf, info, err := unwrapRMID(b)
		out := map[string]any{"error": ""}
		if err != nil {
			out = map[string]any{"error": err.Error()}
		} else {
			out["smf"] = fmt.Sprintf("%x", smf)
			out["title"] = fmt.Sprintf("%x", info.title)
			out["copyright"] = fmt.Sprintf("%x", info.copyright)
		}
		inputs = append(inputs, inputCase{b, detect(b), out})
	}
	s := fixtureHeader(0, 1, 480)
	for _, b := range [][]byte{nil, []byte("MThd"), s, fixtureRiff(), fixtureRiff(fixtureChunk("data", nil)), fixtureRiff(fixtureChunk("data", s)), fixtureRiff(fixtureChunk("LIST", append([]byte("INFO"), append(fixtureChunk("INAM", []byte("name\x00")), fixtureChunk("ICOP", []byte("copyright"))...)...)), fixtureChunk("data", s)), fixtureRiff(fixtureChunk("data", s), fixtureChunk("data", []byte("other"))), fixtureRiff(fixtureChunk("LIST", append([]byte("INFO"), append(fixtureChunk("INAM", []byte("old")), fixtureChunk("INAM", []byte("new"))...)...)), fixtureChunk("data", s))} {
		addInput(b)
	}
	base := fixtureRiff(fixtureChunk("LIST", append([]byte("INFO"), append(fixtureChunk("INAM", []byte("name")), fixtureChunk("ICOP", []byte("rights"))...)...)), fixtureChunk("data", s))
	for i := 0; i < len(base); i++ {
		addInput(base[:i])
	}
	for i := 0; i < 500; i++ {
		b := append([]byte(nil), base...)
		for j := 0; j < 1+rng.Intn(4); j++ {
			b[rng.Intn(len(b))] = byte(rng.Intn(256))
		}
		addInput(b)
	}
	headers := []headerCase{}
	addHeader := func(b []byte, tick int) {
		p := &parser{o: &Options{}, warned: map[string]bool{}}
		_, err := p.parse(b)
		out := map[string]any{"error": ""}
		if err != nil {
			out = map[string]any{"error": err.Error()}
		} else {
			d := binary.BigEndian.Uint16(b[12:])
			out = map[string]any{"error": "", "format": int(binary.BigEndian.Uint16(b[8:])), "tracks": int(binary.BigEndian.Uint16(b[10:])), "division": int(d), "length": int(binary.BigEndian.Uint32(b[4:])), "smpte": d&0x8000 != 0, "num": p.tm.num, "den": p.tm.den, "maxTick": p.maxTick, "ppq": p.tm.ppq(int64(tick)), "warnings": p.warnings}
			if p.warnings == nil {
				out["warnings"] = []string{}
			}
		}
		headers = append(headers, headerCase{b, tick, out})
	}
	for _, b := range [][]byte{nil, []byte("MThd"), []byte("bad header"), []byte("MThd\x00\x00\x00\x05"), []byte("MThd\x00\x00\x00\x06"), []byte("MThd\xff\xff\xff\xff")} {
		addHeader(b, 0)
	}
	for i := 0; i < 3000; i++ {
		d := uint16(rng.Intn(65536))
		f := uint16(rng.Intn(7))
		tick := rng.Intn(100000)
		addHeader(fixtureHeader(f, 1, d), tick)
	}
	for _, d := range []uint16{0, 1, 96, 480, 32767, 0xe801, 0xe8ff, 0xe701, 0xe301, 0xe201, 0xe200, 0xff01, 0x8001} {
		for f := uint16(0); f <= 3; f++ {
			addHeader(fixtureHeader(f, 1, d), 12345)
		}
	}
	vars := []varCase{}
	for i := 0; i < 3000; i++ {
		b := make([]byte, rng.Intn(7))
		rng.Read(b)
		v, n := readVarlen(b)
		vars = append(vars, varCase{b, [2]int{v, n}})
	}
	output := map[string]any{"inputs": inputs, "headers": headers, "varlens": vars}
	encoded, e := json.Marshal(output)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(root, "compat/midiinput/upstream.json"), encoded, 0644); e != nil {
		t.Fatal(e)
	}
}
