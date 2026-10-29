//go:build ignore

// Copy into upstream converter/musicxml and run TestCodexMusicXMLTextDetect.
package musicxml
import ("encoding/binary"; "encoding/json"; "math/rand"; "os"; "path/filepath"; "testing"; "unicode/utf16")
func TestCodexMusicXMLTextDetect(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT");if root==""{t.Fatal("BDF_FIXTURE_ROOT required")}
 strings:=[]string{"", "<score-partwise>", "<score-timewise>", " <?xml?><score-partwise>", "<x -//Recordare//DTD MusicXML 4.0 Partwise//EN>", "<x -//Recordare//DTD MusicXML-//Recordare//DTD MusicXML Partwise//EN>", "<x -//Recordare//DTD MusicXML Opus//EN>", "#<score-partwise>", "<score-partwisé>"}
 fragments:=[]string{"<", "score-partwise", "<score-partwise", "<score-timewise", "-//Recordare//DTD MusicXML", " Partwise", " Timewise", "//EN", "<x>", "<?xml?>", "日本語", "  ", "\n", "no", "MML"};r:=rand.New(rand.NewSource(321413));for i:=0;i<10000;i++{s:="";for j:=0;j<1+r.Intn(5);j++{s+=fragments[r.Intn(len(fragments))]};strings=append(strings,s)}
 out:=[]any{};for _,s:=range strings {for mode:=0;mode<5;mode++ {var input []byte;switch mode {case 0:input=[]byte(s);case 1:input=append([]byte{0xef,0xbb,0xbf},[]byte(s)...);default:units:=utf16.Encode([]rune(s));little:=mode==2 || mode==4;if mode==2 {input=[]byte{0xff,0xfe}}else if mode==3 {input=[]byte{0xfe,0xff}};for _,u:=range units {var b [2]byte;if little{binary.LittleEndian.PutUint16(b[:],u)}else{binary.BigEndian.PutUint16(b[:],u)};input=append(input,b[:]...)}};le,ok:=utf16Order(input);head:=headText(input);out=append(out,map[string]any{"input":input,"want":[]any{le,ok,head,isScoreText(head)}})}}
 b,err:=json.Marshal(out);if err!=nil{t.Fatal(err)};if err=os.WriteFile(filepath.Join(root,"compat/musicxml/detect.json"),b,0644);err!=nil{t.Fatal(err)}
}
