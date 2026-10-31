//go:build ignore

// Copy without its build tag beside upstream converter/pdf/interp.go, set
// BDF_PDF_FIXTURES and BDF_REFERENCE_OUTPUT, then run TestCodexPDFDrawOperators.
package pdf

import (
	"bytes"
	"context"
	"fmt"
	"github.com/pdfcpu/pdfcpu/pkg/api"
	"github.com/pdfcpu/pdfcpu/pkg/pdfcpu/model"
	"github.com/pdfcpu/pdfcpu/pkg/pdfcpu/types"
	"math/rand"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func opPathBytes(b []byte) string {
	var s strings.Builder
	s.WriteString(`b"`)
	for _, v := range b {
		fmt.Fprintf(&s, `\x%02x`, v)
	}
	s.WriteString(`"`)
	return s.String()
}
func TestCodexPDFDrawOperators(t *testing.T) {
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
	r := rand.New(rand.NewSource(5562))
	ops := []string{"m", "l", "c", "v", "y", "h", "re"}
	for block := 0; block < 4; block++ {
		fmt.Fprintf(out, "///|\ntest \"PDF path operators match upstream Go %d\" {\n", block)
		for sample := 0; sample < 32; sample++ {
			in := &interp{c: &converter{pdf: &pdf{ctx: ctx}}}
			in.resetPath()
			var input strings.Builder
			input.WriteString("[")
			for n := 0; n < 16; n++ {
				op := ops[r.Intn(len(ops))]
				args := make([]types.Object, r.Intn(9))
				fmt.Fprintf(&input, "(b%q,[", op)
				for i := range args {
					switch r.Intn(3) {
					case 0:
						v := r.Intn(101) - 50
						args[i] = types.Integer(v)
						fmt.Fprintf(&input, "Integer(%dL),", v)
					case 1:
						v := float64(r.Intn(1001)-500) / 7
						args[i] = types.Float(v)
						fmt.Fprintf(&input, "Real(%#.17g),", v)
					case 2:
						args[i] = types.Name("bad")
						input.WriteString(`Name(b"bad"),`)
					}
				}
				input.WriteString("]),")
				in.exec(op, args)
			}
			input.WriteString("]")
			fmt.Fprintf(out, "check_pdf_draw_operators(%s,%s,[", input.String(), opPathBytes(in.path.Verbs))
			for _, x := range in.path.Args {
				fmt.Fprintf(out, "%#.17g,", float64(x))
			}
			bounds := "None"
			if !in.pathEmpty {
				bounds = fmt.Sprintf("Some((%#.17g,%#.17g,%#.17g,%#.17g))", in.pathBBox.x0, in.pathBBox.y0, in.pathBBox.x1, in.pathBBox.y1)
			}
			fmt.Fprintf(out, "],%s,(%#.17g,%#.17g),(%#.17g,%#.17g))\n", bounds, in.cur[0], in.cur[1], in.start[0], in.start[1])
		}
		fmt.Fprintln(out, "}")
	}
}
