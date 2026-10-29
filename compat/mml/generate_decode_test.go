//go:build ignore

// Copy into upstream converter/mml and run TestCodexMMLDecode.
package mml

import (
 "encoding/json"
 "math/rand"
 "os"
 "path/filepath"
 "testing"
)
func TestCodexMMLDecode(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT");if root=="" {t.Fatal("BDF_FIXTURE_ROOT required")};r:=rand.New(rand.NewSource(931755));out:=[]any{}
 inputs:=[][]byte{[]byte("abc\r\ndef\r"),{0xef,0xbb,0xbf,0xff,0xff},{0xff,0xfe,0,0},{0xfe,0xff,0xd8,0},{0x82,0xa0,0x0d,0x0a}, {0xff,0xfe,0x00}, {0xef,0xbb,0xbf}}
 for i:=0;i<10000;i++ {b:=make([]byte,r.Intn(25));r.Read(b);switch i%7 {case 0:b=append([]byte{0xef,0xbb,0xbf},b...);case 1:b=append([]byte{0xff,0xfe},b...);case 2:b=append([]byte{0xfe,0xff},b...)};inputs=append(inputs,b)}
 for _,b:=range inputs {out=append(out,map[string]any{"input":b,"want":decode(b)})}
 data,err:=json.Marshal(out);if err!=nil {t.Fatal(err)};if err=os.WriteFile(filepath.Join(root,"compat/mml/decode.json"),data,0644);err!=nil {t.Fatal(err)}
}
