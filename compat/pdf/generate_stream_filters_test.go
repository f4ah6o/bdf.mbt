//go:build ignore

// Copy without its build tag beside upstream converter/pdf/objects.go and run
// TestCodexStreamFilters with BDF_REFERENCE_OUTPUT set.
package pdf

import (
	"bytes"
	"fmt"
	"github.com/pdfcpu/pdfcpu/pkg/filter"
	"github.com/pdfcpu/pdfcpu/pkg/pdfcpu/types"
	"io"
	"math/rand"
	"os"
	"strings"
	"testing"
)

func streamBytes(b []byte) string {
	var s strings.Builder
	s.WriteString(`b"`)
	for _, c := range b {
		fmt.Fprintf(&s, `\x%02x`, c)
	}
	s.WriteString(`"`)
	return s.String()
}
func TestCodexStreamFilters(t *testing.T) {
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dest == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(dest)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	rng := rand.New(rand.NewSource(349117))
	names := []string{filter.ASCIIHex, filter.ASCII85, filter.Flate, filter.LZW, filter.RunLength}
	fmt.Fprintln(out, "///|\n// Generated from upstream PDF stream filter pipelines.\ntest \"PDF stream pipelines match upstream Go\" {")
	for i := 0; i < 512; i++ {
		raw := make([]byte, rng.Intn(50))
		rng.Read(raw)
		var chosen []string
		for j := 0; j < rng.Intn(4); j++ {
			chosen = append(chosen, names[rng.Intn(len(names))])
		}
		data := append([]byte(nil), raw...)
		for j := len(chosen) - 1; j >= 0; j-- {
			fi, err := filter.NewFilter(chosen[j], nil)
			if err != nil {
				t.Fatal(err)
			}
			r, err := fi.Encode(bytes.NewReader(data))
			if err != nil {
				t.Fatal(err)
			}
			data, err = io.ReadAll(r)
			if err != nil {
				t.Fatal(err)
			}
		}
		if i%7 == 0 {
			chosen = append(chosen, filter.DCT)
		}
		if i%11 == 0 {
			chosen = append(chosen, "BogusDecode")
		}
		if i%17 == 0 && len(data) > 0 {
			data = data[:len(data)/2]
		}
		filters := make([]types.PDFFilter, len(chosen))
		var literals []string
		for j, name := range chosen {
			filters[j] = types.PDFFilter{Name: name}
			literals = append(literals, fmt.Sprintf("{name:%s,predictor:1,colors:1,bits:8,columns:1,early_change:1}", streamBytes([]byte(name))))
		}
		limit := []int64{0, 1, 10, 49, 1000}[rng.Intn(5)]
		cut := rng.Intn(2) == 0
		sd := &types.StreamDict{Raw: data, FilterPipeline: filters}
		decoded, image, err := (&pdf{}).decodeStreamUpTo(sd, limit, cut)
		expected := "None"
		if err == nil {
			img := "None"
			if image != "" {
				img = "Some(" + streamBytes([]byte(image)) + ")"
			}
			expected = "Some((" + streamBytes(decoded) + "," + img + "))"
		}
		fmt.Fprintf(out, "  check_pdf_stream_filters(%s,[%s],%dL,%t,%s)\n", streamBytes(data), strings.Join(literals, ","), limit, cut, expected)
	}
	fmt.Fprintln(out, `}

///|
fn check_pdf_stream_filters(data : Bytes, filters : Array[PdfStreamFilter], limit : Int64, cut : Bool, expected : (Bytes, Bytes?)?) -> Unit raise {
  let actual : (Bytes, Bytes?)? = try { Some(pdf_decode_stream(data, filters, limit, cut, 268435456L)) } catch { _ => None }
  assert_eq(actual, expected)
}`)
}
