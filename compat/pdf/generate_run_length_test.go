//go:build ignore

// Copy without its build tag beside upstream converter/pdf/objects.go and run
// TestCodexRunLengthReference with BDF_REFERENCE_OUTPUT set.
package pdf

import (
	"fmt"
	"math/rand"
	"os"
	"strings"
	"testing"
)

func runLengthBytes(b []byte) string {
	var s strings.Builder
	s.WriteString(`b"`)
	for _, c := range b {
		fmt.Fprintf(&s, `\x%02x`, c)
	}
	s.WriteString(`"`)
	return s.String()
}
func TestCodexRunLengthReference(t *testing.T) {
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dest == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(dest)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	rng := rand.New(rand.NewSource(70541))
	fmt.Fprintln(out, "///|\n// Generated from upstream PDF RunLengthDecode.\ntest \"PDF run lengths match upstream Go\" {")
	for i := 0; i < 1024; i++ {
		data := make([]byte, rng.Intn(200))
		rng.Read(data)
		if len(data) > 0 && i < 256 {
			data[0] = byte(i)
		}
		max := []int64{-1, 0, 1, 2, 10, 127, 128, 256, 1000}[rng.Intn(9)]
		fmt.Fprintf(out, "  assert_eq(pdf_decode_run_length(%s,%dL),%s)\n", runLengthBytes(data), max, runLengthBytes(decodeRunLength(data, max)))
	}
	fmt.Fprintln(out, "}")
}
