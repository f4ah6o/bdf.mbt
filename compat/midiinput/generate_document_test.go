//go:build ignore

// Copy into upstream converter/midi and run TestCodexMidiDocument.
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
func TestCodexMidiDocument(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT");if root=="" {t.Fatal("BDF_FIXTURE_ROOT required")}
 raw,err:=os.ReadFile(filepath.Join(root,"compat/midiinput/score.json"));if err!=nil {t.Fatal(err)};var samples []struct{Input []byte `json:"input"`};if err=json.Unmarshal(raw,&samples);err!=nil {t.Fatal(err)}
 out:=[]any{}
 for i,s:=range samples {
  p,err:=Parse(s.Input,nil);if err!=nil {t.Fatal(err)};score:=music.Notate(p.Perf,music.NotateOptions{});score.SMF=p.SMF
  o:=music.Options{Source:"midi",NoSystemFonts:true,SystemFonts:true,NoTextIndex:i%5==0,NoPlay:i%7==0,PageWidth:float64(300+(i%5)*100),PageHeight:float64(450+(i%7)*100),StaffSpace:float64(3+i%4)}
  if i%4==0 {o.Title="A title"};if i%11==0 {o.Pages=conv.PageList(1,3,2,99)}
  res,err:=music.Build(score,o);if err!=nil {continue}
  parts:=[]any{};for _,part:=range res.Doc.Parts(){parts=append(parts,[]any{part.Type,part.Hash.String()})}
  warnings:=append(p.Warnings,res.Warnings...);if warnings==nil {warnings=[]string{}}
  out=append(out,map[string]any{"input":s.Input,"width":o.PageWidth,"height":o.PageHeight,"sp":o.StaffSpace,"title":o.Title,"noText":o.NoTextIndex,"noPlay":o.NoPlay,"select":o.Pages!=nil,"want":map[string]any{"meta":res.Doc.Meta,"views":res.Doc.Views,"parts":parts,"warnings":warnings,"counts":[]int{res.Pages,res.Systems,res.Measures,res.Parts,res.Staves,res.Notes,res.EmbeddedFonts}}})
 }
 b,err:=json.Marshal(out);if err!=nil {t.Fatal(err)};var buf bytes.Buffer;z:=gzip.NewWriter(&buf);if _,err=z.Write(b);err!=nil {t.Fatal(err)};if err=z.Close();err!=nil {t.Fatal(err)};if err=os.WriteFile(filepath.Join(root,"compat/midiinput/document.json.gz"),buf.Bytes(),0644);err!=nil {t.Fatal(err)}
}
