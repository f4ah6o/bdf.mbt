//go:build ignore

// Copy into upstream converter/musicxml and run TestCodexMusicXMLText.
package musicxml
import ("encoding/binary"; "encoding/json"; "math/rand"; "os"; "path/filepath"; "testing"; "unicode/utf16"; "github.com/shibukawa/bdf/internal/xmltree")
func TestCodexMusicXMLText(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT");if root==""{t.Fatal("BDF_FIXTURE_ROOT required")};r:=rand.New(rand.NewSource(123499));samples:=[][]byte{}
 for _,s:=range []string{"", "<score-partwise />", "<?xml version=\"1.0\" encoding=\"UTF-8\"?><score-partwise />", "<?xml encoding='shift_jis'?><x>", "<?xml encoding=\" latin1 \"?><x>", "<?xml encoding='UTF8'?>\x80\x81\x00", "\xef\xbb\xbf<x>\x00\x01\x09", "<?xml encoding='utf-8'?>日本語"} {samples=append(samples,[]byte(s));u:=utf16.Encode([]rune(s));for _,little:=range []bool{true,false} {b:=[]byte{0xfe,0xff};if little{b=[]byte{0xff,0xfe}};for _,v:=range u {var x [2]byte;if little{binary.LittleEndian.PutUint16(x[:],v)}else{binary.BigEndian.PutUint16(x[:],v)};b=append(b,x[:]...)};samples=append(samples,b)}}
 for i:=0;i<10000;i++ {b:=make([]byte,r.Intn(45));r.Read(b);switch i%4 {case 0:b=append([]byte("<?xml encoding='utf-8'?>"),b...);case 1:b=append([]byte("<?xml encoding='Shift_JIS'?>"),b...);case 2:b=append([]byte{0xff,0xfe},b...)};samples=append(samples,b)}
 out:=[]any{};for _,input:=range samples {label:=xmltree.DeclaredEncoding(input);data,note:=toUTF8(append([]byte{},input...));out=append(out,map[string]any{"input":input,"want":[]any{label,data,note}})};b,err:=json.Marshal(out);if err!=nil{t.Fatal(err)};if err=os.WriteFile(filepath.Join(root,"compat/musicxml/text.json"),b,0644);err!=nil{t.Fatal(err)}
}
