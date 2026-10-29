//go:build ignore

// Copy into upstream converter/internal/music and run TestCodexSpanning.
package music

import (
 "bytes"
 "compress/gzip"
 "encoding/json"
 "math/rand"
 "os"
 "path/filepath"
 "testing"
 "github.com/shibukawa/bdf/converter/internal/fontset"
 "github.com/shibukawa/bdf/internal/fontdb"
)
func TestCodexSpanning(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT"); if root=="" {t.Fatal("BDF_FIXTURE_ROOT required")}
 r:=rand.New(rand.NewSource(193181)); cases:=[]any{}
 for sample:=0;sample<1500;sample++ {
  sp:=defaultSp
  score:=&Score{}; first:=r.Intn(2); partCount:=1+r.Intn(5)
  partRaw:=[]float64{}; names:=[]string{}; metrics:=[]float64{}
  e:=&engraver{s:score,sp:sp,def:fontDefaults(),text:&texter{set:fontset.New(fontdb.New(nil,nil,false),func(string){})}}
  sys:=&system{first:first}; y:=0.0
  for pi:=0;pi<partCount;pi++ {
   n:=1+r.Intn(3); name:=[]string{"Piano","Violin","Flute","","Bass"}[r.Intn(5)]; abbr:=[]string{"Pno.","Vln.","Fl.",""}[r.Intn(4)]
   p:=&Part{Name:name,Abbrev:abbr,Staves:n}; score.Parts=append(score.Parts,p)
   names=append(names,name,abbr); partRaw=append(partRaw,float64(n))
   for j:=0;j<n;j++ { if pi>0||j>0 {y+=float64(75+r.Intn(100))/10}; sys.y=append(sys.y,y); partRaw=append(partRaw,y); e.staves=append(e.staves,staffRef{pi,j}) }
   if n>1 {e.grand=true}
   label:=abbr; if first==0 {label=name}; v:=e.text.line(label,2.2*sp,false,false); metrics=append(metrics,v.width/sp,v.asc/sp,v.desc/sp)
  }
  count:=1+r.Intn(5); sys.last=first+count-1; e.cols=make([]*column,first+count); score.Measures=make([]*Measure,first+count)
  bars:=[]float64{}; x:=0.0
  for i:=0;i<first+count;i++ {
   m:=&Measure{}; col:=&column{}; if i>=first { col.x=x; col.width=float64(80+r.Intn(150))/10; x+=col.width; m.Left=Barline(r.Intn(9)); m.Right=Barline(r.Intn(9)); bars=append(bars,col.x,col.width,float64(m.Left),float64(m.Right)) }; score.Measures[i]=m; e.cols[i]=col
  }
  prims:=[]any{}; for _,p:=range e.systemPrims(sys) { name:=""; if p.g!=nil {name=p.g.name}; text:=""; if p.text!=nil {for _,run:=range p.text.runs {text+=run.s}}; prims=append(prims,[]any{int(p.kind),name,p.x,p.y,p.w,p.h,p.scale,p.sx,p.sy,p.width,p.dash,text,p.align,int(p.mark),p.alt}) }
  cases=append(cases,map[string]any{"parts":partRaw,"names":names,"metrics":metrics,"bars":bars,"first":first==0,"want":prims})
 }
 b,err:=json.Marshal(cases); if err!=nil {t.Fatal(err)}; var buf bytes.Buffer; z:=gzip.NewWriter(&buf); if _,err=z.Write(b);err!=nil {t.Fatal(err)}; if err=z.Close();err!=nil {t.Fatal(err)}; if err=os.WriteFile(filepath.Join(root,"compat/musicnotation/spanning.json.gz"),buf.Bytes(),0644);err!=nil {t.Fatal(err)}
}
