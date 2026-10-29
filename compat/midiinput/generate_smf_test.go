//go:build ignore

// Copy into upstream converter/midi and run TestCodexGeneratedSMF.
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
func TestCodexGeneratedSMF(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT");if root=="" {t.Fatal("BDF_FIXTURE_ROOT required")}
 raw,err:=os.ReadFile(filepath.Join(root,"compat/midiinput/score.json"));if err!=nil {t.Fatal(err)}
 var samples []struct{Input []byte `json:"input"`};if err=json.Unmarshal(raw,&samples);err!=nil {t.Fatal(err)}
 out:=[]any{};for _,s:=range samples {p,err:=Parse(s.Input,nil);if err!=nil {t.Fatal(err)};out=append(out,map[string]any{"input":s.Input,"want":p.Perf.SMF()})}
 for i:=0;i<20;i++ {
  tick:=268435455+i*100000
  perf:=&music.Performance{Title:"Long wait", End:tick+960, Tempo:[]music.Tempo{{Tick:0,BPM:120}},Tracks:[]*music.Track{{Name:"Track",Channel:i%16,Program:7,Volume:80,Pan:64,Notes:[]music.PlayNote{{Tick:0,Dur:960,Key:60,Vel:90},{Tick:tick,Dur:960,Key:62,Vel:85}},Controls:[]music.Control{{Tick:tick,Kind:music.ControlPitchBend,Value:-100}},Lyrics:[]music.Lyric{{Tick:tick,Text:"la"}}}}}
  input:=perf.SMF();p,err:=Parse(input,nil);if err!=nil {t.Fatal(err)};out=append(out,map[string]any{"input":input,"want":p.Perf.SMF()})
 }
 b,err:=json.Marshal(out);if err!=nil {t.Fatal(err)};var buf bytes.Buffer;z:=gzip.NewWriter(&buf);if _,err=z.Write(b);err!=nil {t.Fatal(err)};if err=z.Close();err!=nil {t.Fatal(err)};if err=os.WriteFile(filepath.Join(root,"compat/midiinput/smf.json.gz"),buf.Bytes(),0644);err!=nil {t.Fatal(err)}
}
