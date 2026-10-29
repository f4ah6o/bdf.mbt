//go:build ignore

// Copy alongside generate_prepare_test.go into upstream converter/internal/music.
package music

import (
 "bytes"
 "compress/gzip"
 "encoding/json"
 "os"
 "path/filepath"
 "testing"
 "testing/fstest"
 "github.com/shibukawa/bdf"
)
func TestCodexRenderPagesFonts(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT");if root=="" {t.Fatal("BDF_FIXTURE_ROOT required")}
 raw,err:=os.ReadFile(filepath.Join(root,"compat/midiinput/score.json"));if err!=nil {t.Fatal(err)};var samples []codexFixture;if err=json.Unmarshal(raw,&samples);err!=nil {t.Fatal(err)}
 out:=[]any{}
 for _,file:=range []string{"stix.ttf","features.ttf","restricted.ttf"} {
  font,err:=os.ReadFile(filepath.Join(root,"compat/font/fixtures",file));if err!=nil {t.Fatal(err)}
  fsys:=fstest.MapFS{file:&fstest.MapFile{Data:font}}; count:=0
  for i,sample:=range samples {
   s:=codexScoreFromFixture(sample);if len(s.Parts)==0 || len(s.Measures)==0 {continue}
   o:=Options{FontFS:fsys,NoSystemFonts:true,NoWOFF2:true,NoTextIndex:true,NoPlay:true,PageWidth:float64(350+(i%3)*100),PageHeight:float64(500+(i%3)*100),StaffSpace:float64(3+i%4),Title:"Sample Ω"}
   res,err:=Build(s,o);if err!=nil {t.Fatal(err)}
   path:="";for _,part:=range res.Doc.Parts() {if part.Type==bdf.PartPath {path=part.Hash.String()}}
   objects:=[]string{};for _,page:=range res.Doc.Views[0].Pages {objects=append(objects,page.Layers[0].Obj.String())}
   if res.Warnings==nil {res.Warnings=[]string{}}
   out=append(out,map[string]any{"input":sample.Input,"file":file,"width":o.PageWidth,"height":o.PageHeight,"sp":o.StaffSpace,"title":o.Title,"want":[]any{path,objects,res.EmbeddedFonts,res.Warnings}})
   count++;if count==60 {break}
  }
 }
 b,err:=json.Marshal(out);if err!=nil {t.Fatal(err)};var buf bytes.Buffer;z:=gzip.NewWriter(&buf);if _,err=z.Write(b);err!=nil {t.Fatal(err)};if err=z.Close();err!=nil {t.Fatal(err)};if err=os.WriteFile(filepath.Join(root,"compat/musicnotation/render_pages_fonts.json.gz"),buf.Bytes(),0644);err!=nil {t.Fatal(err)}
}
