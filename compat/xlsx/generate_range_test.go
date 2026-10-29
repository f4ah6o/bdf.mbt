//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexXLSXRanges.
package xlsx
import("encoding/json";"fmt";"math/rand";"os";"path/filepath";"testing")
func TestCodexXLSXRanges(t *testing.T){root:=os.Getenv("BDF_FIXTURE_ROOT");if root==""{t.Fatal("BDF_FIXTURE_ROOT required")};samples:=[]string{"","A1","A1:C4","C4:A1","A:C","$A:$XFD","1:99","$2:$5","  A1:B9  ","A1: C3","3:9999999999","A1:B2:C3","A1:A1","-1:3","０:3"};r:=rand.New(rand.NewSource(591852));atoms:=[]string{"A","$C","XFD","XFE","A1","$B$3","5","123","1048577","$3","ab9","abc","","  A1 ","+5","-1"};for i:=0;i<10000;i++{if i%3==0{samples=append(samples,atoms[r.Intn(len(atoms))])}else{samples=append(samples,fmt.Sprintf("%s:%s",atoms[r.Intn(len(atoms))],atoms[r.Intn(len(atoms))]))}};out:=[]any{};for _,s:=range samples{v,ok:=parseRange(s);out=append(out,map[string]any{"input":s,"want":[]any{v.r0,v.c0,v.r1,v.c1,ok}})};b,e:=json.Marshal(out);if e!=nil{t.Fatal(e)};if e=os.WriteFile(filepath.Join(root,"compat/xlsx/range.json"),b,0644);e!=nil{t.Fatal(e)}}
