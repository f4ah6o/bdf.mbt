//go:build ignore

// Copy without its build tag beside upstream converter/pdf/interp.go, set
// BDF_PDF_FIXTURES and BDF_REFERENCE_OUTPUT, then run TestCodexPDFGraphics.
package pdf

import (
	"bytes"
	"context"
	"fmt"
	"github.com/pdfcpu/pdfcpu/pkg/api"
	"github.com/pdfcpu/pdfcpu/pkg/pdfcpu/model"
	"github.com/shibukawa/bdf"
	"math/rand"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func graphicsBytes(b []byte) string {
	var s strings.Builder
	s.WriteString(`b"`)
	for _, v := range b {
		fmt.Fprintf(&s, `\x%02x`, v)
	}
	s.WriteString(`"`)
	return s.String()
}
func TestCodexPDFGraphics(t *testing.T) {
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
	rand := rand.New(rand.NewSource(653))
	cases := []string{"", "0 0 100 100 re f", "q 1 0 0 1 20 30 cm .1 .2 .3 rg 0 0 40 50 re f Q", "0 0 10 10 re W n 1 2 m 3 4 l S", "W n", "0 w 10 20 30 40 re B", "0.1 0.2 0.3 0.4 k 1 2 30 40 re f*", "q q 2 3 m 4 5 l s", "[2 3] 1 d 0 0 m 20 20 l S [] 7 d 0 0 m 20 0 l S", "[0 0] 3 d 0 0 m 20 20 l S", "[1.00004 2] 0 d 0 0 m 1 1 l S [1.00003 2] 0 d 0 0 m 2 2 l S", "[0.00005 -0.00005 -0.0] -0.0 d 0 0 m 2 2 l S", "/DeviceRGB cs 0.2 0.4 0.8 sc 0 0 20 20 re f /DeviceCMYK CS 0.1 0.2 0.3 0.4 SC 1 2 m 3 4 l S"}
	commands := []string{"0 0 m", "10 20 l", "2 4 6 8 10 12 c", "3 4 5 6 v", "3 4 5 6 y", "h", "10 20 30 40 re", "S", "s", "f", "f*", "B", "B*", "b", "b*", "n", "W", "W*", "0.3 g", "0.8 G", "0.2 0.4 0.8 rg", "0.8 0.4 0.2 RG", "0.1 0.2 0.3 0.4 k", "0.4 0.3 0.2 0.1 K", "0 w", "1 w", "2 J", "1 j", "8 M", "q", "Q", "1 0 0 1 20 30 cm", "[2 3] 1 d", "[0 0] 2 d", "[] 5 d", "[0.00005 1.23455] 0.5 d", "/DeviceRGB cs", "/DeviceGray CS", "/CMYK cs", "0.1 0.2 0.3 sc", "0.5 SC", "0.2 0.3 0.4 0.5 scn", "0.1 0.2 SCN"}
	for i := 0; i < 128; i++ {
		var s strings.Builder
		for j := 0; j < 20; j++ {
			s.WriteString(commands[rand.Intn(len(commands))])
			s.WriteByte('\n')
		}
		cases = append(cases, s.String())
	}
	for idx, content := range cases {
		if idx%16 == 0 {
			fmt.Fprintf(out, "///|\ntest \"PDF graphics output matches upstream Go %d\" {\n", idx/16)
		}
		c := &converter{pdf: &pdf{ctx: ctx}, warned: map[string]bool{}}
		p := newPending(bdf.Rect{X: 0, Y: 0, W: 612, H: 792})
		base := matrix{1, 0, 0, -1, 0, 792}
		in := c.newInterp(p, nil, base, 0)
		in.transform(base)
		in.run([]byte(content))
		fmt.Fprintf(out, "check_pdf_graphics(%s,%s)\n", graphicsBytes([]byte(content)), graphicsBytes(p.obj.Encode()))
		if idx%16 == 15 || idx == len(cases)-1 {
			fmt.Fprintln(out, "}")
		}
	}
}
