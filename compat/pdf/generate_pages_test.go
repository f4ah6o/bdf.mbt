//go:build ignore

// Copy without its build tag beside upstream converter/pdf along with
// generate_xref_test.go; run with BDF_PDF_FIXTURES and BDF_REFERENCE_OUTPUT.
package pdf

import (
	"bytes"
	"compress/gzip"
	"context"
	"fmt"
	"github.com/pdfcpu/pdfcpu/pkg/api"
	"github.com/pdfcpu/pdfcpu/pkg/pdfcpu/model"
	"github.com/pdfcpu/pdfcpu/pkg/pdfcpu/types"
	"hash/fnv"
	"os"
	"path/filepath"
	"testing"
)

func pageRect(r *types.Rectangle) string {
	if r == nil {
		return "None"
	}
	return fmt.Sprintf("Some((%#.17g,%#.17g,%#.17g,%#.17g))", r.LL.X, r.LL.Y, r.UR.X, r.UR.Y)
}
func referencePageContent(p *pdf, leaf pageLeaf) ([]byte, error) {
	value := p.deref(leaf.dict["Contents"])
	var streams []types.Object
	switch v := value.(type) {
	case nil:
		return nil, nil
	case types.Array:
		streams = v
	default:
		streams = []types.Object{v}
	}
	var result []byte
	for _, item := range streams {
		if p.deref(item) == nil {
			continue
		}
		sd, _, err := p.ctx.DereferenceStreamDict(item)
		if err != nil {
			return nil, err
		}
		if sd == nil {
			return nil, fmt.Errorf("not a stream")
		}
		if err = sd.Decode(); err != nil {
			return nil, err
		}
		result = append(result, sd.Content...)
	}
	return result, nil
}
func TestCodexPDFPages(t *testing.T) {
	dir, dest := os.Getenv("BDF_PDF_FIXTURES"), os.Getenv("BDF_REFERENCE_OUTPUT")
	if dir == "" || dest == "" {
		t.Fatal("BDF_PDF_FIXTURES and BDF_REFERENCE_OUTPUT required")
	}
	out, e := os.Create(dest)
	if e != nil {
		t.Fatal(e)
	}
	defer out.Close()
	names := []string{"cairo-cff.pdf", "cairo-type1.pdf", "chrome-doc.pdf", "chrome-masks.pdf", "chrome-slides.pdf", "cjk-cmaps.pdf", "images-jpx-jbig2.pdf", "reportlab-master.pdf", "reportlab-mixed.pdf", "reportlab-type1.pdf", "weasyprint-webfonts.pdf"}
	for idx, name := range names {
		data, e := os.ReadFile(filepath.Join(dir, name))
		if e != nil {
			t.Fatal(e)
		}
		ctx, e := api.ReadContext(context.Background(), bytes.NewReader(data), model.NewDefaultConfiguration())
		if e != nil {
			t.Fatal(e)
		}
		leaves, left, e := (&pdf{ctx: ctx}).pageLeaves()
		if e != nil {
			t.Fatalf("%s: %v", name, e)
		}
		var z bytes.Buffer
		w := gzip.NewWriter(&z)
		w.Write(data)
		w.Close()
		fmt.Fprintf(out, "///|\ntest \"PDF pages match upstream Go %d\" {\n check_pdf_pages(%q,%s,%d,[\n", idx, name, xrefChunks(z.Bytes()), left)
		for _, leaf := range leaves {
			id := "None"
			if leaf.ref != nil {
				id = fmt.Sprintf("Some(%dL)", leaf.ref.ObjectNumber)
			}
			err := "None"
			if leaf.err != nil {
				err = fmt.Sprintf("Some(%q)", leaf.err.Error())
			}
			content, e := referencePageContent(&pdf{ctx: ctx}, leaf)
			if e != nil {
				t.Fatalf("%s content: %v", name, e)
			}
			h := fnv.New64a()
			h.Write(content)
			fmt.Fprintf(out, "(%s,%s,%s,%d,%t,%s,%d,%dUL),\n", id, pageRect(leaf.attrs.MediaBox), pageRect(leaf.attrs.CropBox), leaf.attrs.Rotate, leaf.attrs.Resources != nil, err, len(content), h.Sum64())
		}
		fmt.Fprintln(out, "])\n}")
		t.Logf("%s: %d pages", name, len(leaves))
	}
}
