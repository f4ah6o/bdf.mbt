//go:build ignore

// Copy without its build tag beside upstream converter/pdf sources, set
// BDF_PDF_FIXTURES and BDF_REFERENCE_OUTPUT, then run TestCodexPDFTextState.
package pdf

import (
	"bytes"
	"context"
	"fmt"
	"github.com/pdfcpu/pdfcpu/pkg/api"
	"github.com/pdfcpu/pdfcpu/pkg/pdfcpu/model"
	"github.com/pdfcpu/pdfcpu/pkg/pdfcpu/types"
	"github.com/shibukawa/bdf"
	"math/rand"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func textMatrix(m matrix) string {
	return fmt.Sprintf("(%#.17g,%#.17g,%#.17g,%#.17g,%#.17g,%#.17g)", m[0], m[1], m[2], m[3], m[4], m[5])
}
func TestCodexPDFTextState(t *testing.T) {
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
	r := rand.New(rand.NewSource(774))
	ops := []string{"BT", "ET", "Tc", "Tw", "Tz", "TL", "Ts", "Tr", "Td", "TD", "Tm", "T*"}
	for block := 0; block < 4; block++ {
		fmt.Fprintf(out, "///|\ntest \"PDF text state matches upstream Go %d\" {\n", block)
		for sample := 0; sample < 32; sample++ {
			c := &converter{pdf: &pdf{ctx: ctx}, warned: map[string]bool{}}
			p := newPending(bdf.Rect{W: 612, H: 792})
			in := c.newInterp(p, nil, identity, 0)
			var input strings.Builder
			input.WriteString("[")
			for j := 0; j < 24; j++ {
				op := ops[r.Intn(len(ops))]
				args := make([]types.Object, r.Intn(8))
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
			fmt.Fprintf(out, "check_pdf_text_state(%s,%t,%s,%s,%s,(%#.17g,%#.17g),(%#.17g,%#.17g,%#.17g,%#.17g,%#.17g,%d))\n", input.String(), in.inText, textMatrix(in.text.tm), textMatrix(in.text.tlm), textMatrix(in.text.base), in.text.tx, in.text.ty, in.gs.charSp, in.gs.wordSp, in.gs.hscale, in.gs.leading, in.gs.rise, in.gs.render)
		}
		fmt.Fprintln(out, "}")
	}
}
