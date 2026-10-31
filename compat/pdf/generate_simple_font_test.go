//go:build ignore

// Copy without its build tag beside upstream converter/pdf sources, set
// BDF_PDF_FIXTURES and BDF_REFERENCE_OUTPUT, then run TestCodexPDFSimpleFont.
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

func TestCodexPDFSimpleFont(t *testing.T) {
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
	fonts := []types.Dict{
		{"Subtype": types.Name("Type1"), "BaseFont": types.Name("Helvetica")},
		{"Subtype": types.Name("TrueType"), "BaseFont": types.Name("Courier-BoldOblique")},
		{"Subtype": types.Name("Type1"), "BaseFont": types.Name("ABCDEF+Times-Roman"), "FontDescriptor": types.Dict{"FontWeight": types.Integer(480), "Flags": types.Integer(64)}},
		{"Subtype": types.Name("Type1"), "BaseFont": types.Name("Helvetica"), "FontDescriptor": types.Dict{"Flags": types.Integer(2), "StemV": types.Integer(130)}},
		{"Subtype": types.Name("Type1"), "BaseFont": types.Name("Symbol-Heavy"), "FontDescriptor": types.Dict{"Flags": types.Integer(1)}},
		{"Subtype": types.Name("Type1"), "BaseFont": types.Name("A+BCDE+Times-Light"), "FontDescriptor": types.Dict{"ItalicAngle": types.Integer(-10)}},
		{"Subtype": types.Name("Type1"), "BaseFont": types.Name("Arial"), "FirstChar": types.Integer(65), "Widths": types.Array{types.Integer(400), types.Integer(0), types.Name("bad")}, "FontDescriptor": types.Dict{"MissingWidth": types.Integer(500)}},
	}
	for i, d := range fonts {
		c := &converter{pdf: &pdf{ctx: ctx}, opts: &Options{}, fonts: map[string]*pdfFont{}, warned: map[string]bool{}}
		f := c.loadFont(d, nil)
		fmt.Fprintf(out, "///|\ntest \"PDF simple font metrics match upstream Go %d\" {\n check_pdf_simple_font(%d,%q,%d,%d,[\n", i, i, f.family, f.weight, f.style)
		for code := 0; code < 256; code++ {
			g := glyphCode{code: uint32(code), nbytes: 1, cid: uint32(code)}
			fmt.Fprintf(out, "%#.17g,\n", f.width(g))
		}
		fmt.Fprintln(out, "])\n}")
	}
}
