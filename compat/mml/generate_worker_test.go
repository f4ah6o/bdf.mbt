//go:build ignore

// Copy into upstream converter/mml and run TestCodexMMLWorker.
package mml
import ("bytes"; "compress/gzip"; "encoding/json"; "os"; "path/filepath"; "testing"; conv "github.com/shibukawa/bdf/converter"; "github.com/shibukawa/bdf/converter/internal/music")
func TestCodexMMLWorker(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT");if root==""{t.Fatal("BDF_FIXTURE_ROOT required")};out:=[]any{}
 for _,name:=range []string{"twinkle.mml","ode.mml","frere.mml","sjis.mml"} {input,err:=os.ReadFile(filepath.Join("testdata",name));if err!=nil{t.Fatal(err)}
  for _,test:=range []struct{dialect,octave,program,time,key,pages,tab string}{{},{"generic","reverse","3","3/4","Bb","1-","false"},{"auto","normal","80","cut","F#m","2,1,99","true"}} {
   co:=&conv.Options{Params:map[string]string{"dialect":test.dialect,"octave":test.octave,"program":test.program,"time":test.time,"key":test.key,"tab":test.tab}};opts,no,err:=options(co);if err!=nil{t.Fatal(err)};tab,err:=music.TabEnabled(co);if err!=nil{t.Fatal(err)};pages,err:=conv.ParsePages(test.pages);if err!=nil{t.Fatal(err)};p,warnings,err:=Parse(input,opts);if err!=nil{t.Fatal(err)}
   res,err:=music.Build(music.Notate(p,no),music.Options{Source:"mml",Pages:pages,NoSystemFonts:true,NoWOFF2:true,GuitarTAB:tab});if err!=nil{t.Fatal(err)};var bdf bytes.Buffer;if err=res.Doc.WriteSingle(&bdf);err!=nil{t.Fatal(err)};warnings=append(warnings,res.Warnings...);if warnings==nil{warnings=[]string{}}
   out=append(out,map[string]any{"name":name,"input":input,"bdf":bdf.Bytes(),"dialect":test.dialect,"octave":test.octave,"program":test.program,"time":test.time,"key":test.key,"pages":test.pages,"tab":test.tab,"summary":res.Summary(),"warnings":warnings})
  }
 }
 b,err:=json.Marshal(out);if err!=nil{t.Fatal(err)};var buf bytes.Buffer;z:=gzip.NewWriter(&buf);if _,err=z.Write(b);err!=nil{t.Fatal(err)};if err=z.Close();err!=nil{t.Fatal(err)};if err=os.WriteFile(filepath.Join(root,"compat/mml/worker.json.gz"),buf.Bytes(),0644);err!=nil{t.Fatal(err)}
}
