//go:build ignore

// Copy into upstream converter/mml and run TestCodexMMLScan.
package mml
import ("encoding/json"; "math/rand"; "os"; "path/filepath"; "testing")
func TestCodexMMLScan(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT"); if root=="" {t.Fatal("BDF_FIXTURE_ROOT required")};r:=rand.New(rand.NewSource(1234580))
 samples:=[]string{"", "0", "0.12345", "+00125...foo", "%0..", "%", "123456789012345678901234567890.123456789", "[a[b]c|d]", "/:a/:b:/c/d:/", "{abc}", "日本語"}
 chars:=[]byte("0123456789.+-%[,]{}:/|abcdefgr \t");for i:=0;i<14000;i++ {s:=make([]byte,r.Intn(40));for j:=range s{s[j]=chars[r.Intn(len(chars))]};samples=append(samples,string(s))}
 out:=[]any{};for _,text:=range samples {b:=[]byte(text);idx:=0;n,nok:=number(b,&idx);ni:=idx;idx=0;sg,sok:=signed(b,&idx);si:=idx;idx=0;dec,dok:=decimal(b,&idx);di:=idx;idx=0;v:=&voice{pct:384};ln,lok:=v.lengthArg(b,&idx);li:=idx;idx=0;dot:=dots(b,&idx,960);dit:=idx;idx=0;skipArgs(b,&idx);out=append(out,map[string]any{"input":text,"want":[]any{n,nok,ni,sg,sok,si,dec,dok,di,ln,lok,li,dot,dit,idx,closing(b,0,'[',']'),closing(b,0,'{','}'),closingSlash(b,0),breakAt(b,'['),breakAt(b,'/')}})}
 data,err:=json.Marshal(out);if err!=nil{t.Fatal(err)};if err=os.WriteFile(filepath.Join(root,"compat/mml/scan.json"),data,0644);err!=nil{t.Fatal(err)}
}
