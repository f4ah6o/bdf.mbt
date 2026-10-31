//go:build ignore

// Copy without its build tag beside upstream converter/pdf/objects.go and run
// TestCodexASCIIFilters with BDF_REFERENCE_OUTPUT set.
package pdf

import (
	"bytes"
	"encoding/ascii85"
	"encoding/hex"
	"fmt"
	"github.com/pdfcpu/pdfcpu/pkg/filter"
	"io"
	"math/rand"
	"os"
	"strings"
	"testing"
)

func asciiBytes(b []byte) string {
	var s strings.Builder
	s.WriteString(`b"`)
	for _, c := range b {
		fmt.Fprintf(&s, `\x%02x`, c)
	}
	s.WriteString(`"`)
	return s.String()
}
func TestCodexASCIIFilters(t *testing.T) {
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dest == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(dest)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	rng := rand.New(rand.NewSource(123901))
	fmt.Fprintln(out, "///|\n// Generated from the upstream PDF ASCII85 and ASCIIHex filters.\ntest \"PDF ASCII filters match upstream Go\" {")
	for i := 0; i < 2048; i++ {
		raw := make([]byte, rng.Intn(50))
		rng.Read(raw)
		name := filter.ASCIIHex
		kind := 0
		var input []byte
		if i%2 == 0 {
			input = []byte(hex.EncodeToString(raw))
			input = append(input, '>')
		} else {
			name = filter.ASCII85
			kind = 1
			input = make([]byte, ascii85.MaxEncodedLen(len(raw)))
			n := ascii85.Encode(input, raw)
			input = append(input[:n], '~', '>')
		}
		switch i % 11 {
		case 0:
			input = nil
		case 1:
			if len(input) > 0 {
				input = input[:len(input)-1]
			}
		case 2:
			input = append([]byte(" \n\x00\t"), input...)
		case 3:
			if len(input) > 2 {
				input[1] = 'z'
			}
		case 4:
			if len(input) > 2 {
				input[1] = 0xff
			}
		case 5:
			input = append(input, 'q', 'q')
		case 6:
			if len(input) > 2 {
				input = append(input[:1], input[2:]...)
			}
		case 7:
			input = []byte("z~>")
		case 8:
			input = []byte("!~>")
		case 9:
			input = []byte("uuuuu~>")
		case 10:
			input = []byte("0>")
		}
		var decoded []byte
		var e error
		if name == filter.ASCII85 && len(input) == 0 {
			decoded = nil
		} else {
			fi, err := filter.NewFilter(name, nil)
			if err != nil {
				t.Fatal(err)
			}
			var r io.Reader
			r, e = fi.Decode(bytes.NewReader(input))
			if e == nil {
				decoded, e = io.ReadAll(r)
			}
		}
		expected := "None"
		if e == nil {
			expected = "Some(" + asciiBytes(decoded) + ")"
		}
		fmt.Fprintf(out, "  check_pdf_ascii(%d,%s,%s)\n", kind, asciiBytes(input), expected)
	}
	fmt.Fprintln(out, `}

///|
fn check_pdf_ascii(kind : Int, data : Bytes, expected : Bytes?) -> Unit raise {
  let actual : Bytes? = try {
    if kind == 0 { Some(pdf_decode_ascii_hex(data)) } else { Some(pdf_decode_ascii85(data)) }
  } catch { _ => None }
  assert_eq(actual, expected)
}`)
}
