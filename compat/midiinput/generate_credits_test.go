//go:build ignore

// Copy into upstream converter/midi and run TestCodexMidiCredits.
package midi

import (
	"encoding/binary"
	"encoding/json"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexMidiCredits(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	type fixture struct {
		Input []byte `json:"input"`
		Want  any    `json:"want"`
	}
	data := []fixture{}
	addFile := func(format uint16, bodies [][]byte, riffTitle, riffCopyright string) {
		file := fixtureHeader(format, uint16(len(bodies)), 480)[:14]
		chunks := []*chunk{}
		for i, body := range bodies {
			body = append(body, 0, 0xff, 0x2f, 0)
			file = append(file, []byte("MTrk\x00\x00\x00\x00")...)
			binary.BigEndian.PutUint32(file[len(file)-4:], uint32(len(body)))
			file = append(file, body...)
			c := &chunk{index: i, body: body}
			p := &parser{o: &Options{}, warned: map[string]bool{}, maxTick: 1000000}
			if err := p.readTrack(c); err != nil {
				t.Fatal(err)
			}
			chunks = append(chunks, c)
		}
		info := riffInfo{title: []byte(riffTitle), copyright: []byte(riffCopyright)}
		if riffTitle != "" || riffCopyright != "" {
			list := append([]byte("INFO"), fixtureChunk("INAM", info.title)...)
			list = append(list, fixtureChunk("ICOP", info.copyright)...)
			file = fixtureRiff(fixtureChunk("LIST", list), fixtureChunk("data", file))
		}
		parsed, err := Parse(file, nil)
		if err != nil {
			t.Fatal(err)
		}
		d := newDecoder(chunks, info)
		c := chunks[0]
		nchans := 0
		for _, n := range c.notes {
			if len(n) > 0 {
				nchans++
			}
		}
		names := [][2]string{}
		for ch := 0; ch < 16; ch++ {
			names = append(names, [2]string{d.trackName(c, ch, nchans, false, 0, format == 0), d.trackName(c, ch, nchans, true, ch*7, format == 0)})
		}
		perf := parsed.Perf
		data = append(data, fixture{file, map[string]any{"title": perf.Title, "composer": perf.Composer, "lyricist": perf.Lyricist, "arranger": perf.Arranger, "copyright": perf.Copyright, "names": names}})
	}
	add := func(format uint16, body []byte) { addFile(format, [][]byte{body}, "", "") }

	meta := func(body []byte, kind byte, s string) []byte {
		v := []byte(s)
		body = append(body, 0, 0xff, kind, byte(len(v)))
		return append(body, v...)
	}
	names := []string{"", "Song", "Tempo", "Words", "Track 1", " Piano ", "日本語", "\tLead\n"}
	texts := []string{"", "@TThe Title", "@LJapanese", "Composer: Bach", "COMPOSED BY Mozart", "music by Beethoven", "作曲：滝廉太郎", "lyricist: A", "Lyrics by B", "作詞：田中", "Arranged by C", "編曲:D", "The Song", "@ignore", "Composer:", "music byX"}
	r := rand.New(rand.NewSource(845))
	for i := 0; i < 2000; i++ {
		format := uint16(r.Intn(3))
		b := []byte{}
		if r.Intn(2) == 0 {
			b = meta(b, 3, names[r.Intn(len(names))])
		}
		if r.Intn(3) == 0 {
			b = meta(b, 4, names[r.Intn(len(names))])
		}
		if r.Intn(3) == 0 {
			b = meta(b, 2, "Public domain")
		}
		for j := 0; j < r.Intn(5); j++ {
			b = meta(b, 1, texts[r.Intn(len(texts))])
		}
		if r.Intn(2) == 0 {
			b = append(b, 0, 0xff, 0x20, 1, byte(r.Intn(16)))
			b = meta(b, 3, names[r.Intn(len(names))])
		}
		for j := 0; j < r.Intn(3); j++ {
			ch := byte(r.Intn(16))
			b = append(b, 0, 0x90|ch, 60, 90, 1, 0x80|ch, 60, 0)
		}
		add(format, b)
	}
	for i := 0; i < 500; i++ {
		first := meta(nil, 3, names[r.Intn(len(names))])
		second := meta(nil, 1, texts[r.Intn(len(texts))])
		if r.Intn(2) == 0 {
			first = append(first, 0, 0x90, 60, 80, 1, 0x80, 60, 0)
		}
		if r.Intn(2) == 0 {
			second = meta(second, 2, "Track copyright")
		}
		addFile(1, [][]byte{first, second}, "RIFF title", "RIFF copyright")
	}

	out, err := json.Marshal(data)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/midiinput/credits.json"), out, 0644); err != nil {
		t.Fatal(err)
	}
}
