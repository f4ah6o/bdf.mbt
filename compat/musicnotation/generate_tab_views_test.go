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
)
func TestCodexTabViews(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT");if root=="" {t.Fatal("BDF_FIXTURE_ROOT required")};raw,err:=os.ReadFile(filepath.Join(root,"compat/midiinput/score.json"));if err!=nil {t.Fatal(err)};var samples []codexFixture;if err=json.Unmarshal(raw,&samples);err!=nil {t.Fatal(err)};out:=[]any{}
 for i,sample:=range samples {
  s:=codexScoreFromFixture(sample);if len(s.Parts)==0 || len(s.Measures)==0 {continue}
  o:=Options{NoSystemFonts:true,SystemFonts:true,NoTextIndex:true,NoPlay:true,GuitarTAB:true,PageWidth:float64(300+(i%5)*100),PageHeight:float64(450+(i%7)*100),StaffSpace:float64(30+i%27)/10};if i%4==0 {o.Title="A title"}
  res,err:=Build(s,o);if err!=nil {t.Fatal(err)};views:=[]any{}
  for _,view:=range res.Doc.Views[1:] {pages:=[]any{};for _,page:=range view.Pages {pages=append(pages,[]any{page.W,page.H,page.Layers[0].Obj.String()})};views=append(views,[]any{view.ID,view.Title,pages})}
  out=append(out,map[string]any{"input":sample.Input,"width":o.PageWidth,"height":o.PageHeight,"sp":o.StaffSpace,"title":o.Title,"want":views})
 }
 b,err:=json.Marshal(out);if err!=nil {t.Fatal(err)};var buf bytes.Buffer;z:=gzip.NewWriter(&buf);if _,err=z.Write(b);err!=nil {t.Fatal(err)};if err=z.Close();err!=nil {t.Fatal(err)};if err=os.WriteFile(filepath.Join(root,"compat/musicnotation/tab_views.json.gz"),buf.Bytes(),0644);err!=nil {t.Fatal(err)}
}
