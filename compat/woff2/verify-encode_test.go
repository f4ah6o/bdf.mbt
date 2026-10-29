//go:build ignore

// Copy into upstream font/woff2 and run TestCodexExternalWOFF2Encoding after
// npm run test:woff2-encode has written the encoded test fonts.
package woff2

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexExternalWOFF2Encoding(t *testing.T) {
	root := os.Getenv("BDF_FIXTURE_ROOT")
	if root == "" {
		t.Fatal("BDF_FIXTURE_ROOT required")
	}
	file, err := os.Open(filepath.Join(root, "compat/woff2/encode.json.gz"))
	if err != nil {
		t.Fatal(err)
	}
	defer file.Close()
	z, err := gzip.NewReader(file)
	if err != nil {
		t.Fatal(err)
	}
	data, err := io.ReadAll(z)
	if err != nil {
		t.Fatal(err)
	}
	var cases []struct {
		Name, Error string
		Decoded     []byte
	}
	if err = json.Unmarshal(data, &cases); err != nil {
		t.Fatal(err)
	}
	for i, c := range cases {
		if c.Error != "" {
			continue
		}
		encoded, err := os.ReadFile(filepath.Join(root, "_build/woff2-encoded", fmt.Sprintf("%d.woff2", i)))
		if err != nil {
			t.Fatal(err)
		}
		decoded, err := Decode(encoded)
		if err != nil {
			t.Fatalf("%s: %v", c.Name, err)
		}
		if !bytes.Equal(decoded, c.Decoded) {
			t.Fatalf("%s: decoded SFNT differs", c.Name)
		}
	}
}
