//go:build ignore

// Copy without its build tag beside upstream converter/pdf, set
// BDF_PDF_FIXTURES to its testdata directory and BDF_REFERENCE_OUTPUT to the
// generated MoonBit test path, then run TestCodexPDFXRef.
package pdf

import (
	"bytes"
	"compress/gzip"
	"context"
	"encoding/base64"
	"fmt"
	"github.com/pdfcpu/pdfcpu/pkg/api"
	"github.com/pdfcpu/pdfcpu/pkg/pdfcpu/model"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"
)

func xrefChunks(b []byte) string {
	var s strings.Builder
	s.WriteString("[")
	encoded := base64.StdEncoding.EncodeToString(b)
	for i := 0; i < len(encoded); i += 1000 {
		end := min(i+1000, len(encoded))
		fmt.Fprintf(&s, "%q,\n", encoded[i:end])
	}
	s.WriteString("]")
	return s.String()
}
func TestCodexPDFXRef(t *testing.T) {
	dir := os.Getenv("BDF_PDF_FIXTURES")
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dir == "" || dest == "" {
		t.Fatal("BDF_PDF_FIXTURES and BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(dest)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	names := []string{"cairo-cff.pdf", "cairo-type1.pdf", "chrome-doc.pdf", "chrome-masks.pdf", "chrome-slides.pdf", "cjk-cmaps.pdf", "images-jpx-jbig2.pdf", "reportlab-master.pdf", "reportlab-mixed.pdf", "reportlab-type1.pdf", "weasyprint-webfonts.pdf"}
	for idx, name := range names {
		data, err := os.ReadFile(filepath.Join(dir, name))
		if err != nil {
			t.Fatal(err)
		}
		conf := model.NewDefaultConfiguration()
		ctx, err := api.ReadContext(context.Background(), bytes.NewReader(data), conf)
		if err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		var compressed bytes.Buffer
		w := gzip.NewWriter(&compressed)
		w.Write(data)
		w.Close()
		root := "None"
		if ctx.Root != nil {
			root = fmt.Sprintf("Some(PdfRef(%dL,%dL))", ctx.Root.ObjectNumber, ctx.Root.GenerationNumber)
		}
		fmt.Fprintf(out, "///|\ntest \"PDF cross references match upstream Go %d\" {\n  check_pdf_xrefs(%q,%s,%s,[\n", idx, name, xrefChunks(compressed.Bytes()), root)
		keys := make([]int, 0, len(ctx.Table))
		for key := range ctx.Table {
			keys = append(keys, key)
		}
		sort.Ints(keys)
		for _, key := range keys {
			entry := ctx.Table[key]
			if entry == nil {
				continue
			}
			var expected string
			if entry.Free {
				gen := 0
				if entry.Generation != nil {
					gen = *entry.Generation
				}
				expected = fmt.Sprintf("XRefFree(%dL)", gen)
			} else if entry.Compressed || (entry.Offset == nil && entry.ObjectStream != nil) {
				if entry.ObjectStream == nil || entry.ObjectStreamInd == nil {
					t.Fatal("invalid compressed entry")
				}
				expected = fmt.Sprintf("XRefCompressed(%dL,%dL)", *entry.ObjectStream, *entry.ObjectStreamInd)
			} else {
				if entry.Offset == nil {
					continue
				}
				gen := 0
				if entry.Generation != nil {
					gen = *entry.Generation
				}
				expected = fmt.Sprintf("XRefOffset(%dL,%dL)", *entry.Offset, gen)
			}
			fmt.Fprintf(out, "    (%dL,%s),\n", key, expected)
		}
		fmt.Fprintln(out, "] )\n}")
		t.Logf("%s: %d entries", name, len(keys))
	}
}
