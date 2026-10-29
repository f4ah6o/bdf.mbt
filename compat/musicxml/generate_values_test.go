//go:build ignore

// Copy into upstream converter/musicxml and run TestCodexMusicXMLValues.
package musicxml
import ("encoding/json"; "math/rand"; "os"; "path/filepath"; "testing")
func TestCodexMusicXMLValues(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT");if root==""{t.Fatal("BDF_FIXTURE_ROOT required")};r:=rand.New(rand.NewSource(104571));samples:=[]string{"", "1", "+1", "001", "0", "-1", "99", "100", "1.5", "-1.5", " 2 ", "foo", "9e2", "NaN", "Inf", "-Inf", "0x1.8p2", "1_000", "1-3", "1-100", "2,4;7.9", "1-2-3", "1000000000.5", "999999999999999999999999999", "  -0.5 ", "0x1p_2", "0x1p+_2", "0x1_8.0_p2", "0x_1p2", "0x0p999999", "0x1p-999999", "1e_2", "1e+2", "1__0", "1_0.0_2"};chars:=[]byte("0123456789abcdef-+ .,;eE_\t");for i:=0;i<10000;i++{s:=make([]byte,r.Intn(25));for j:=range s{s[j]=chars[r.Intn(len(chars))]};samples=append(samples,string(s))}
 for i:=0;i<3000;i++{digits:=[]byte("0123456789abcdef._");n:=1+r.Intn(12);v:=make([]byte,n);for j:=range v{v[j]=digits[r.Intn(len(digits))]};samples=append(samples,"0x"+string(v)+"p"+[]string{"1","-2","4","-32","+3","0","_2","+_2"}[r.Intn(8)])}
 out:=[]any{};for _,s:=range samples{n,nok:=atoi(s);f,fok:=parseFloat(s);end,more:=endingNumbers(s);if end==nil{end=[]int{}};out=append(out,map[string]any{"input":s,"want":[]any{n,nok,f,fok,end,more}})}
 b,e:=json.Marshal(out);if e!=nil{t.Fatal(e)};if e=os.WriteFile(filepath.Join(root,"compat/musicxml/values.json"),b,0644);e!=nil{t.Fatal(e)}
}
