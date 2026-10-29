//go:build ignore

// Verify a MoonBit-written single or split document with the upstream Go reader.
package main

import (
	"bytes"
	"crypto/ecdh"
	"fmt"
	"os"

	"github.com/shibukawa/bdf"
)

func main() {
	info, err := os.Stat(os.Args[1])
	if err != nil {
		panic(err)
	}
	var reader *bdf.Reader
	if info.IsDir() {
		reader, err = bdf.OpenSplit(os.Args[1])
	} else {
		reader, err = bdf.OpenSingleFile(os.Args[1])
	}
	if err != nil {
		panic(err)
	}
	defer reader.Close()
	var joined bytes.Buffer
	if err := reader.WriteSingle(&joined); err != nil {
		panic(err)
	}
	copy, err := bdf.OpenSingle(bytes.NewReader(joined.Bytes()), int64(joined.Len()))
	if err != nil {
		panic(err)
	}
	if reader.Encrypted() {
		if len(os.Args) > 2 && os.Args[2] == "ecdh" {
			// The committed public test fixture's P-256 private scalar is 42.
			raw := make([]byte, 32)
			raw[31] = 42
			key, err := ecdh.P256().NewPrivateKey(raw)
			if err != nil {
				panic(err)
			}
			if err := reader.UnlockECDH(key); err != nil {
				panic(err)
			}
			if err := copy.UnlockECDH(key); err != nil {
				panic(err)
			}
		} else {
			// The compatibility fixture uses the public test password "pass".
			password := "pass"
			if len(os.Args) > 2 && os.Args[2] == "unicode" {
				password = "ABC"
			}
			if err := reader.Unlock(password); err != nil {
				panic(err)
			}
			if err := copy.Unlock(password); err != nil {
				panic(err)
			}
		}
	}
	for _, part := range reader.Manifest.Parts {
		a, err := reader.Part(part.H)
		if err != nil {
			panic(err)
		}
		b, err := copy.Part(part.H)
		if err != nil {
			panic(err)
		}
		if !bytes.Equal(a, b) {
			panic("part differs after joining")
		}
	}
	fmt.Printf("Go reader opened and joined %d parts (encrypted: %v)\n", len(reader.Manifest.Parts), reader.Encrypted())
}
