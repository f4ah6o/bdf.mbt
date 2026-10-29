// Generate upstream.json with shibukawa/bdf at 4f9af52. From its checkout:
// go run /path/to/bdf.mbt/compat/image/generate.go > /path/to/bdf.mbt/compat/image/upstream.json
package main

import (
	"bytes"
	"compress/zlib"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"hash/crc32"
	stdimage "image"
	"image/color"
	"image/jpeg"
	"image/png"
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
	Animated  bool         `json:"animated"`
	Warnings  []string     `json:"warnings"`
	PageW     float32      `json:"pageW"`
	PageH     float32      `json:"pageH"`
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

func pngChunk(kind string, data []byte) []byte {
	out := make([]byte, 12+len(data))
	binary.BigEndian.PutUint32(out[:4], uint32(len(data)))
	copy(out[4:8], kind)
	copy(out[8:], data)
	binary.BigEndian.PutUint32(out[8+len(data):], crc32.ChecksumIEEE(out[4:8+len(data)]))
	return out
}

func pngCompressed(value string) []byte {
	var out bytes.Buffer
	writer := zlib.NewWriter(&out)
	if _, err := writer.Write([]byte(value)); err != nil {
		panic(err)
	}
	if err := writer.Close(); err != nil {
		panic(err)
	}
	return out.Bytes()
}

func pngFixture() []byte {
	picture := stdimage.NewNRGBA(stdimage.Rect(0, 0, 7, 5))
	for y := 0; y < 5; y++ {
		for x := 0; x < 7; x++ {
			picture.Set(x, y, color.NRGBA{uint8(x * 30), uint8(y * 40), 80, 255})
		}
	}
	var encoded bytes.Buffer
	if err := png.Encode(&encoded, picture); err != nil {
		panic(err)
	}
	data := encoded.Bytes()
	out := append([]byte{}, data[:33]...)
	out = append(out, pngChunk("tEXt", []byte("Title\x00Native title"))...)
	out = append(out, pngChunk("zTXt", append([]byte("Author\x00\x00"), pngCompressed("Ann")...))...)
	out = append(out, pngChunk("iTXt", append([]byte("Description\x00\x01\x00\x00\x00"), pngCompressed("圧縮された説明")...))...)
	exif := []byte("II\x2a\x00\x08\x00\x00\x00\x01\x00\x12\x01\x03\x00\x01\x00\x00\x00\x06\x00\x00\x00\x00\x00\x00\x00")
	out = append(out, pngChunk("eXIf", exif)...)
	packet := `<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"><rdf:Description xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>XMP title</dc:title></rdf:Description></rdf:RDF>`
	out = append(out, pngChunk("iTXt", append([]byte("XML:com.adobe.xmp\x00\x00\x00\x00\x00"), []byte(packet)...))...)
	out = append(out, pngChunk("tIME", []byte{0x07, 0xea, 9, 2, 8, 0, 0})...)
	return append(out, data[33:]...)
}

func webpChunk(out *bytes.Buffer, kind string, data []byte) {
	out.WriteString(kind)
	if err := binary.Write(out, binary.LittleEndian, uint32(len(data))); err != nil {
		panic(err)
	}
	out.Write(data)
	if len(data)%2 != 0 {
		out.WriteByte(0)
	}
}

func webpFixture(kind string) []byte {
	var body bytes.Buffer
	body.WriteString("WEBP")
	switch kind {
	case "lossy":
		webpChunk(&body, "VP8 ", []byte{0, 0, 0, 0x9d, 1, 0x2a, 7, 0, 5, 0})
	case "lossless":
		webpChunk(&body, "VP8L", []byte{0x2f, 6, 0, 1, 0})
	case "animated":
		webpChunk(&body, "VP8X", []byte{0, 0, 0, 0, 6, 0, 0, 4, 0, 0})
		webpChunk(&body, "EXIF", []byte("II\x2a\x00\x08\x00\x00\x00\x01\x00\x12\x01\x03\x00\x01\x00\x00\x00\x06\x00\x00\x00\x00\x00\x00\x00"))
		webpChunk(&body, "ANMF", nil)
		webpChunk(&body, "ANMF", nil)
	}
	var out bytes.Buffer
	out.WriteString("RIFF")
	if err := binary.Write(&out, binary.LittleEndian, uint32(body.Len())); err != nil {
		panic(err)
	}
	out.Write(body.Bytes())
	return out.Bytes()
}

func isoBox(kind string, data []byte) []byte {
	out := make([]byte, 8+len(data))
	binary.BigEndian.PutUint32(out[:4], uint32(len(out)))
	copy(out[4:8], kind)
	copy(out[8:], data)
	return out
}

func avifSequence() []byte {
	tkhd := make([]byte, 84)
	binary.BigEndian.PutUint32(tkhd[76:], 64<<16)
	binary.BigEndian.PutUint32(tkhd[80:], 48<<16)
	out := isoBox("ftyp", []byte("avis\x00\x00\x00\x00avis"))
	return append(out, isoBox("moov", isoBox("trak", isoBox("tkhd", tkhd)))...)
}

func main() {
	svgs := map[string]string{
		"units.svg":           `<svg xmlns="http://www.w3.org/2000/svg" width="1cm" height="1in"><title>Units</title></svg>`,
		"fraction.svg":        `<svg xmlns="http://www.w3.org/2000/svg" width="0.1" height="0.3"><title>Small</title></svg>`,
		"ratio.svg":           `<svg xmlns="http://www.w3.org/2000/svg" width="1.25in" viewBox="0 0 4 3"><desc>A landscape</desc></svg>`,
		"default.svg":         `<svg xmlns="http://www.w3.org/2000/svg"/>`,
		"no-namespace.svg":    `<svg width="1em" height="2ex"><title>Hi <tspan>there</tspan> !</title></svg>`,
		"truncated-root.svg":  `<svg xmlns="http://www.w3.org/2000/svg" width="11" height="12">`,
		"truncated-child.svg": `<svg xmlns="http://www.w3.org/2000/svg" width="11" height="12"><title>Title</title><desc>Some text`,
		"truncated-tag.svg":   `<svg xmlns="http://www.w3.org/2000/svg" width="11" height="12"><title>Title</title><rect`,
	}
	webps := map[string]string{
		"synthetic-lossy.webp":    "lossy",
		"synthetic-lossless.webp": "lossless",
		"synthetic-animated.webp": "animated",
	}
	dates := map[string]string{
		"date-rfc1123z.png": "Tue, 01 Sep 2026 10:20:30 +0900",
		"date-rfc1123.png":  "Tue, 01 Sep 2026 10:20:30 UTC",
		"date-rfc822z.png":  "01 Sep 26 10:20 +0900",
		"date-rfc822.png":   "01 Sep 26 10:20 UTC",
		"date-rfc850.png":   "Sunday, 06-Nov-94 08:49:37 GMT",
		"date-ansic.png":    "Tue Sep  1 10:20:30 2026",
		"date-short.png":    "1 Sep 2026 10:20:30 +0900",
		"date-zone.png":     "Tue, 1 Sep 2026 10:20:30 +0960",
	}
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
		{"tags.png", "tags.png", "", 0},
		{"anim.png", "anim.png", "", 0},
		{"metadata.png", "metadata.png", "", 0},
		{"date-rfc1123z.png", "date-rfc1123z.png", "", 0},
		{"date-rfc1123.png", "date-rfc1123.png", "", 0},
		{"date-rfc822z.png", "date-rfc822z.png", "", 0},
		{"date-rfc822.png", "date-rfc822.png", "", 0},
		{"date-rfc850.png", "date-rfc850.png", "", 0},
		{"date-ansic.png", "date-ansic.png", "", 0},
		{"date-short.png", "date-short.png", "", 0},
		{"date-zone.png", "date-zone.png", "", 0},
		{"anim.gif", "anim.gif", "", 0},
		{"xmp.gif", "xmp.gif", "", 0},
		{"scene.webp", "scene.webp", "", 0},
		{"rotated.avif", "rotated.avif", "", 0},
		{"drawing.svg", "drawing.svg", "", 0},
		{"units.svg", "units.svg", "", 0},
		{"fraction.svg", "fraction.svg", "", 0},
		{"ratio.svg", "ratio.svg", "", 0},
		{"default.svg", "default.svg", "", 0},
		{"no-namespace.svg", "no-namespace.svg", "", 0},
		{"truncated-root.svg", "truncated-root.svg", "", 0},
		{"truncated-child.svg", "truncated-child.svg", "", 0},
		{"truncated-tag.svg", "truncated-tag.svg", "", 0},
		{"synthetic-sequence.avif", "synthetic-sequence.avif", "", 0},
		{"synthetic-lossy.webp", "synthetic-lossy.webp", "", 0},
		{"synthetic-lossless.webp", "synthetic-lossless.webp", "", 0},
		{"synthetic-animated.webp", "synthetic-animated.webp", "", 0},
	} {
		var data []byte
		if svg, ok := svgs[tc.file]; ok {
			data = []byte(svg)
		} else if tc.file == "synthetic-sequence.avif" {
			data = avifSequence()
		} else if kind, ok := webps[tc.file]; ok {
			data = webpFixture(kind)
		} else if date, ok := dates[tc.file]; ok {
			original := pngFixture()
			data = append([]byte{}, original[:33]...)
			data = append(data, pngChunk("tEXt", append([]byte("Creation Time\x00"), []byte(date)...))...)
			data = append(data, original[33:]...)
		} else if tc.file == "metadata.png" {
			data = pngFixture()
		} else if tc.jpeg != 0 {
			data = jpegFixture(tc.jpeg)
		} else {
			var err error
			file := tc.file
			if file == "anim.png" {
				file = "tags.png"
			}
			if file == "xmp.gif" {
				file = "anim.gif"
			}
			data, err = os.ReadFile(filepath.Join("converter/image/testdata", file))
			if err != nil {
				panic(err)
			}
		}
		if tc.file == "anim.png" {
			chunk := []byte{0, 0, 0, 8, 'a', 'c', 'T', 'L', 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0}
			combined := append([]byte{}, data[:33]...)
			combined = append(combined, chunk...)
			data = append(combined, data[33:]...)
		}
		if tc.file == "xmp.gif" {
			packet := `<?xpacket begin=""?><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"><rdf:Description xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>GIF title</dc:title><dc:description>XMP description</dc:description></rdf:Description></rdf:RDF><?xpacket end="w"?>`
			extension := append([]byte{0x21, 0xff, 0x0b}, []byte("XMP DataXMP")...)
			extension = append(extension, []byte(packet)...)
			extension = append(extension, 0)
			result := append([]byte{}, data[:len(data)-1]...)
			result = append(result, extension...)
			data = append(result, data[len(data)-1:]...)
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
		out = append(out, fixture{tc.name, tc.title, base64.StdEncoding.EncodeToString(data), result.Format, result.Width, result.Height, result.Summary(), base64.StdEncoding.EncodeToString(object.Data), result.Doc.Parts()[0].Hash.String(), prefixes, result.Doc.Meta.DC, result.Animated, append([]string{}, result.Warnings...), page.W, page.H})
	}
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	if err := enc.Encode(out); err != nil {
		panic(err)
	}
}
