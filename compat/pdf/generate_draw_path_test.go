//go:build ignore

// Copy without its build tag beside upstream converter/pdf/interp.go, set
// BDF_REFERENCE_OUTPUT, then run TestCodexPDFDrawPath.
package pdf

import (
	"fmt"
	"math/rand"
	"os"
	"strings"
	"testing"
)

func pathBytes(b []byte) string {
	var s strings.Builder
	s.WriteString(`b"`)
	for _, v := range b {
		fmt.Fprintf(&s, `\x%02x`, v)
	}
	s.WriteString(`"`)
	return s.String()
}
func TestCodexPDFDrawPath(t *testing.T) {
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dest == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, e := os.Create(dest)
	if e != nil {
		t.Fatal(e)
	}
	defer out.Close()
	r := rand.New(rand.NewSource(1844))
	for block := 0; block < 16; block++ {
		fmt.Fprintf(out, "///|\ntest \"PDF path construction matches upstream Go %d\" {\n", block)
		for sample := 0; sample < 32; sample++ {
			in := &interp{}
			in.resetPath()
			var args strings.Builder
			args.WriteString("[")
			for n := 0; n < 32; n++ {
				op := r.Intn(5)
				count := []int{2, 2, 6, 0, 4}[op]
				v := make([]float64, count)
				for i := range v {
					v[i] = float64(r.Intn(40001)-20000) / 13.0
				}
				fmt.Fprintf(&args, "(%d,[", op)
				for _, x := range v {
					fmt.Fprintf(&args, "%#.17g,", x)
				}
				args.WriteString("]),")
				switch op {
				case 0:
					in.moveTo(v[0], v[1])
				case 1:
					in.lineTo(v[0], v[1])
				case 2:
					in.curveTo(v[0], v[1], v[2], v[3], v[4], v[5])
				case 3:
					in.closePath()
				case 4:
					in.rectPath(v[0], v[1], v[2], v[3])
				}
			}
			args.WriteString("]")
			fmt.Fprintf(out, "check_pdf_draw_path(%s,%s,[", args.String(), pathBytes(in.path.Verbs))
			for _, x := range in.path.Args {
				fmt.Fprintf(out, "%#.17g,", float64(x))
			}
			fmt.Fprintf(out, "],(%#.17g,%#.17g,%#.17g,%#.17g),(%#.17g,%#.17g),(%#.17g,%#.17g))\n", in.pathBBox.x0, in.pathBBox.y0, in.pathBBox.x1, in.pathBBox.y1, in.cur[0], in.cur[1], in.start[0], in.start[1])
		}
		fmt.Fprintln(out, "}")
	}
}
