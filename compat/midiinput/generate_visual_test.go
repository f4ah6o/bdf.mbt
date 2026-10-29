//go:build ignore

// Copy into upstream converter/midi and run TestCodexMidiVisual.
package midi

import (
 "bytes"
 "compress/gzip"
 "encoding/json"
 "os"
 "path/filepath"
 "testing"
 "github.com/shibukawa/bdf/converter/internal/music"
)
func TestCodexMidiVisual(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT");if root=="" {t.Fatal("BDF_FIXTURE_ROOT required")};out:=[]any{}
 for _,name:=range []string{"twinkle.kar","ode.mid"} {
  input,err:=os.ReadFile(filepath.Join("testdata",name));if err!=nil {t.Fatal(err)};parsed,err:=Parse(input,nil);if err!=nil {t.Fatal(err)}
  score:=music.Notate(parsed.Perf,music.NotateOptions{});score.SMF=parsed.SMF
  result,err:=music.Build(score,music.Options{Source:"midi",NoSystemFonts:true,SystemFonts:true,GuitarTAB:true,PageWidth:500,PageHeight:700,StaffSpace:5});if err!=nil {t.Fatal(err)}
  var file bytes.Buffer;if err=result.Doc.WriteSingle(&file);err!=nil {t.Fatal(err)}
  out=append(out,map[string]any{"name":name,"input":input,"bdf":file.Bytes()})
 }
 data,err:=json.Marshal(out);if err!=nil {t.Fatal(err)};var buf bytes.Buffer;z:=gzip.NewWriter(&buf);if _,err=z.Write(data);err!=nil {t.Fatal(err)};if err=z.Close();err!=nil {t.Fatal(err)};if err=os.WriteFile(filepath.Join(root,"compat/midiinput/visual.json.gz"),buf.Bytes(),0644);err!=nil {t.Fatal(err)}
}
