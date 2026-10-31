//go:build ignore

// Copy this file and generate_object_test.go without their build tags into
// upstream converter/pdf. Set BDF_PDF_FIXTURES to its testdata directory and
// BDF_REFERENCE_OUTPUT to generate the MoonBit reference test.
package pdf

import (
	"context"
	"fmt"
	"github.com/pdfcpu/pdfcpu/pkg/pdfcpu/model"
	"os"
	"path/filepath"
	"regexp"
	"testing"
)

func TestCodexRealPDFObjects(t *testing.T) {
	dir := os.Getenv("BDF_PDF_FIXTURES")
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dir == "" || dest == "" {
		t.Fatal("BDF_PDF_FIXTURES and BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(dest)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	names := []string{"cairo-cff.pdf", "cairo-type1.pdf", "chrome-doc.pdf", "chrome-masks.pdf", "chrome-slides.pdf", "cjk-cmaps.pdf", "images-jpx-jbig2.pdf", "reportlab-master.pdf", "reportlab-mixed.pdf", "reportlab-type1.pdf", "weasyprint-webfonts.pdf"}
	objectStart := regexp.MustCompile(`(?m)(?:^|[\r\n])\d+[ \t]+\d+[ \t]+obj[ \t\r\n]+`)
	count := 0
	for _, name := range names {
		data, err := os.ReadFile(filepath.Join(dir, name))
		if err != nil {
			t.Fatal(err)
		}
		for _, loc := range objectStart.FindAllIndex(data, -1) {
			source := string(data[loc[1]:])
			rest := source
			_, err := model.ParseObject(context.Background(), &rest, 0)
			if err != nil {
				continue
			}
			used := len(source) - len(rest)
			if used == 0 || used > 4096 {
				continue
			}
			input := source[:used] + " endobj"
			rest = input
			value, err := model.ParseObject(context.Background(), &rest, 0)
			if err != nil {
				continue
			}
			expected := fmt.Sprintf("Some((%s,%d))", objectValue(value), len(input)-len(rest))
			if count%64 == 0 {
				fmt.Fprintf(out, "///|\ntest \"PDF real objects match upstream Go %d\" {\n", count/64)
			}
			fmt.Fprintf(out, "  check_pdf_object(%s,%s)\n", objectBytes([]byte(input)), expected)
			count++
			if count%64 == 0 {
				fmt.Fprintln(out, "}")
			}
		}
	}
	if count%64 != 0 {
		fmt.Fprintln(out, "}")
	}
	t.Logf("%d real PDF objects", count)
}
