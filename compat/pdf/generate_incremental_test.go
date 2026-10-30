//go:build ignore

// Copy without its build tag alongside generate_xref_test.go and
// generate_object_test.go into upstream converter/pdf, then set
// BDF_REFERENCE_OUTPUT and run TestCodexIncrementalPDF.
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
	"sort"
	"testing"
)

func TestCodexIncrementalPDF(t *testing.T) {
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dest == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(dest)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	var p bytes.Buffer
	p.WriteString("%PDF-1.7\n%incremental\n")
	offsets := make([]int, 4)
	for i, obj := range []string{"<< /Type /Catalog /Pages 2 0 R >>", "<< /Type /Pages /Count 0 /Kids [] >>", "<< /Value (old) >>"} {
		offsets[i+1] = p.Len()
		fmt.Fprintf(&p, "%d 0 obj\n%s\nendobj\n", i+1, obj)
	}
	base := p.Len()
	p.WriteString("xref\n0 4\n0000000000 65535 f \n")
	for _, offset := range offsets[1:] {
		fmt.Fprintf(&p, "%010d 00000 n \n", offset)
	}
	fmt.Fprintf(&p, "trailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n", base)
	updated := p.Len()
	p.WriteString("3 0 obj\n<< /Value (new) >>\nendobj\n")
	next := p.Len()
	fmt.Fprintf(&p, "xref\n3 1\n%010d 00000 n \ntrailer\n<< /Size 4 /Root 1 0 R /Prev %d >>\nstartxref\n%d\n%%%%EOF\n", updated, base, next)
	data := p.Bytes()
	ctx, err := api.ReadContext(context.Background(), bytes.NewReader(data), model.NewDefaultConfiguration())
	if err != nil {
		t.Fatal(err)
	}
	var compressed bytes.Buffer
	w := gzip.NewWriter(&compressed)
	w.Write(data)
	w.Close()
	root := "None"
	if ctx.Root != nil {
		root = fmt.Sprintf("Some(PdfRef(%dL,%dL))", ctx.Root.ObjectNumber, ctx.Root.GenerationNumber)
	}
	fmt.Fprintf(out, "///|\ntest \"incremental PDF cross references match upstream Go\" {\n  check_pdf_xrefs(%q,%s,%s,[\n", "incremental", xrefChunks(compressed.Bytes()), root)
	keys := make([]int, 0, len(ctx.Table))
	for key := range ctx.Table {
		keys = append(keys, key)
	}
	sort.Ints(keys)
	for _, key := range keys {
		e := ctx.Table[key]
		if e == nil {
			continue
		}
		if e.Free {
			gen := 0
			if e.Generation != nil {
				gen = *e.Generation
			}
			fmt.Fprintf(out, "(%dL,XRefFree(%dL)),\n", key, gen)
		} else if e.Offset != nil {
			gen := 0
			if e.Generation != nil {
				gen = *e.Generation
			}
			fmt.Fprintf(out, "(%dL,XRefOffset(%dL,%dL)),\n", key, *e.Offset, gen)
		}
	}
	fmt.Fprintln(out, "] )\n}")
	value, err := ctx.Dereference(*types.NewIndirectRef(3, 0))
	if err != nil {
		t.Fatal(err)
	}
	fmt.Fprintf(out, "///|\ntest \"incremental PDF resolves newest object\" {\n  check_pdf_resolve(%q,%s,[(3L,%s,-1,0UL)])\n}\n", "incremental", xrefChunks(compressed.Bytes()), objectValue(value))
}
