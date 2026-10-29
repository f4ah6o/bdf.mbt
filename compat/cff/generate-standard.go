//go:build ignore

// Generate the CFF standard name and encoding tables from upstream.
package main

import (
	"fmt"
	"github.com/shibukawa/bdf/internal/cff"
)

func main() {
	fmt.Println("///|\n// Generated from shibukawa/bdf internal/cff tables (MIT).\nlet standard_strings : Array[String] = [")
	for _, s := range cff.StandardStrings {
		fmt.Printf("  %q,\n", s)
	}
	fmt.Println("]\n\n///|\nlet standard_encoding : Array[String] = [")
	for _, s := range cff.StandardEncoding {
		fmt.Printf("  %q,\n", s)
	}
	fmt.Println("]")
}
