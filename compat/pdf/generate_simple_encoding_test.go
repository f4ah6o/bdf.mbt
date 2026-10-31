//go:build ignore

// Copy without its build tag beside upstream converter/pdf sources, set
// BDF_PDF_FIXTURES and BDF_REFERENCE_OUTPUT, then run TestCodexPDFSimpleEncoding.
package pdf

import (
	"bytes"
	"context"
	"fmt"
	"github.com/pdfcpu/pdfcpu/pkg/api"
	"github.com/pdfcpu/pdfcpu/pkg/pdfcpu/model"
	"github.com/pdfcpu/pdfcpu/pkg/pdfcpu/types"
	"os"
	"path/filepath"
	"testing"
)

func TestCodexPDFSimpleEncoding(t *testing.T) {
	dest, dir := os.Getenv("BDF_REFERENCE_OUTPUT"), os.Getenv("BDF_PDF_FIXTURES")
	if dest == "" || dir == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT and BDF_PDF_FIXTURES required")
	}
	data, e := os.ReadFile(filepath.Join(dir, "cairo-cff.pdf"))
	if e != nil {
		t.Fatal(e)
	}
	ctx, e := api.ReadContext(context.Background(), bytes.NewReader(data), model.NewDefaultConfiguration())
	if e != nil {
		t.Fatal(e)
	}
	out, e := os.Create(dest)
	if e != nil {
		t.Fatal(e)
	}
	defer out.Close()
	encodings := []types.Object{nil, types.Name("WinAnsiEncoding"), types.Name("MacRomanEncoding"), types.Name("MacExpertEncoding"), types.Dict{"BaseEncoding": types.Name("WinAnsiEncoding"), "Differences": types.Array{types.Integer(32), types.Name("uni00A9"), types.Name("foo.alt"), types.Integer(65), types.Name("zero"), types.Name("u1F600"), types.Integer(255), types.Name("A"), types.Name("B")}}, types.Name("Unknown")}
	for i, enc := range encodings {
		f := &pdfFont{}
		c := &converter{pdf: &pdf{ctx: ctx}}
		c.loadSimpleEncoding(f, types.Dict{"Encoding": enc}, nil)
		fmt.Fprintf(out, "///|\ntest \"PDF simple encoding matches upstream Go %d\" {\n check_pdf_simple_encoding(%d,[\n", i, i)
		for code := 0; code < 256; code++ {
			g := glyphCode{code: uint32(code), nbytes: 1, cid: uint32(code)}
			fmt.Fprintf(out, "(%q,%q),\n", f.glyphName(uint32(code)), f.unicode(g))
		}
		fmt.Fprintln(out, "])\n}")
	}
}
