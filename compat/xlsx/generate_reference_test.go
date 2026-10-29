//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexXLSXReferences.
package xlsx
import("encoding/json";"math/rand";"os";"path/filepath";"testing")
func TestCodexXLSXReferences(t *testing.T){root:=os.Getenv("BDF_FIXTURE_ROOT");if root==""{t.Fatal("BDF_FIXTURE_ROOT required")};samples:=[]string{"A1","$A$1","XFD1048576","XFE1","A1048577"," a+1 ","A-1","$$A$$01","日本語","","_x000D__x000A_","_xD800_","_x005F_x000A_","a\r\nb\rc","_x0041_","_X0041_","_xDEAD_","_x00GG_"};r:=rand.New(rand.NewSource(852114));chars:=[]rune("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789$-+_ :\t\r\n日本語");for i:=0;i<20000;i++{v:=make([]rune,r.Intn(30));for j:=range v{v[j]=chars[r.Intn(len(chars))]};samples=append(samples,string(v))};out:=[]any{};for i,s:=range samples{c,row,ok:=parseRef(s);col:=i%20000-100;out=append(out,map[string]any{"input":s,"column":col,"want":[]any{c,row,ok,colName(col),decodeXString(s)}})};b,e:=json.Marshal(out);if e!=nil{t.Fatal(e)};if e=os.WriteFile(filepath.Join(root,"compat/xlsx/reference.json"),b,0644);e!=nil{t.Fatal(e)}}
