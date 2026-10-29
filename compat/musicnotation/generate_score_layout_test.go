//go:build ignore

// Copy alongside generate_prepare_test.go into upstream converter/internal/music.
// Insert codexLayoutHook(e, systems, pageW, pageH, titleH, title) immediately
// before the "the document" comment in page.go for this test, then restore it.
package music

import (
 "bytes"
 "compress/gzip"
 "encoding/json"
 "os"
 "path/filepath"
 "strconv"
 "testing"
)
var codexLayoutHook func(*engraver, []*system, float64, float64, float64, string)
func TestCodexScoreLayout(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT"); if root=="" {t.Fatal("BDF_FIXTURE_ROOT required")}
 raw,err:=os.ReadFile(filepath.Join(root,"compat/midiinput/score.json")); if err!=nil {t.Fatal(err)}
 var samples []codexFixture; if err=json.Unmarshal(raw,&samples);err!=nil {t.Fatal(err)}
 out:=[]any{}
 for i,sample:=range samples {
  score:=codexScoreFromFixture(sample)
  if len(score.Parts)==0 || len(score.Measures)==0 {continue}
  opts:=&Options{NoSystemFonts:true, PageWidth:float64(300+(i%5)*100),PageHeight:float64(450+(i%7)*100),StaffSpace:float64(3+(i%4))}
  if i%4==0 {opts.Title="A title"}
  var got any; metrics:=map[string][3]float64{}
  codexLayoutHook=func(e *engraver, systems []*system, pageW,pageH,titleH float64,title string) {
   measure:=func(text string,size float64,italic bool) { key:="n|"; if italic {key="i|"}; key+=strconv.FormatFloat(size,'f',1,64)+"|"+text; line:=e.text.line(text,size*e.sp,false,italic); metrics[key]=[3]float64{line.width/e.sp,line.asc/e.sp,line.desc/e.sp} }
   for _,p:=range score.Parts {measure(p.Name,2.2,false); for _,m:=range p.Measures {for _,v:=range m.Events {for _,l:=range v.Lyrics {measure(l.Text,2.2,false)}}}}
   result:=[]any{}
   for _,sys:=range systems {
    if sys.first>0 {measure(strconv.Itoa(e.counts[sys.first]),1.6,true)}
    for mi:=sys.first;mi<=sys.last;mi++ {for _,tempo:=range score.Measures[mi].Tempo {measure(" = "+strconv.FormatFloat(tempo.PerMinute,'f',-1,64),2.4,false)}}
    extents:=[][2]float64{}; for _,staff:=range sys.staves {extents=append(extents,[2]float64{staff.above,staff.below})}
    result=append(result,[]any{sys.first,sys.last,sys.header,sys.width,sys.left,sys.y,sys.above,sys.below,sys.top,sys.page,extents})
   }
   got=[]any{pageW,pageH,e.sp,title,titleH,result}; panic("codex layout captured")
  }
  func() {defer func(){ if v:=recover(); v!=nil && v!="codex layout captured" {panic(v)} }(); _,err:=build(score,opts); if err!=nil {t.Fatal(err)} }()
  if got==nil {t.Fatalf("layout missing for sample %d",i)}
  out=append(out,map[string]any{"input":sample.Input,"width":opts.PageWidth,"height":opts.PageHeight,"staffSpace":opts.StaffSpace,"title":opts.Title,"metrics":metrics,"want":got})
 }
 b,err:=json.Marshal(out);if err!=nil {t.Fatal(err)};var buf bytes.Buffer;z:=gzip.NewWriter(&buf);if _,err=z.Write(b);err!=nil {t.Fatal(err)};if err=z.Close();err!=nil {t.Fatal(err)};if err=os.WriteFile(filepath.Join(root,"compat/musicnotation/score_layout.json.gz"),buf.Bytes(),0644);err!=nil {t.Fatal(err)}
}
