//go:build ignore

// Generate convert/midi/lyric_scripts.mbt using the upstream Go toolchain.
package main

import (
	"fmt"
	"unicode"
)

func main() {
	fmt.Println("// Unicode letter and script ranges from Go's unicode tables (BSD-3-Clause).\n\n///|\nlet lyric_script_ranges : Array[(Int32, Int32, Int32)] = [")
	codes := []rune{}
	for c := rune(0); c <= unicode.MaxRune; c++ {
		if unicode.IsLetter(c) && (unicode.Is(unicode.Latin, c) || unicode.Is(unicode.Greek, c) || unicode.Is(unicode.Cyrillic, c)) {
			codes = append(codes, c)
		}
	}
	for i := 0; i < len(codes); {
		start := i
		stride := rune(1)
		if i+1 < len(codes) {
			stride = codes[i+1] - codes[i]
			i++
			for i+1 < len(codes) && codes[i+1]-codes[i] == stride {
				i++
			}
		}
		fmt.Printf("  (0x%x, 0x%x, %d),\n", codes[start], codes[i], stride)
		i++
	}
	fmt.Println("]")
}
