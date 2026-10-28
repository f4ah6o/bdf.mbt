// Generate upstream.json with shibukawa/bdf at 4f9af52. From its checkout:
// go run /path/to/bdf.mbt/compat/image/generate.go > /path/to/bdf.mbt/compat/image/upstream.json
package main

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	stdimage "image"
	"image/color"
	"image/jpeg"
	"os"
	"path/filepath"

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
}

func jpegFixture(rotated bool) []byte {
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
	if !rotated {
		return data
	}
	exif := []byte("Exif\x00\x00II\x2a\x00\x08\x00\x00\x00\x01\x00\x12\x01\x03\x00\x01\x00\x00\x00\x06\x00\x00\x00\x00\x00\x00\x00")
	segment := append([]byte{0xff, 0xe1, 0, byte(len(exif) + 2)}, exif...)
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
	} {
		var data []byte
		if tc.jpeg != 0 {
			data = jpegFixture(tc.jpeg == 2)
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
		out = append(out, fixture{tc.name, tc.title, base64.StdEncoding.EncodeToString(data), result.Format, result.Width, result.Height, result.Summary(), base64.StdEncoding.EncodeToString(object.Data), result.Doc.Parts()[0].Hash.String(), prefixes})
	}
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	if err := enc.Encode(out); err != nil {
		panic(err)
	}
}
