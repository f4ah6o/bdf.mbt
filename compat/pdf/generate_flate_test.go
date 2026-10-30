//go:build ignore

// Copy without its build tag beside upstream converter/pdf/flate.go and run
// TestCodexFlateReference with BDF_REFERENCE_OUTPUT set.
package pdf

import (
	"bytes"
	"compress/zlib"
	"fmt"
	"math/rand"
	"os"
	"strings"
	"testing"
)

func flateBytes(b []byte) string {
	var s strings.Builder
	s.WriteString(`b"`)
	for _, c := range b {
		fmt.Fprintf(&s, `\x%02x`, c)
	}
	s.WriteString(`"`)
	return s.String()
}
func TestCodexFlateReference(t *testing.T) {
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dest == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(dest)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	rng := rand.New(rand.NewSource(66073))
	fmt.Fprintln(out, "///|\n// Generated from upstream PDF FlateDecode and predictor processing.\ntest \"PDF Flate streams match upstream Go\" {")
	for i := 0; i < 640; i++ {
		colors := 1 + rng.Intn(4)
		bits := []int{1, 2, 4, 8, 16}[rng.Intn(5)]
		columns := 1 + rng.Intn(20)
		predictor := []int{1, 2, 10, 11, 12, 13, 14, 15, 5}[rng.Intn(9)]
		rowSize := (bits*colors*columns + 7) / 8
		rowLen := rowSize
		if predictor >= 10 && predictor <= 15 {
			rowLen++
		}
		raw := make([]byte, rowLen*(1+rng.Intn(4))+rng.Intn(4))
		rng.Read(raw)
		if predictor >= 10 && predictor <= 15 {
			for j := 0; j+rowLen <= len(raw); j += rowLen {
				raw[j] = byte(rng.Intn(7))
			}
		}
		var z bytes.Buffer
		w := zlib.NewWriter(&z)
		w.Write(raw)
		w.Close()
		data := append([]byte(nil), z.Bytes()...)
		switch i % 9 {
		case 1:
			data = data[2:]
		case 2:
			data[len(data)-1]++
		case 3:
			data = data[:len(data)/2]
		case 4:
			data = data[:rng.Intn(len(data)+1)]
		case 5:
			data = append(data, 0xab, 0xcd)
		case 6:
			data = []byte{0x78, 0xbb, 0, 0, 0, 0, 1}
		case 7:
			if len(data) > 6 {
				data[2] = 0xff
				data[3] = 0xff
				data[4] = 0xff
			}
		case 8:
			data = nil
		}
		max := []int64{-1, 0, 1, 5, 32, 255, 4096}[rng.Intn(7)]
		parms := map[string]int{"Predictor": predictor, "Colors": colors, "BitsPerComponent": bits, "Columns": columns}
		var got []byte
		var e error
		if max >= 0 {
			e = checkPredictor(parms, len(data))
		}
		if e == nil {
			got, e = inflateUpTo(data, parms, max, false)
		}
		expected := "None"
		if e == nil {
			expected = "Some(" + flateBytes(got) + ")"
		}
		fmt.Fprintf(out, "  check_pdf_flate(%s,%d,%d,%d,%d,%dL,%s)\n", flateBytes(data), predictor, colors, bits, columns, max, expected)
	}
	fmt.Fprintln(out, `}

///|
test "large PDF Flate streams match upstream Go" {`)
	big := make([]byte, 1<<19)
	for i := range big {
		big[i] = byte(i >> 10)
	}
	var compressed bytes.Buffer
	w := zlib.NewWriter(&compressed)
	w.Write(big)
	w.Close()
	encoded := compressed.Bytes()
	inputs := [][]byte{encoded, encoded[2:], encoded[:len(encoded)/2], encoded[:2], append(append([]byte(nil), encoded...), 0xff)}
	for _, input := range inputs {
		for _, max := range []int64{0, 1, 1000, 65535, 65536, 1 << 19} {
			data, err := inflateUpTo(input, nil, max, false)
			if err != nil {
				t.Fatal(err)
			}
			digest := uint64(14695981039346656037)
			for _, b := range data {
				digest = (digest ^ uint64(b)) * 1099511628211
			}
			fmt.Fprintf(out, "  check_pdf_flate_digest(%s,%dL,%d,%dUL)\n", flateBytes(input), max, len(data), digest)
		}
	}
	fmt.Fprintln(out, `}

///|
fn check_pdf_flate_digest(input : Bytes, max : Int64, length : Int, expected : UInt64) -> Unit raise {
  let actual = pdf_inflate_up_to(input, 1, 1, 8, 1, max)
  assert_eq(actual.length(), length)
  let mut digest = 14695981039346656037UL
  for b in actual { digest = (digest ^ b.to_uint64()) * 1099511628211UL }
  assert_eq(digest, expected)
}

///|
fn check_pdf_flate(input : Bytes, predictor : Int, colors : Int, bits : Int, columns : Int, max : Int64, expected : Bytes?) -> Unit raise {
  let actual : Bytes? = try { Some(pdf_inflate_up_to(input, predictor, colors, bits, columns, max)) } catch { _ => None }
  assert_eq(actual, expected)
}`)
}
