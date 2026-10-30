//go:build ignore

// Copy without its build tag beside upstream converter/pdf and run
// TestCodexPDFObjects with BDF_REFERENCE_OUTPUT set.
package pdf

import (
	"context"
	"fmt"
	"github.com/pdfcpu/pdfcpu/pkg/pdfcpu/model"
	"github.com/pdfcpu/pdfcpu/pkg/pdfcpu/types"
	"math/rand"
	"os"
	"sort"
	"strings"
	"testing"
)

func objectBytes(b []byte) string {
	var s strings.Builder
	s.WriteString(`b"`)
	for _, c := range b {
		fmt.Fprintf(&s, `\x%02x`, c)
	}
	s.WriteString(`"`)
	return s.String()
}
func objectValue(v types.Object) string {
	switch v := v.(type) {
	case nil:
		return "PdfNull"
	case types.Boolean:
		return fmt.Sprintf("PdfBool(%t)", v)
	case types.Integer:
		return fmt.Sprintf("PdfInt(%dL)", v)
	case types.Float:
		return fmt.Sprintf("PdfReal(%.17g)", v)
	case types.Name:
		return "PdfName(" + objectBytes([]byte(v)) + ")"
	case types.StringLiteral:
		b, err := types.Unescape(v.Value())
		if err != nil {
			panic(err)
		}
		return "PdfString(" + objectBytes(b) + ")"
	case types.HexLiteral:
		b, err := v.Bytes()
		if err != nil {
			panic(err)
		}
		return "PdfHex(" + objectBytes(b) + ")"
	case types.IndirectRef:
		return fmt.Sprintf("PdfRef(%dL,%dL)", v.ObjectNumber, v.GenerationNumber)
	case types.Array:
		a := make([]string, len(v))
		for i, x := range v {
			a[i] = objectValue(x)
		}
		return "PdfArray([" + strings.Join(a, ",") + "])"
	case types.Dict:
		keys := make([]string, 0, len(v))
		for k := range v {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		a := make([]string, 0, len(keys))
		for _, k := range keys {
			a = append(a, "("+objectBytes([]byte(k))+","+objectValue(v[k])+")")
		}
		return "PdfDict([" + strings.Join(a, ",") + "])"
	default:
		panic(fmt.Sprintf("unexpected %T", v))
	}
}

func randomPDFObject(rng *rand.Rand, depth int) string {
	atoms := []string{"0", "-12", "3.5", "/Name#20x", "(a\\n(b))", "<0a1>", "true", "false", "null", "21 0 R"}
	if depth >= 4 || rng.Intn(3) == 0 {
		return atoms[rng.Intn(len(atoms))]
	}
	if rng.Intn(2) == 0 {
		var out strings.Builder
		out.WriteString("[")
		for i := 0; i < rng.Intn(5); i++ {
			out.WriteString(randomPDFObject(rng, depth+1))
			out.WriteByte(' ')
		}
		out.WriteString("]")
		return out.String()
	}
	var out strings.Builder
	out.WriteString("<< ")
	for _, name := range []string{"A", "B", "C"} {
		if rng.Intn(2) == 0 {
			fmt.Fprintf(&out, "/%s %s ", name, randomPDFObject(rng, depth+1))
		}
	}
	out.WriteString(">>")
	return out.String()
}
func TestCodexPDFObjects(t *testing.T) {
	dest := os.Getenv("BDF_REFERENCE_OUTPUT")
	if dest == "" {
		t.Fatal("BDF_REFERENCE_OUTPUT required")
	}
	out, err := os.Create(dest)
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	atoms := []string{"0", "-12", "+3", "0003", "9223372036854775808", "3.5", ".5", "-.5", "1,5", "0-2", "1e3", "word", "true", "FALSE", "null", "/Name#20x", "/Byte#ff", "/Bad#xx", "(a(b)\\n\\101)", "<00 ff 1>", "<badZ>", "[]", "[1 2 0 R /A (x) true null]", "<< /A 1 /B 2 0 R >>", "<< /A null /A 3 >>", "<< /A 1 /A null >>", "<< /A [1 2 3] >>", "2 0 R", "0 65535 R", "(unterminated", "<abc", "[1 2", "<< /A 1"}
	atoms = append(atoms, "-0", "+0", "-9223372036854775809", "3.4.5", "TRUE", "True", "1.0 0 R", "1 2 Rabc", "1 2 3", "0.000-3", ".-5", "1,,2", "/A#00", "/A#", "/A{B}", "(a\r\nb)", "(x\\777y)", "(a\\\r\nb)", "(\\(x\\))", "<>", "<0>", "<<>>", "<< /A null >>", "<< /A true /B [1 2 0 R] >>", "[[] [1 0 R] << /A 1 >>]", "[1%comment\n2]", "<< /A 1 %comment\n /B 2 >>", "[1 2]tail", "<abc>tail", "<< /A 1 >", "/A#2Fname")
	atoms = append(atoms, "1 99999999999999999999 R", "1 0-2 R", "1 03 R", "1 -2 R", "1 +2 R", "1 2 Rabc", "9223372036854775808 0 R")
	rng := rand.New(rand.NewSource(920483))
	fmt.Fprintln(out, "// Generated from upstream pdfcpu file-object parsing.")
	count := 0
	emit := func(input, expected string) {
		if count%128 == 0 {
			fmt.Fprintf(out, "///|\ntest \"PDF file objects match upstream Go %d\" {\n", count/128)
		}
		fmt.Fprintf(out, "  check_pdf_object(%s,%s)\n", objectBytes([]byte(input)), expected)
		count++
		if count%128 == 0 {
			fmt.Fprintln(out, "}")
		}
	}
	for i := 0; i < 4096; i++ {
		a := atoms[rng.Intn(len(atoms))]
		prefix := []string{"", " ", "\n", "% comment\n"}[rng.Intn(4)]
		suffix := []string{"", " tail", " 4 0 R", " /X", " ]"}[rng.Intn(5)]
		input := prefix + a + suffix
		rest := input
		value, e := model.ParseObject(context.Background(), &rest, 0)
		expected := "None"
		if e == nil {
			expected = fmt.Sprintf("Some((%s,%d))", objectValue(value), len(input)-len(rest))
		}
		emit(input, expected)
	}
	for i := 0; i < 768; i++ {
		input := randomPDFObject(rng, 0) + " endobj"
		rest := input
		value, e := model.ParseObject(context.Background(), &rest, 0)
		expected := "None"
		if e == nil {
			expected = fmt.Sprintf("Some((%s,%d))", objectValue(value), len(input)-len(rest))
		}
		emit(input, expected)
	}
	for i := 0; i < 2048; i++ {
		alphabet := []byte("0123456789+-.,eEabcdef")
		token := make([]byte, 1+rng.Intn(12))
		for j := range token {
			token[j] = alphabet[rng.Intn(len(alphabet))]
		}
		input := string(token) + []string{"", " /X", " 0 R", " 1 0 R"}[rng.Intn(4)]
		rest := input
		value, err := model.ParseObject(context.Background(), &rest, 0)
		expected := "None"
		if err == nil {
			expected = fmt.Sprintf("Some((%s,%d))", objectValue(value), len(input)-len(rest))
		}
		emit(input, expected)
	}
	if count%128 != 0 {
		fmt.Fprintln(out, "}")
	}
	fmt.Fprintln(out, `

///|
test "PDF file object depth matches upstream Go" {`)
	for _, n := range []int{98, 99, 100, 101, 102, 200} {
		for _, pair := range [][2]string{{"[", "]"}, {"<< /A ", " >>"}} {
			input := strings.Repeat(pair[0], n) + "1" + strings.Repeat(pair[1], n)
			rest := input
			_, err := model.ParseObject(context.Background(), &rest, 0)
			fmt.Fprintf(out, "  check_pdf_object_depth(%s,%t)\n", objectBytes([]byte(input)), err == nil)
		}
	}
	fmt.Fprintln(out, `}

///|
fn check_pdf_object_depth(input : Bytes, expected : Bool) -> Unit raise {
  let reader : PdfObjectReader = { data: input, pos: 0 }
  let actual = try { ignore(reader.read(0)); true } catch { _ => false }
  assert_eq(actual, expected)
}

///|
fn check_pdf_object(input : Bytes, expected : (PdfObject, Int)?) -> Unit raise {
  let reader : PdfObjectReader = { data: input, pos: 0 }
  let actual : (PdfObject, Int)? = try { let value = reader.read(0); Some((normalize_pdf_object(value), reader.pos)) } catch { _ => None }
  assert_eq(actual, expected, msg=@utf8.decode_lossy(input[:]))
}`)
}
