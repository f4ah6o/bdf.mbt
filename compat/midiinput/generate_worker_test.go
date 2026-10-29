//go:build ignore

// Copy into upstream converter/midi and run TestCodexMidiWorker.
package midi

import (
 "bytes"
 "compress/gzip"
 "encoding/json"
 "os"
 "path/filepath"
 "testing"
 conv "github.com/shibukawa/bdf/converter"
 "github.com/shibukawa/bdf/converter/internal/music"
)
func TestCodexMidiWorker(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT");if root=="" {t.Fatal("BDF_FIXTURE_ROOT required")};out:=[]any{}
 for _,name:=range []string{"twinkle.kar","ode.mid","ode.rmi"} {
  input,err:=os.ReadFile(filepath.Join("testdata",name));if err!=nil {t.Fatal(err)}
  for _,test:=range []struct{time,key,pages,tab string}{{},{"3/4","Bb","1-","false"},{"cut","F#m","2,1,99","true"}} {
   p,err:=Parse(input,nil);if err!=nil {t.Fatal(err)};co:=&conv.Options{Params:map[string]string{"time":test.time,"key":test.key,"tab":test.tab}};no,err:=music.NotateParams(co);if err!=nil {t.Fatal(err)};tab,err:=music.TabEnabled(co);if err!=nil {t.Fatal(err)};pages,err:=conv.ParsePages(test.pages);if err!=nil {t.Fatal(err)}
   score:=music.Notate(p.Perf,no);score.SMF=p.SMF;res,err:=music.Build(score,music.Options{Source:"midi",Pages:pages,NoSystemFonts:true,NoWOFF2:true,GuitarTAB:tab});if err!=nil {t.Fatal(err)}
   var bdf bytes.Buffer;if err=res.Doc.WriteSingle(&bdf);err!=nil {t.Fatal(err)};warnings:=append(p.Warnings,res.Warnings...);if warnings==nil {warnings=[]string{}}
   out=append(out,map[string]any{"name":name,"input":input,"bdf":bdf.Bytes(),"time":test.time,"key":test.key,"pages":test.pages,"tab":test.tab,"summary":res.Summary(),"warnings":warnings})
  }
 }
 b,err:=json.Marshal(out);if err!=nil {t.Fatal(err)};var buf bytes.Buffer;z:=gzip.NewWriter(&buf);if _,err=z.Write(b);err!=nil {t.Fatal(err)};if err=z.Close();err!=nil {t.Fatal(err)};if err=os.WriteFile(filepath.Join(root,"compat/midiinput/worker.json.gz"),buf.Bytes(),0644);err!=nil {t.Fatal(err)}
}
