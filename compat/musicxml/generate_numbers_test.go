//go:build ignore

// Copy into upstream converter/musicxml and run TestCodexMusicXMLNumbers.
package musicxml
import ("encoding/json"; "math/rand"; "os"; "path/filepath"; "testing")
func TestCodexMusicXMLNumbers(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT");if root==""{t.Fatal("BDF_FIXTURE_ROOT required")};r:=rand.New(rand.NewSource(93355));names:=[]string{"","1","01","+1","2","99","100","0","-1","bass","treble","2.0"," 3 ","一","99","1e3"};out:=[]any{};for i:=0;i<2000;i++ {max:=[]int{0,1,2,5,99}[r.Intn(5)];n:=newNumbers(max);input:=[]string{};want:=[]int{};for j:=0;j<1+r.Intn(30);j++ {s:=names[r.Intn(len(names))];input=append(input,s);want=append(want,n.get(s))};out=append(out,map[string]any{"max":max,"input":input,"want":want})};b,e:=json.Marshal(out);if e!=nil{t.Fatal(e)};if e=os.WriteFile(filepath.Join(root,"compat/musicxml/numbers.json"),b,0644);e!=nil{t.Fatal(e)}
}
