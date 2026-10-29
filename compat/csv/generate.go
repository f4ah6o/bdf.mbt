// Run in the pinned shibukawa/bdf checkout to create the compatibility data.
package main

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"strings"

	"github.com/shibukawa/bdf/converter/csv"
	"golang.org/x/text/encoding"
	"golang.org/x/text/encoding/charmap"
	"golang.org/x/text/encoding/htmlindex"
	"golang.org/x/text/encoding/japanese"
	"golang.org/x/text/encoding/korean"
	"golang.org/x/text/encoding/simplifiedchinese"
	"golang.org/x/text/encoding/traditionalchinese"
	unicode "golang.org/x/text/encoding/unicode"
	"golang.org/x/text/encoding/unicode/utf32"
)

type fixture struct {
	Name      string     `json:"name"`
	Input     string     `json:"input"`
	Label     string     `json:"label"`
	Charset   string     `json:"charset"`
	BOM       bool       `json:"bom"`
	Text      string     `json:"text"`
	Delimiter rune       `json:"delimiter"`
	Quote     rune       `json:"quote"`
	Escape    rune       `json:"escape"`
	Rows      [][]string `json:"rows"`
	Header    bool       `json:"header"`
	Columns   int        `json:"columns"`
	Warnings  []string   `json:"warnings"`
}

func encoded(enc encoding.Encoding, s string) []byte {
	b, err := enc.NewEncoder().Bytes([]byte(s))
	if err != nil {
		panic(err)
	}
	return b
}

func decoded(enc encoding.Encoding, b []byte) string {
	text, err := enc.NewDecoder().Bytes(b)
	if err != nil {
		panic(err)
	}
	return string(text)
}

