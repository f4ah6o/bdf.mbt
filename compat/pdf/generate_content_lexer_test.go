//go:build ignore

// Copy this file without the build tag beside the upstream PDF lexer and run
// TestCodexContentLexer with BDF_REFERENCE_OUTPUT set to regenerate the test.
package pdf

import (
	"fmt"
	"math/rand"
	"os"
	"strings"
	"testing"

	"github.com/pdfcpu/pdfcpu/pkg/pdfcpu/types"
)

func codexBytes(b []byte) string {
	var s strings.Builder
	s.WriteString(`b"`)
	for _, c := range b {
		fmt.Fprintf(&s, `\x%02x`, c)
	}
	s.WriteString(`"`)
	return s.String()
}
func codexValue(v types.Object) string {
	switch v := v.(type) {
	case nil:
		return "Null"
	case types.Integer:
		return fmt.Sprintf("Integer(%dL)", v)
	case types.Float:
		return fmt.Sprintf("Real(%.17g)", v)
	case types.Boolean:
		return fmt.Sprintf("Boolean(%t)", v)
	case types.Name:
		return "Name(" + codexBytes([]byte(v)) + ")"
	case types.StringLiteral:
		return "Literal(" + codexBytes([]byte(v)) + ")"
	case types.HexLiteral:
		return "Hex(" + codexBytes([]byte(v)) + ")"
	case types.Array:
		values := make([]string, len(v))
		for i, x := range v {
			values[i] = codexValue(x)
		}
		return "ArrayValue([" + strings.Join(values, ",") + "])"
	case types.Dict:
		// Fixtures use a single dictionary key, avoiding map order assumptions.
		if len(v) > 1 {
			panic("multiple keys")
		}
		for k, x := range v {
			return "Dictionary([(" + codexBytes([]byte(k)) + "," + codexValue(x) + ")])"
		}
		return "Dictionary([])"
	default:
		panic(fmt.Sprintf("unexpected %T", v))
	}
}
func TestCodexContentLexer(t *testing.T) {
	output := os.Getenv("BDF_REFERENCE_OUTPUT")
	if output == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	f, err := os.Create(output)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	fmt.Fprintln(f, "///|\n// Generated from the upstream PDF content-stream lexer.\ntest \"PDF content tokens match upstream Go\" {")
	r := rand.New(rand.NewSource(120730))
	pieces := []string{"1", "-2.5", "+3", "-0", ".5", "+.5", "-.5", "3.4.5", "--5", "1e-2", "1e999", "2E400", "5e-9999", "12e+", "1--2", "00003", "+0", "9223372036854775808", "-9223372036854775809", "/Name#20x", "/X#ff#00", "/bad#xx", "(a(b)\\n\\101)", "(abc\\\r\ndef)", "<a b c>", "<badZ>", "[1 q /X (z)]", "<</K 1 /K 2>>", "true", "false", "null", "q", "Tj", "%%hello\r\n", "]>}{", "\x00\x0c"}
	for i := 0; i < 512; i++ {
		var s strings.Builder
		for j := 0; j < 1+r.Intn(8); j++ {
			s.WriteString(pieces[r.Intn(len(pieces))])
			s.WriteByte(' ')
		}
		src := []byte(s.String())
		l := &lexer{b: src}
		var toks []string
		for {
			k, o, op := l.next()
			if k == tokEOF {
				break
			}
			if k == tokOperand {
				toks = append(toks, "Operand("+codexValue(o)+")")
			} else {
				toks = append(toks, "Operator("+codexBytes([]byte(op))+")")
			}
		}
		fmt.Fprintf(f, "  check_content_tokens(%s, [%s])\n", codexBytes(src), strings.Join(toks, ","))
	}
	fmt.Fprintln(f, `}

///|
test "PDF inline images match upstream Go" {`)
	images := []string{" abc EI Q", " abc EIx def EI Q", " EI Q", " x EI y EI Q", "\r\nabc EI/Q", "\x00\xff EI", " no terminator", " EI", " abc EI"}
	for _, input := range images {
		for _, length := range []int{-1, 0, 1, 3, 6, 100} {
			l := &lexer{b: []byte(input)}
			data := l.readInlineImageData(length)
			fmt.Fprintf(f, "  check_inline_image(%s, %d, %s, %d)\n", codexBytes([]byte(input)), length, codexBytes(data), l.pos)
		}
	}
	fmt.Fprintln(f, `}

///|
fn check_content_tokens(input : Bytes, expected : Array[ContentToken]) -> Unit raise {
  let lexer : ContentLexer = { data: input, pos: 0 }
  for token in expected { assert_eq(lexer.next(0), token) }
  assert_eq(lexer.next(0), End)
}

///|
fn check_inline_image(input : Bytes, length : Int, expected : Bytes, position : Int) -> Unit raise {
  let lexer : ContentLexer = { data: input, pos: 0 }
  assert_eq(lexer.read_inline_image(length), expected)
  assert_eq(lexer.pos, position)
}`)
}
