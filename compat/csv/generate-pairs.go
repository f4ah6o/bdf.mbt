// Generate decoder digests in the pinned upstream Go checkout.
package main

import (
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"os"

	"golang.org/x/text/encoding"
	"golang.org/x/text/encoding/charmap"
	"golang.org/x/text/encoding/htmlindex"
	"golang.org/x/text/encoding/japanese"
	"golang.org/x/text/encoding/korean"
	"golang.org/x/text/encoding/simplifiedchinese"
	"golang.org/x/text/encoding/traditionalchinese"
	unicode "golang.org/x/text/encoding/unicode"
)

func main() {
	cases := []struct {
		name   string
		enc    encoding.Encoding
		prefix []byte
	}{
		{"shift_jis", japanese.ShiftJIS, nil},
		{"euc-jp", japanese.EUCJP, nil},
		{"gbk", simplifiedchinese.GBK, nil},
		{"gb18030", simplifiedchinese.GB18030, nil},
		{"big5", traditionalchinese.Big5, nil},
		{"euc-kr", korean.EUCKR, nil},
		{"windows-1252", charmap.Windows1252, nil},
		{"utf-16le", unicode.UTF16(unicode.LittleEndian, unicode.IgnoreBOM), nil},
		{"utf-16be", unicode.UTF16(unicode.BigEndian, unicode.IgnoreBOM), nil},
		{"euc-jp-triples", japanese.EUCJP, []byte{0x8f}},
		{"iso-2022-jp", japanese.ISO2022JP, nil},
		{"iso-jis0208", japanese.ISO2022JP, []byte{0x1b, 0x24, 0x42}},
		{"iso-jis0212", japanese.ISO2022JP, []byte{0x1b, 0x24, 0x28, 0x44}},
		{"iso-katakana", japanese.ISO2022JP, []byte{0x1b, 0x28, 0x49}},
		{"iso-roman", japanese.ISO2022JP, []byte{0x1b, 0x28, 0x4a}},
	}
	results := map[string]string{}
	for _, tc := range cases {
		hash := sha256.New()
		for i := 0; i < 65536; i++ {
			if len(tc.prefix) == 0 && (i == 0xfffe || i == 0xfeff) {
				continue
			} // BOM overrides the named encoding
			data := []byte{byte(i >> 8), byte(i)}
			data = append(append([]byte{}, tc.prefix...), data...)
			decoded, err := tc.enc.NewDecoder().Bytes(data)
			if err != nil {
				panic(err)
			}
			var length [4]byte
			binary.BigEndian.PutUint32(length[:], uint32(len(decoded)))
			hash.Write(length[:])
			hash.Write(decoded)
		}
		results[tc.name] = hex.EncodeToString(hash.Sum(nil))
	}
	ranges := sha256.New()
	for i := 0; i < 39420; i++ {
		data := []byte{byte(i/12600 + 0x81), byte(i/1260%10 + 0x30), byte(i/10%126 + 0x81), byte(i%10 + 0x30)}
		decoded, err := simplifiedchinese.GB18030.NewDecoder().Bytes(data)
		if err != nil {
			panic(err)
		}
		var length [4]byte
		binary.BigEndian.PutUint32(length[:], uint32(len(decoded)))
		ranges.Write(length[:])
		ranges.Write(decoded)
	}
	results["gb18030-ranges"] = hex.EncodeToString(ranges.Sum(nil))
	labels := []string{"ibm866", "iso-8859-2", "iso-8859-3", "iso-8859-4", "iso-8859-5", "iso-8859-6", "iso-8859-7", "iso-8859-8", "iso-8859-8-i", "iso-8859-10", "iso-8859-13", "iso-8859-14", "iso-8859-15", "iso-8859-16", "koi8-r", "koi8-u", "macintosh", "windows-874", "windows-1250", "windows-1251", "windows-1252", "windows-1253", "windows-1254", "windows-1255", "windows-1256", "windows-1257", "windows-1258", "x-mac-cyrillic", "x-user-defined"}
	for _, label := range labels {
		enc, err := htmlindex.Get(label)
		if err != nil {
			panic(err)
		}
		hash := sha256.New()
		for i := 0; i < 256; i++ {
			decoded, err := enc.NewDecoder().Bytes([]byte{byte(i)})
			if err != nil {
				panic(err)
			}
			var length [4]byte
			binary.BigEndian.PutUint32(length[:], uint32(len(decoded)))
			hash.Write(length[:])
			hash.Write(decoded)
		}
		results["single:"+label] = hex.EncodeToString(hash.Sum(nil))
	}
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	if err := enc.Encode(results); err != nil {
		panic(err)
	}
}
