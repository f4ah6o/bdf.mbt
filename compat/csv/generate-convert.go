//go:build ignore

// Generate CSV conversion fixtures without fonts, with and without text indexes.
package main

import (
	"bytes"
	stdcsv "encoding/csv"
	"encoding/json"
	conv "github.com/shibukawa/bdf/converter"
	"github.com/shibukawa/bdf/converter/csv"
	"os"
	"strconv"
	"strings"
)

type input struct {
	Data                 []byte
	Name, Title, Charset string
	Delimiter, Quote     rune
	Header               csv.Header
	Mode                 string
	NoTextIndex          bool
}

func main() {
	inputs := []input{
		{Data: []byte("")},
		{Data: []byte("name,amount\nAlice,1\nBob,2.5\n"), Name: "People", Title: "Report", Header: csv.HeaderYes},
		{Data: []byte("0012,abc\n1003,hello\n"), Header: csv.HeaderNo, Mode: "none"},
		{Data: []byte("商品;価格\n鉛筆;20\n消しゴム;100\n"), Name: "商品", Header: csv.HeaderAuto, Delimiter: ';'},
		{Data: []byte("col1,col2\n\"one\ntwo\",3\nz,4\n"), Header: csv.HeaderYes, Mode: "all"},
		{Data: []byte("a,b\n\"unterminated"), Header: csv.HeaderYes},
		{Data: []byte("\xff\xfeA\x00,\x00B\x00\n\x001\x00,\x002\x00\n\x00"), Header: csv.HeaderYes},
		{Data: []byte("code,value\n0001," + strings.Repeat("long text ", 150) + "\n0002,end\n"), Header: csv.HeaderYes},
		{Data: []byte("날짜,수량\n2024-01-01,10\n2024-01-02,20\n"), Name: "매출", Header: csv.HeaderYes},
		{Data: []byte("name|note\n'Ann'|'one|two'\n'Bob'|'ok'\n"), Name: "quotes", Header: csv.HeaderYes, Delimiter: '|', Quote: '\''},
		{Data: []byte("name,value\n'Ann',1\n'Bob',2\n"), Name: "literal", Header: csv.HeaderYes, Quote: -1},
		{Data: []byte("name,value\ncaf\xe9,1\nni\xf1o,2\n"), Name: "latin", Header: csv.HeaderYes, Charset: "cp1252"},
		{Data: []byte("name value\nAnn 1\nBob 2\n"), Name: "space", Header: csv.HeaderYes, Delimiter: ' '},
	}
	texts := []string{"hello", "漢字", "かな ABC", "한글", "\t spaces ", "line\nwrap", "0007", "abc-def", ""}
	for i := 0; i < 20; i++ {
		var data bytes.Buffer
		writer := stdcsv.NewWriter(&data)
		if err := writer.Write([]string{"name", "code", "notes"}); err != nil {
			panic(err)
		}
		for r := 0; r < 4; r++ {
			note := texts[(i*3+r*5)%len(texts)]
			if (i+r)%9 == 0 {
				note += strings.Repeat("xyz", 300)
			}
			if err := writer.Write([]string{texts[(i+r)%len(texts)], strconv.Itoa(i*10 + r), note}); err != nil {
				panic(err)
			}
		}
		writer.Flush()
		if err := writer.Error(); err != nil {
			panic(err)
		}
		mode := ""
		if i%3 == 0 {
			mode = "none"
		} else if i%3 == 1 {
			mode = "all"
		}
		inputs = append(inputs, input{Data: data.Bytes(), Name: "Sample", Header: csv.HeaderYes, Mode: mode})
	}
	for i := range inputs {
		inputs[i].NoTextIndex = true
	}
	for _, in := range append([]input(nil), inputs...) {
		in.NoTextIndex = false
		inputs = append(inputs, in)
	}
	result := []any{}
	for _, in := range inputs {
		opts := &csv.Options{Name: in.Name, Title: in.Title, Charset: in.Charset, Delimiter: in.Delimiter, Quote: in.Quote, Header: in.Header, Data: in.Mode, NoSystemFonts: true, NoTextIndex: in.NoTextIndex}
		converted, err := csv.Convert(bytes.NewReader(in.Data), int64(len(in.Data)), opts)
		if err != nil {
			panic(err)
		}
		var b bytes.Buffer
		if err := converted.Doc.WriteSingle(&b); err != nil {
			panic(err)
		}
		params := map[string]string{"charset": in.Charset, "data": in.Mode}
		if in.Delimiter != 0 {
			params["delimiter"] = string(in.Delimiter)
		}
		if in.Quote == -1 {
			params["quote"] = "none"
		} else if in.Quote != 0 {
			params["quote"] = string(in.Quote)
		}
		if in.Header == csv.HeaderYes {
			params["header"] = "true"
		} else if in.Header == csv.HeaderNo {
			params["header"] = "false"
		}
		registered, err := conv.Convert(bytes.NewReader(in.Data), int64(len(in.Data)), "csv", &conv.Options{
			NoSystemFonts: true, NoTextIndex: in.NoTextIndex, FileName: in.Name, Title: in.Title, Params: params,
		})
		if err != nil {
			panic(err)
		}
		result = append(result, map[string]any{
			"input": in, "bdf": b.Bytes(), "warnings": converted.Warnings,
			"charset": converted.Charset, "bom": converted.BOM, "header": converted.Header,
			"rows": converted.Rows, "columns": converted.Cols,
			"summary": registered.Summary,
		})
	}
	if err := json.NewEncoder(os.Stdout).Encode(result); err != nil {
		panic(err)
	}
}
