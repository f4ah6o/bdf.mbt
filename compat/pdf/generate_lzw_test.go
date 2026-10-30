//go:build ignore

// Copy without its build tag beside upstream converter/pdf/objects.go and run
// TestCodexLZWReference with BDF_REFERENCE_OUTPUT set.
package pdf

import (
	"bytes"
	"fmt"
	"github.com/pdfcpu/pdfcpu/pkg/filter"
	"io"
	"math/rand"
	"os"
	"strings"
	"testing"
)

func lzwBytes(b []byte) string {
	var s strings.Builder
	s.WriteString(`b"`)
	for _, c := range b {
		fmt.Fprintf(&s, `\x%02x`, c)
	}
	s.WriteString(`"`)
	return s.String()
}
func codexLZW(data []byte, early, predictor int, max int64) ([]byte, error) {
	fi, err := filter.NewFilter(filter.LZW, map[string]int{"EarlyChange": early, "Predictor": predictor})
	if err != nil {
		return nil, err
	}
	r, err := fi.DecodeLength(bytes.NewReader(data), max+1)
	if err == nil {
		return io.ReadAll(r)
	}
	if err != io.EOF {
		return nil, err
	}
	r, err = fi.Decode(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}
	return io.ReadAll(r)
}
func encodeCodexLZW(t *testing.T, raw []byte, early int) []byte {
	fi, err := filter.NewFilter(filter.LZW, map[string]int{"EarlyChange": early})
	if err != nil {
		t.Fatal(err)
	}
	r, err := fi.Encode(bytes.NewReader(raw))
	if err != nil {
		t.Fatal(err)
	}
	b, err := io.ReadAll(r)
	if err != nil {
		t.Fatal(err)
	}
	return b
}
func TestCodexLZWReference(t *testing.T) {
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dest == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(dest)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	rng := rand.New(rand.NewSource(43829))
	fmt.Fprintln(out, "///|\n// Generated from upstream pdfcpu LZWDecode.\ntest \"PDF LZW streams match upstream Go\" {")
	for i := 0; i < 768; i++ {
		early := []int{0, 1, 2}[rng.Intn(3)]
		predictor := 1
		if i%23 == 0 {
			predictor = 2
		}
		raw := make([]byte, rng.Intn(160))
		rng.Read(raw)
		if i%5 == 0 {
			for j := range raw {
				raw[j] = byte(j % 7)
			}
		}
		data := encodeCodexLZW(t, raw, early)
		switch i % 7 {
		case 1:
			data = data[:rng.Intn(len(data)+1)]
		case 2:
			if len(data) > 2 {
				data[2] = 0xff
			}
		case 3:
			data = []byte{0xff, 0xff, 0xff}
		case 4:
			data = nil
		case 5:
			data = append(data, 0xff, 0xff)
		}
		max := []int64{0, 1, 5, 32, 127, 256, 1024}[rng.Intn(7)]
		decoded, e := codexLZW(data, early, predictor, max)
		expected := "None"
		if e == nil {
			expected = "Some(" + lzwBytes(decoded) + ")"
		}
		fmt.Fprintf(out, "  check_pdf_lzw(%s,%d,%d,%dL,%s)\n", lzwBytes(data), early, predictor, max, expected)
	}
	fmt.Fprintln(out, `}

///|
test "large PDF LZW streams match upstream Go" {`)
	for _, early := range []int{0, 1} {
		for _, repeat := range []bool{false, true} {
			raw := make([]byte, 6000)
			rng.Read(raw)
			if repeat {
				for i := range raw {
					raw[i] = byte(i % 13)
				}
			}
			data := encodeCodexLZW(t, raw, early)
			for _, max := range []int64{0, 1, 500, 4095, 4096, 5999, 6000} {
				decoded, err := codexLZW(data, early, 1, max)
				if err != nil {
					t.Fatal(err)
				}
				digest := uint64(14695981039346656037)
				for _, b := range decoded {
					digest = (digest ^ uint64(b)) * 1099511628211
				}
				fmt.Fprintf(out, "  check_pdf_lzw_digest(%s,%d,%dL,%d,%dUL)\n", lzwBytes(data), early, max, len(decoded), digest)
			}
		}
	}
	fmt.Fprintln(out, `}

///|
fn check_pdf_lzw_digest(input : Bytes, early : Int, max : Int64, length : Int, expected : UInt64) -> Unit raise {
  let actual = pdf_decode_lzw(input, early, 1, max)
  assert_eq(actual.length(), length)
  let mut digest = 14695981039346656037UL
  for b in actual { digest = (digest ^ b.to_uint64()) * 1099511628211UL }
  assert_eq(digest, expected)
}

///|
fn check_pdf_lzw(input : Bytes, early : Int, predictor : Int, max : Int64, expected : Bytes?) -> Unit raise {
  let actual : Bytes? = try { Some(pdf_decode_lzw(input, early, predictor, max)) } catch { _ => None }
  assert_eq(actual, expected)
}`)
}
