//go:build ignore

// Copy into upstream converter/internal/music and run TestCodexTabShapes.
package music

import (
 "bytes"
 "compress/gzip"
 "encoding/json"
 "math/rand"
 "os"
 "path/filepath"
 "testing"
)
func TestCodexTabShapes(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT");if root=="" {t.Fatal("BDF_FIXTURE_ROOT required")}
 r:=rand.New(rand.NewSource(107776));out:=[]any{}
 for i:=0;i<4000;i++ {
  var notes []tabInput;raw:=[]int{}
  for j:=0;j<r.Intn(8);j++ {
   pitch:=35+r.Intn(60); pos:=&Note{};str,fret:=0,0
   if r.Intn(4)==0 {str=r.Intn(10);fret=r.Intn(32)-3;pos.Tab=&TabPosition{String:str,Fret:fret}}
   notes=append(notes,tabInput{note:pos,pitch:pitch,end:123});has:=0;if pos.Tab!=nil {has=1};raw=append(raw,pitch,has,str,fret)
  }
  preset:=r.Intn(len(tabPresets));relaxed:=r.Intn(2)==1
  candidates:=[]any{};for _,n:=range notes {cs:=[]any{};for _,c:=range tabCandidates(n,relaxed){cs=append(cs,[]any{c.pos.String,c.pos.Fret,c.penalty})};candidates=append(candidates,cs)}
  shapes:=[]any{};for _,s:=range tabShapes(notes,tabPresets[preset],relaxed){ps:=[]any{};for _,p:=range s.positions {ps=append(ps,[]int{p.String,p.Fret})};shapes=append(shapes,[]any{ps,s.cost,s.base})}
  out=append(out,map[string]any{"notes":raw,"preset":preset,"relaxed":relaxed,"want":[]any{candidates,shapes}})
 }
 b,err:=json.Marshal(out);if err!=nil {t.Fatal(err)};var buf bytes.Buffer;z:=gzip.NewWriter(&buf);if _,err=z.Write(b);err!=nil {t.Fatal(err)};if err=z.Close();err!=nil {t.Fatal(err)};if err=os.WriteFile(filepath.Join(root,"compat/musicnotation/tab_shapes.json.gz"),buf.Bytes(),0644);err!=nil {t.Fatal(err)}
}