func main() {
	ja := "名前,説明\n山田,ひらがなとカタカナの文章です。\n佐藤,漢字だけ\n"
	names := "氏名,住所\n山田太郎,東京都千代田区\n佐藤花子,大阪府大阪市\n"
	latin := "Name;City;Note\nMüller;Köln;Straße\nRenée;Besançon;“naïve” café – ok\n"
	stray := []byte(strings.Repeat("名前,説明\n", 5) + "caf\xe9\n")
	twoStray := []byte(strings.Repeat("名前,説明\n", 5) + "caf\xe9\xff\n")
	basic, err := os.ReadFile("converter/csv/testdata/basic.csv")
	if err != nil {
		panic(err)
	}
	japaneseFixture, err := os.ReadFile("converter/csv/testdata/japanese.tsv")
	if err != nil {
		panic(err)
	}
	chinese := "姓名,城市\n张三,北京\n李四,上海\n"
	traditional := "姓名,城市\n陳先生,臺北\n"
	koreanText := "이름,도시\n김철수,서울\n"
	cases := []struct {
		name        string
		data        []byte
		label, text string
	}{
		{"ascii", []byte("a,b\n1,2\n"), "", "a,b\n1,2\n"},
		{"utf8", []byte(ja), "", ja},
		{"utf8-bom", append([]byte{0xef, 0xbb, 0xbf}, []byte(ja)...), "cp932", ja},
		{"utf16le-bom", append([]byte{0xff, 0xfe}, encoded(unicode.UTF16(unicode.LittleEndian, unicode.IgnoreBOM), ja)...), "", ja},
		{"utf16be-bom", append([]byte{0xfe, 0xff}, encoded(unicode.UTF16(unicode.BigEndian, unicode.IgnoreBOM), ja)...), "", ja},
		{"utf32le-bom", append([]byte{0xff, 0xfe, 0, 0}, encoded(utf32.UTF32(utf32.LittleEndian, utf32.IgnoreBOM), "a,b")...), "", "a,b"},
		{"utf32be-bom", append([]byte{0, 0, 0xfe, 0xff}, encoded(utf32.UTF32(utf32.BigEndian, utf32.IgnoreBOM), "a,b")...), "", "a,b"},
		{"utf16le", encoded(unicode.UTF16(unicode.LittleEndian, unicode.IgnoreBOM), ja), "", ja},
		{"utf16be", encoded(unicode.UTF16(unicode.BigEndian, unicode.IgnoreBOM), latin), "", latin},
		{"sjis", encoded(japanese.ShiftJIS, ja), "", ja},
		{"sjis-kanji", encoded(japanese.ShiftJIS, names), "", names},
		{"sjis-named", encoded(japanese.ShiftJIS, ja), "cp932", ja},
		{"euc-jp", encoded(japanese.EUCJP, ja), "", ja},
		{"euc-jp-kanji", encoded(japanese.EUCJP, names), "", names},
		{"iso-2022-jp", encoded(japanese.ISO2022JP, ja), "", ja},
		{"windows-1252", encoded(charmap.Windows1252, latin), "", latin},
		{"windows-1252-named", encoded(charmap.Windows1252, latin), "latin1", latin},
		{"utf8-stray", stray, "", strings.Repeat("名前,説明\n", 5) + "caf�\n"},
		{"utf8-two-stray", twoStray, "", decoded(japanese.ShiftJIS, twoStray)},
		{"windows-undefined", []byte{'x', ',', 0x81, 0x8d, 0x8f, 0x90, 0x9d, '\n'}, "windows-1252", "x,�����\n"},
		{"basic.csv", basic, "", strings.TrimPrefix(string(basic), "\ufeff")},
		{"japanese.tsv", japaneseFixture, "", decoded(japanese.ShiftJIS, japaneseFixture)},
		{"gbk-named", encoded(simplifiedchinese.GBK, chinese), "cp936", chinese},
		{"gb18030-named", encoded(simplifiedchinese.GB18030, chinese+"😀\n"), "gb18030", chinese + "😀\n"},
		{"big5-named", encoded(traditionalchinese.Big5, traditional), "cp950", traditional},
		{"euc-kr-named", encoded(korean.EUCKR, koreanText), "cp949", koreanText},
	}
	out := []fixture{}
	for _, tc := range cases {
		rows, result, err := csv.Records(tc.data, &csv.Options{Charset: tc.label})
		if err != nil {
			panic(err)
		}
		for i, row := range rows {
			if row == nil {
				rows[i] = []string{}
			}
		}
		out = append(out, fixture{tc.name, base64.StdEncoding.EncodeToString(tc.data), tc.label, result.Charset, result.BOM, tc.text, result.Dialect.Delimiter, result.Dialect.Quote, result.Dialect.Escape, rows, result.Header, result.Cols, append([]string{}, result.Warnings...)})
	}
	// Reproducible malformed input probes compare decoding and all record-level
	// results, including the charset scorer's decisions.
	random := rand.New(rand.NewSource(71917))
	labels := []string{"", "utf-8", "shift_jis", "euc-jp", "iso-2022-jp", "windows-1252", "gbk", "big5", "euc-kr", "gb18030"}
	for i := 0; i < 200; i++ {
		data := make([]byte, 10+random.Intn(70))
		random.Read(data)
		label := labels[i%len(labels)]
		rows, result, err := csv.Records(data, &csv.Options{Charset: label})
		if err != nil {
			panic(err)
		}
		text := strings.ToValidUTF8(string(data), "�")
		if result.Charset != "UTF-8" {
			enc, err := htmlindex.Get(result.Charset)
			if err != nil {
				panic(err)
			}
			text = decoded(enc, data)
		}
		for j, row := range rows {
			if row == nil {
				rows[j] = []string{}
			}
		}
		out = append(out, fixture{fmt.Sprintf("random-%03d", i), base64.StdEncoding.EncodeToString(data), label, result.Charset, result.BOM, text, result.Dialect.Delimiter, result.Dialect.Quote, result.Dialect.Escape, rows, result.Header, result.Cols, append([]string{}, result.Warnings...)})
	}
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	if err := enc.Encode(out); err != nil {
		panic(err)
	}
}
