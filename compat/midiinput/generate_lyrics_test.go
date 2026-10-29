//go:build ignore

// Copy into upstream converter/midi and run TestCodexMidiLyrics.
package midi

import (
	"encoding/binary"
	"encoding/json"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
	"unicode"
)

func TestCodexMidiLyrics(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	type fixture struct {
		Input []byte `json:"input"`
		Want  any    `json:"want"`
	}
	data := []fixture{}
	add := func(file []byte) {
		result, err := Parse(file, nil)
		if err != nil {
			t.Fatal(err)
		}
		out := []any{}
		for _, track := range result.Perf.Tracks {
			lyrics := [][2]any{}
			for _, lyric := range track.Lyrics {
				lyrics = append(lyrics, [2]any{lyric.Tick, lyric.Text})
			}
			out = append(out, lyrics)
		}
		data = append(data, fixture{file, out})
	}
	for _, name := range []string{"twinkle.kar", "twinkle.mid", "ode.mid", "ode.rmi"} {
		file, err := os.ReadFile(filepath.Join("testdata", name))
		if err != nil {
			t.Fatal(err)
		}
		add(file)
	}
	words := []string{"Twin", "kle", "little", "star", " A", "B ", "/new", "\\line", "あ", "いう", "é", "β", "Я", "-", "", " ", "\n", "x-y", "♥", "😀", "\u0085space\u0085", "\u00a0word\u00a0", "\u1680word\u1680", "\u2000word\u2000", "\u2028word\u2029", "\u3000word\u3000", "a\x00b", "\x01word", "\xef\xbb\xbfU"}
	rng := rand.New(rand.NewSource(1763))
	for i := 0; i < 2000; i++ {
		count := 1 + rng.Intn(4)
		division := []uint16{96, 480, 960}[rng.Intn(3)]
		file := fixtureHeader(uint16(rng.Intn(3)), uint16(count), division)[:14]
		for tr := 0; tr < count; tr++ {
			body := []byte{}
			if rng.Intn(3) == 0 {
				body = append(body, 0, 0xff, 3, 5, 'W', 'o', 'r', 'd', 's')
			}
			if rng.Intn(4) == 0 {
				body = append(body, 0, 0xff, 1, 2, '@', 'L')
			}
			for j := 0; j < 25; j++ {
				delta := byte(rng.Intn(31))
				ch := byte([]int{0, 1, 2, 9}[rng.Intn(4)])
				switch rng.Intn(6) {
				case 0, 1:
					body = append(body, delta, 0x90|ch, byte(60+rng.Intn(4)), byte(1+rng.Intn(127)))
				case 2:
					body = append(body, delta, 0x80|ch, byte(60+rng.Intn(4)), 0)
				default:
					s := []byte(words[rng.Intn(len(words))])
					typ := byte(5)
					if rng.Intn(3) == 0 {
						typ = 1
					}
					body = append(body, delta, 0xff, typ, byte(len(s)))
					body = append(body, s...)
				}
			}
			body = append(body, 0, 0xff, 0x2f, 0)
			file = append(file, []byte("MTrk\x00\x00\x00\x00")...)
			binary.BigEndian.PutUint32(file[len(file)-4:], uint32(len(body)))
			file = append(file, body...)
		}
		add(file)
	}
	// Exercise script and letter classification beyond a handful of common glyphs.
	letters := []rune{}
	for c := rune(0); c <= 0x2ffff; c++ {
		if unicode.IsLetter(c) && (unicode.Is(unicode.Latin, c) || unicode.Is(unicode.Greek, c) || unicode.Is(unicode.Cyrillic, c)) {
			letters = append(letters, c)
		}
	}
	for i := 0; i < 1200; i++ {
		chars := []string{string(letters[rng.Intn(len(letters))]), string(letters[rng.Intn(len(letters))]), " x "}
		body := []byte{0, 0x90, 60, 100}
		for _, value := range chars {
			b := []byte(value)
			body = append(body, 0, 0xff, 5, byte(len(b)))
			body = append(body, b...)
		}
		body = append(body, 1, 0x80, 60, 0, 0, 0xff, 0x2f, 0)
		file := fixtureHeader(0, 1, 480)[:14]
		file = append(file, []byte("MTrk\x00\x00\x00\x00")...)
		binary.BigEndian.PutUint32(file[len(file)-4:], uint32(len(body)))
		file = append(file, body...)
		add(file)
	}

	out, err := json.Marshal(data)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(root, "compat/midiinput/lyrics.json"), out, 0644); err != nil {
		t.Fatal(err)
	}
}
