package csv

import (
	"bytes"
	"encoding/json"
	"github.com/shibukawa/bdf/converter/internal/hpglsniff"
	"math/rand"
	"os"
	"strings"
	"testing"
)

func TestCodexGenerateDetection(t *testing.T) {
	path := os.Getenv("BDF_CSV_DETECT_FIXTURE")
	if path == "" {
		t.Skip("fixture path not set")
	}
	inputs := [][]byte{
		{}, []byte("a,b\n1,2\n"), []byte("one line"), []byte("a;b\n1;2\n"),
		[]byte("%PDF-a,b\n1,2\n"), []byte("PK\x03\x04a,b\n1,2\n"),
		[]byte("<?xml a,b\n1,2\n"), []byte("<html a,b\n1,2\n"),
		[]byte("%FSLAX24Y24*%\na,b\n1,2\n"), []byte("G04 hello*\na,b\n1,2\n"),
		[]byte(";comment\nM48\na,b\n1,2\n"), []byte("IN;SP1;PA0,0;PD100,200;"),
		[]byte("@PJL ENTER LANGUAGE=HPGL2\r\nIN;SP1;PA1,2;"),
		[]byte("@PJL ENTER LANGUAGE=POSTSCRIPT\r\na,b\n1,2\n"),
		[]byte("\x1b%1BIN;SP1;PA0,0;"), []byte("\x1b*r1Aa,b\n1,2\n"),
		[]byte("a,b\n1,\x002\n"), []byte("a,b\n\xff,2\n"),
		[]byte("\xff\xfeA\x00,\x00B\x00\n\x001\x00,\x002\x00\n\x00"),
		[]byte("A\x00,\x00B\x00\n\x001\x00,\x002\x00\n\x00"),
		[]byte("\xef\xbb\xbfname,value\nAlice,12\n"),
		[]byte(strings.Repeat("a,b\n", 18000)),
		bytes.Repeat([]byte{'a', ',', 0xe9, '\n'}, 18000),
		[]byte("IN;SP1;DT~;LBHello~;PA20,30;"),
		[]byte("IN;SP1;CO\"test,here\";PA20,30;"),
		[]byte("IN;!VC100;SP2;PA0,1;PD2,3;"),
		[]byte("IN;BP1,\"picture\";SP1;PEabc;"),
		[]byte("\x1b.17:IN;SP1;PA0,0;"),
		[]byte("@PJL ENTER LANGUAGE=PCL\r\n\x1b%0BIN;"),
		[]byte("IN;SP;PA;"),
	}
	rng := rand.New(rand.NewSource(58))
	alphabet := []byte("ab123,;| \t\n\r\"'\\\x00\x1b%*")
	for i := 0; i < 500; i++ {
		n := rng.Intn(80)
		b := make([]byte, n)
		for j := range b {
			b[j] = alphabet[rng.Intn(len(alphabet))]
		}
		inputs = append(inputs, b)
	}
	type entry struct {
		Data     []byte
		Detected bool
		Plotter  bool
	}
	out := make([]entry, 0, len(inputs))
	for _, data := range inputs {
		head := data
		if len(head) > 1024 {
			head = head[:1024]
		}
		out = append(out, entry{Data: data, Detected: detect(head, bytes.NewReader(data), int64(len(data))), Plotter: hpglsniff.Is(head)})
	}
	f, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	if err := json.NewEncoder(f).Encode(out); err != nil {
		t.Fatal(err)
	}
}
