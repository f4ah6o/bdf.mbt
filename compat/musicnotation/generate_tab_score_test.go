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
func TestCodexTabScore(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT");if root=="" {t.Fatal("BDF_FIXTURE_ROOT required")};raw,err:=os.ReadFile(filepath.Join(root,"compat/midiinput/score.json"));if err!=nil {t.Fatal(err)};var samples []codexFixture;if err=json.Unmarshal(raw,&samples);err!=nil {t.Fatal(err)}
 out:=[]any{}
 for _,sample:=range samples {
  score:=codexScoreFromFixture(sample);parts:=[]any{}
  for _,part:=range score.Parts {
   ids:=map[*Note]int{};n:=0
   for _,measure:=range part.Measures {for _,event:=range measure.Events {if event.Rest {continue};for _,note:=range event.Notes {ids[note]=n;n++}}}
   onsets:=tabOnsets(score,part);grouped:=[]any{}
   for _,onset:=range onsets {ns:=[]any{};for _,note:=range onset.notes {ns=append(ns,[]int{ids[note.note],note.pitch,note.end})};grouped=append(grouped,[]any{onset.tick,ns})}
   presets:=[]any{}
   for _,preset:=range tabPresets {positions,omitted:=chooseTab(onsets,preset);values:=make([]any,n);for note,pos:=range positions {values[ids[note]]=[]int{pos.String,pos.Fret}};presets=append(presets,[]any{values,omitted})}
   parts=append(parts,[]any{grouped,presets})
  }
  out=append(out,map[string]any{"input":sample.Input,"want":parts})
 }
 b,err:=json.Marshal(out);if err!=nil {t.Fatal(err)};var buf bytes.Buffer;z:=gzip.NewWriter(&buf);if _,err=z.Write(b);err!=nil {t.Fatal(err)};if err=z.Close();err!=nil {t.Fatal(err)};if err=os.WriteFile(filepath.Join(root,"compat/musicnotation/tab_score.json.gz"),buf.Bytes(),0644);err!=nil {t.Fatal(err)}
}
