//go:build ignore

// Copy into upstream converter/midi and run TestCodexMidiOptions.
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
func TestCodexMidiOptions(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT");if root=="" {t.Fatal("BDF_FIXTURE_ROOT required")};raw,err:=os.ReadFile(filepath.Join(root,"compat/midiinput/score.json"));if err!=nil {t.Fatal(err)};var samples []struct{Input []byte `json:"input"`};if err=json.Unmarshal(raw,&samples);err!=nil {t.Fatal(err)};out:=[]any{}
 for i,s:=range samples {
  if i%4!=0 {continue};p,err:=Parse(s.Input,nil);if err!=nil {t.Fatal(err)}
  time:=[]string{"", "3/4", "6/8", "C", "cut"}[i%5];key:=[]string{"", "G", "Bb", "F#m", "-3"}[(i/4)%5];pages:=[]string{"", "1-", "2-4", "99999", "2,1,2", "-2"}[(i/4)%6];tab:=i%8==0
  params:=&conv.Options{Params:map[string]string{"time":time,"key":key}};no,err:=music.NotateParams(params);if err!=nil {t.Fatal(err)}
  score:=music.Notate(p.Perf,no);score.SMF=p.SMF;selected,err:=conv.ParsePages(pages);if err!=nil {t.Fatal(err)}
  opts:=music.Options{Source:"midi",Pages:selected,NoSystemFonts:true,SystemFonts:true,GuitarTAB:tab,PageWidth:400,PageHeight:450,StaffSpace:4}
  res,err:=music.Build(score,opts);if err!=nil {continue};parts:=[]any{};for _,part:=range res.Doc.Parts(){parts=append(parts,[]any{part.Type,part.Hash.String()})};warnings:=append(p.Warnings,res.Warnings...);if warnings==nil {warnings=[]string{}}
  out=append(out,map[string]any{"input":s.Input,"time":time,"key":key,"pages":pages,"tab":tab,"want":map[string]any{"meta":res.Doc.Meta,"views":res.Doc.Views,"parts":parts,"warnings":warnings,"counts":[]int{res.Pages,res.Systems,res.Measures,res.Parts,res.Staves,res.Notes,res.EmbeddedFonts}}})
  if len(out)>=120 {break}
 }
 b,err:=json.Marshal(out);if err!=nil {t.Fatal(err)};var buf bytes.Buffer;z:=gzip.NewWriter(&buf);if _,err=z.Write(b);err!=nil {t.Fatal(err)};if err=z.Close();err!=nil {t.Fatal(err)};if err=os.WriteFile(filepath.Join(root,"compat/midiinput/options.json.gz"),buf.Bytes(),0644);err!=nil {t.Fatal(err)}
}
