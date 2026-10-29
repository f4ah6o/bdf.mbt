//go:build ignore

// Generate cmap rebuild hashes for synthetic fonts using the upstream writer.
package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"github.com/shibukawa/bdf/internal/sfnt"
	"os"
	"path/filepath"
)

func main() {
	data, err := os.ReadFile(filepath.Join(os.Args[1], "compat/font/synthetic.json"))
	if err != nil {
		panic(err)
	}
	var samples []struct {
		Data []byte `json:"data"`
	}
	if err = json.Unmarshal(data, &samples); err != nil {
		panic(err)
	}
	result := []string{}
	for _, sample := range samples {
		face, err := sfnt.Parse(sample.Data)
		if err != nil {
			panic(err)
		}
		checksum := sha256.Sum256(sfnt.BuildCmap(face.Cmap))
		result = append(result, hex.EncodeToString(checksum[:]))
	}
	if err := json.NewEncoder(os.Stdout).Encode(result); err != nil {
		panic(err)
	}
}
