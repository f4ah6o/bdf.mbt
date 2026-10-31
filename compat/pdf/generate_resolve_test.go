//go:build ignore

// Copy this file, generate_xref_test.go and generate_object_test.go without
// their build tags beside upstream converter/pdf. Set BDF_PDF_FIXTURES and
// BDF_REFERENCE_OUTPUT and run TestCodexPDFResolve.
package pdf

import (
	"bytes"
	"compress/gzip"
	"context"
	"fmt"
	"github.com/pdfcpu/pdfcpu/pkg/api"
	"github.com/pdfcpu/pdfcpu/pkg/pdfcpu/model"
	"github.com/pdfcpu/pdfcpu/pkg/pdfcpu/types"
	"os"
	"path/filepath"
	"sort"
	"testing"
)

func TestCodexPDFResolve(t *testing.T) {
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
		ctx, err := api.ReadContext(context.Background(), bytes.NewReader(data), model.NewDefaultConfiguration())
		if err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		var compressed bytes.Buffer
		w := gzip.NewWriter(&compressed)
		w.Write(data)
		w.Close()
		fmt.Fprintf(out, "///|\ntest \"PDF file objects resolve like upstream Go %d\" {\n  check_pdf_resolve(%q,%s,[\n", idx, name, xrefChunks(compressed.Bytes()))
		keys := make([]int, 0, len(ctx.Table))
		for key := range ctx.Table {
			keys = append(keys, key)
		}
		sort.Ints(keys)
		count := 0
		for _, key := range keys {
			entry := ctx.Table[key]
			if entry == nil || entry.Free {
				continue
			}
			gen := 0
			if entry.Generation != nil {
				gen = *entry.Generation
			}
			obj, err := ctx.Dereference(*types.NewIndirectRef(key, gen))
			if err != nil {
				t.Fatalf("%s object %d: %v", name, key, err)
			}
			length := -1
			digest := uint64(0)
			var value types.Object = obj
			switch s := obj.(type) {
			case types.StreamDict:
				value = s.Dict
				length = len(s.Raw)
				digest = 14695981039346656037
				for _, b := range s.Raw {
					digest = (digest ^ uint64(b)) * 1099511628211
				}
			case *types.StreamDict:
				value = s.Dict
				length = len(s.Raw)
				digest = 14695981039346656037
				for _, b := range s.Raw {
					digest = (digest ^ uint64(b)) * 1099511628211
				}
			case types.ObjectStreamDict:
				value = s.Dict
				length = len(s.Raw)
				digest = 14695981039346656037
				for _, b := range s.Raw {
					digest = (digest ^ uint64(b)) * 1099511628211
				}
			case *types.ObjectStreamDict:
				value = s.Dict
				length = len(s.Raw)
				digest = 14695981039346656037
				for _, b := range s.Raw {
					digest = (digest ^ uint64(b)) * 1099511628211
				}
			case types.XRefStreamDict:
				value = s.Dict
				length = len(s.Raw)
				digest = 14695981039346656037
				for _, b := range s.Raw {
					digest = (digest ^ uint64(b)) * 1099511628211
				}
			case *types.XRefStreamDict:
				value = s.Dict
				length = len(s.Raw)
				digest = 14695981039346656037
				for _, b := range s.Raw {
					digest = (digest ^ uint64(b)) * 1099511628211
				}
			}
			text := objectValue(value)
			if len(text) > 8192 {
				continue
			}
			fmt.Fprintf(out, "    (%dL,%s,%d,%dUL),\n", key, text, length, digest)
			count++
		}
		fmt.Fprintln(out, "] )\n}")
		t.Logf("%s: %d objects", name, count)
	}
}
