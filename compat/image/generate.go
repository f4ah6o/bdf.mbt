// Generate upstream.json with shibukawa/bdf at 4f9af52. From its checkout:
// go run /path/to/bdf.mbt/compat/image/generate.go > /path/to/bdf.mbt/compat/image/upstream.json
package main

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
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

func main() {
	var out []fixture
	for _, tc := range []struct{ file, name, title string }{
		{"flag.bmp", "flag.bmp", ""},
		{"icon.ico", "icon.ico", ""},
		{"flag.bmp", "写真.bmp", "絵の題名"},
		{"icon.ico", "", ""},
	} {
		data, err := os.ReadFile(filepath.Join("converter/image/testdata", tc.file))
		if err != nil {
			panic(err)
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
