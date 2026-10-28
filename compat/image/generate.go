// Generate upstream.json with shibukawa/bdf at 4f9af52. From its checkout:
// go run /path/to/bdf.mbt/compat/image/generate.go > /path/to/bdf.mbt/compat/image/upstream.json
package main

import (
	"bytes"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	stdimage "image"
	"image/color"
	"image/jpeg"
	"os"
	"path/filepath"
	"unicode/utf16"

	"github.com/shibukawa/bdf/converter/image"
)

type fixture struct {
	Name      string       `json:"name"`
	Title     string       `json:"title"`
	Input     string       `json:"input"`
	Format    string       `json:"format"`
	Width     float64      `json:"width"`
	Height    float64      `json:"height"`
	Summary   string       `json:"summary"`
	Object    string       `json:"object"`
	ImageHash string       `json:"imageHash"`
	Prefixes  map[int]bool `json:"prefixes"`
	DC        any          `json:"dc"`
}

func jpegFixture(kind int) []byte {
	picture := stdimage.NewNRGBA(stdimage.Rect(0, 0, 7, 5))
	for y := 0; y < 5; y++ {
		for x := 0; x < 7; x++ {
			picture.Set(x, y, color.NRGBA{uint8(x * 30), uint8(y * 40), 80, 255})
		}
	}
	var encoded bytes.Buffer
	if err := jpeg.Encode(&encoded, picture, nil); err != nil {
		panic(err)
	}
	data := encoded.Bytes()
	if kind == 1 {
		return data
	}
	var payload []byte
	if kind == 2 {
		payload = []byte("Exif\x00\x00II\x2a\x00\x08\x00\x00\x00\x01\x00\x12\x01\x03\x00\x01\x00\x00\x00\x06\x00\x00\x00\x00\x00\x00\x00")
	} else {
		packet := `<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"><rdf:Description xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:xmp="http://ns.adobe.com/xap/1.0/" xmp:CreateDate="2026-09-01T12:00:00Z"><dc:title><rdf:Alt><rdf:li xml:lang="ja">題名</rdf:li><rdf:li xml:lang="x-default">Default title</rdf:li></rdf:Alt></dc:title><dc:description>A landscape</dc:description><dc:subject><rdf:Bag><rdf:li>one</rdf:li><rdf:li>two</rdf:li></rdf:Bag></dc:subject></rdf:Description></rdf:RDF>`
		packetBytes := append([]byte{0xef, 0xbb, 0xbf}, []byte(packet)...)
		if kind == 4 || kind == 5 {
			packet = `<?xml version="1.0" encoding="UTF-16"?>` + packet
			packetBytes = []byte{0xff, 0xfe}
			var order binary.ByteOrder = binary.LittleEndian
			if kind == 5 {
				packetBytes = []byte{0xfe, 0xff}
				order = binary.BigEndian
			}
			for _, unit := range utf16.Encode([]rune(packet)) {
				pair := make([]byte, 2)
				order.PutUint16(pair, unit)
				packetBytes = append(packetBytes, pair...)
			}
		}
		payload = append([]byte("http://ns.adobe.com/xap/1.0/\x00"), packetBytes...)
	}
	length := len(payload) + 2
	segment := append([]byte{0xff, 0xe1, byte(length >> 8), byte(length)}, payload...)
	output := append([]byte{}, data[:2]...)
	output = append(output, segment...)
	return append(output, data[2:]...)
}

func main() {
	var out []fixture
	for _, tc := range []struct {
		file, name, title string
		jpeg              int
	}{
		{"flag.bmp", "flag.bmp", "", 0},
		{"icon.ico", "icon.ico", "", 0},
		{"flag.bmp", "写真.bmp", "絵の題名", 0},
		{"icon.ico", "", "", 0},
		{"", "plain.jpg", "", 1},
		{"", "rotated.jpg", "", 2},
		{"photo.jpg", "photo.jpg", "", 0},
		{"iptc.jpg", "iptc.jpg", "", 0},
		{"photo.jpg", "renamed.jpg", "Override", 0},
		{"", "xmp.jpg", "", 3},
		{"", "utf16le.jpg", "", 4},
		{"", "utf16be.jpg", "", 5},
	} {
		var data []byte
		if tc.jpeg != 0 {
			data = jpegFixture(tc.jpeg)
		} else {
			var err error
			data, err = os.ReadFile(filepath.Join("converter/image/testdata", tc.file))
			if err != nil {
				panic(err)
			}
		}
		result, err := image.Convert(bytes.NewReader(data), int64(len(data)), &image.Options{Title: tc.title, FileName: tc.name})
		if err != nil {
			panic(err)
		}
		page := result.Doc.Views[0].Pages[0]
		object := result.Doc.Part(page.Layers[0].Obj)
		prefixes := map[int]bool{}
		for n := 0; n <= len(data); n++ {
			if n > 50 && n != len(data)-1 && n != len(data) && n%127 != 0 {
				continue
			}
			_, err := image.Convert(bytes.NewReader(data[:n]), int64(n), nil)
			prefixes[n] = err == nil
		}
		out = append(out, fixture{tc.name, tc.title, base64.StdEncoding.EncodeToString(data), result.Format, result.Width, result.Height, result.Summary(), base64.StdEncoding.EncodeToString(object.Data), result.Doc.Parts()[0].Hash.String(), prefixes, result.Doc.Meta.DC})
	}
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	if err := enc.Encode(out); err != nil {
		panic(err)
	}
}
