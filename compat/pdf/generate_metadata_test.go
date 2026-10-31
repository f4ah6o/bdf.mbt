//go:build ignore

// Copy without its build tag beside upstream converter/pdf sources, set
// BDF_PDF_FIXTURES and BDF_REFERENCE_OUTPUT, then run TestCodexPDFMetadata.
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
	"strings"
	"testing"
)

func metadataChunks(b []byte) string {
	var s strings.Builder
	s.WriteString("[")
	v := base64.StdEncoding.EncodeToString(b)
	for i := 0; i < len(v); i += 1000 {
		end := min(i+1000, len(v))
		fmt.Fprintf(&s, "%q,\n", v[i:end])
	}
	s.WriteString("]")
	return s.String()
}
func TestCodexPDFMetadata(t *testing.T) {
	dest, dir := os.Getenv("BDF_REFERENCE_OUTPUT"), os.Getenv("BDF_PDF_FIXTURES")
	if dest == "" || dir == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT and BDF_PDF_FIXTURES required")
	}
	out, e := os.Create(dest)
	if e != nil {
		t.Fatal(e)
	}
	defer out.Close()
	names := []string{"cairo-cff.pdf", "cairo-type1.pdf", "chrome-doc.pdf", "chrome-masks.pdf", "chrome-slides.pdf", "cjk-cmaps.pdf", "images-jpx-jbig2.pdf", "reportlab-master.pdf", "reportlab-mixed.pdf", "reportlab-type1.pdf", "weasyprint-webfonts.pdf"}
	for i, name := range names {
		data, e := os.ReadFile(filepath.Join(dir, name))
		if e != nil {
			t.Fatal(e)
		}
		ctx, e := api.ReadContext(context.Background(), bytes.NewReader(data), model.NewDefaultConfiguration())
		if e != nil {
			t.Fatal(e)
		}
		dc := (&pdf{ctx: ctx}).info()
		var compressed bytes.Buffer
		w := gzip.NewWriter(&compressed)
		w.Write(data)
		w.Close()
		fmt.Fprintf(out, "///|\ntest \"PDF metadata matches upstream Go %d\" {\n check_pdf_metadata(%q,%s,%q,%q,%q,[", i, name, metadataChunks(compressed.Bytes()), dc.Title.First(), dc.Creator.First(), dc.Description.First())
		for _, subject := range dc.Subject {
			fmt.Fprintf(out, "%q,", subject)
		}
		fmt.Fprintf(out, "],%q,%q)\n}\n", dc.Created.First(), dc.Modified.First())
	}
}
