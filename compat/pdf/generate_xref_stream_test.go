//go:build ignore

// Copy without its build tag with generate_xref_test.go and
// generate_object_test.go into upstream converter/pdf, then set
// BDF_REFERENCE_OUTPUT and run TestCodexXRefStreams.
package pdf

import (
	"bytes"
	"compress/gzip"
	"compress/zlib"
	"context"
	"fmt"
	"github.com/pdfcpu/pdfcpu/pkg/api"
	"github.com/pdfcpu/pdfcpu/pkg/pdfcpu/model"
	"github.com/pdfcpu/pdfcpu/pkg/pdfcpu/types"
	"os"
	"sort"
	"testing"
)

func xrefCompress(data []byte) []byte {
	var b bytes.Buffer
	w := zlib.NewWriter(&b)
	w.Write(data)
	w.Close()
	return b.Bytes()
}
func TestCodexXRefStreams(t *testing.T) {
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dest == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(dest)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	for variant := 0; variant < 4; variant++ {
		var p bytes.Buffer
		p.WriteString("%PDF-1.7\n%stream\n")
		offsets := make([]int, 6)
		for i, obj := range []string{"<< /Type /Catalog /Pages 2 0 R >>", "<< /Type /Pages /Count 0 /Kids [] >>"} {
			offsets[i+1] = p.Len()
			fmt.Fprintf(&p, "%d 0 obj\n%s\nendobj\n", i+1, obj)
		}
		offsets[3] = p.Len()
		objectData := []byte("4 0 << /Value (compressed) >>")
		filterName := ""
		if variant&1 != 0 {
			objectData = xrefCompress(objectData)
			filterName = "/Filter /FlateDecode"
		}
		fmt.Fprintf(&p, "3 0 obj\n<< /Type /ObjStm /N 1 /First 4 %s /Length %d >>\nstream\n", filterName, len(objectData))
		p.Write(objectData)
		p.WriteString("\nendstream\nendobj\n")
		offsets[5] = p.Len()
		var x bytes.Buffer
		write := func(kind byte, second int, third int) {
			x.WriteByte(kind)
			x.WriteByte(byte(second >> 24))
			x.WriteByte(byte(second >> 16))
			x.WriteByte(byte(second >> 8))
			x.WriteByte(byte(second))
			x.WriteByte(byte(third >> 8))
			x.WriteByte(byte(third))
		}
		write(0, 0, 65535)
		write(1, offsets[1], 0)
		write(1, offsets[2], 0)
		write(1, offsets[3], 0)
		write(2, 3, 0)
		write(1, offsets[5], 0)
		xdata := x.Bytes()
		xf := ""
		if variant&2 != 0 {
			xdata = xrefCompress(xdata)
			xf = "/Filter /FlateDecode"
		}
		fmt.Fprintf(&p, "5 0 obj\n<< /Type /XRef /Size 6 /Root 1 0 R /W [1 4 2] %s /Length %d >>\nstream\n", xf, len(xdata))
		p.Write(xdata)
		fmt.Fprintf(&p, "\nendstream\nendobj\nstartxref\n%d\n%%%%EOF\n", offsets[5])
		data := p.Bytes()
		ctx, err := api.ReadContext(context.Background(), bytes.NewReader(data), model.NewDefaultConfiguration())
		if err != nil {
			t.Fatalf("variant %d: %v", variant, err)
		}
		var zipped bytes.Buffer
		z := gzip.NewWriter(&zipped)
		z.Write(data)
		z.Close()
		fmt.Fprintf(out, "///|\ntest \"PDF xref streams match upstream Go %d\" {\n  check_pdf_xrefs(%q,%s,Some(PdfRef(1L,0L)),[\n", variant, fmt.Sprintf("xref-stream-%d", variant), xrefChunks(zipped.Bytes()))
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
			switch {
			case e.Free:
				gen := 0
				if e.Generation != nil {
					gen = *e.Generation
				}
				fmt.Fprintf(out, "(%dL,XRefFree(%dL)),\n", key, gen)
			case e.Compressed || (e.Offset == nil && e.ObjectStream != nil):
				fmt.Fprintf(out, "(%dL,XRefCompressed(%dL,%dL)),\n", key, *e.ObjectStream, *e.ObjectStreamInd)
			case e.Offset != nil:
				gen := 0
				if e.Generation != nil {
					gen = *e.Generation
				}
				fmt.Fprintf(out, "(%dL,XRefOffset(%dL,%dL)),\n", key, *e.Offset, gen)
			}
		}
		fmt.Fprintln(out, "] )\n}")
		value, err := ctx.Dereference(*types.NewIndirectRef(4, 0))
		if err != nil {
			t.Fatal(err)
		}
		fmt.Fprintf(out, "///|\ntest \"PDF compressed object matches upstream Go %d\" {\n  check_pdf_resolve(%q,%s,[(4L,%s,-1,0UL)])\n}\n", variant, fmt.Sprintf("xref-stream-%d", variant), xrefChunks(zipped.Bytes()), objectValue(value))
	}
}
