//go:build ignore

// Copy into upstream converter/internal/music and run TestCodexTabFingering.
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
func TestCodexTabFingering(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT");if root=="" {t.Fatal("BDF_FIXTURE_ROOT required")};r:=rand.New(rand.NewSource(757220));out:=[]any{}
 for i:=0;i<2000;i++ {
  var onsets []tabOnset;var notes []*Note;raw:=[]int{};tick:=0
  for j:=0;j<1+r.Intn(12);j++ {
   tick+=r.Intn(5)*120;count:=r.Intn(5);raw=append(raw,tick,count);onset:=tabOnset{tick:tick}
   for k:=0;k<count;k++ {
    pitch:=32+r.Intn(67);end:=tick+1+r.Intn(8)*120;note:=&Note{};has,str,fret:=0,0,0
    if r.Intn(5)==0 {has=1;str=1+r.Intn(7);fret=r.Intn(29)-2;note.Tab=&TabPosition{String:str,Fret:fret}}
    notes=append(notes,note);onset.notes=append(onset.notes,tabInput{note:note,pitch:pitch,end:end});raw=append(raw,pitch,end,has,str,fret)
   };onsets=append(onsets,onset)
  }
  preset:=r.Intn(len(tabPresets));positions,omitted:=chooseTab(onsets,tabPresets[preset]);want:=[]any{}
  for id,note:=range notes {if p,ok:=positions[note];ok {want=append(want,[]int{id,p.String,p.Fret})}}
  out=append(out,map[string]any{"raw":raw,"preset":preset,"want":[]any{want,omitted}})
 }
 b,err:=json.Marshal(out);if err!=nil {t.Fatal(err)};var buf bytes.Buffer;z:=gzip.NewWriter(&buf);if _,err=z.Write(b);err!=nil {t.Fatal(err)};if err=z.Close();err!=nil {t.Fatal(err)};if err=os.WriteFile(filepath.Join(root,"compat/musicnotation/tab_fingering.json.gz"),buf.Bytes(),0644);err!=nil {t.Fatal(err)}
}
