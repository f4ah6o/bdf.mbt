//go:build ignore

// Copy into upstream converter/internal/music and run TestCodexPainter.
package music

import (
 "bytes"
 "compress/gzip"
 "encoding/json"
 "math/rand"
 "os"
 "path/filepath"
 "testing"
 "github.com/shibukawa/bdf"
 "github.com/shibukawa/bdf/converter/internal/canvas"
)
func TestCodexPainter(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT"); if root=="" {t.Fatal("BDF_FIXTURE_ROOT required")}
 r:=rand.New(rand.NewSource(297127)); out:=[]any{}; names:=[]string{"gClef","noteheadBlack","accidentalSharp","restQuarter","brace"}
 for sample:=0;sample<700;sample++ {
  sp:=float64(20+r.Intn(80))/10; ox:=float64(r.Intn(1000)-500)/10; oy:=float64(r.Intn(1000)-500)/10
  d:=newDrawing(); ops:=[]float64{}
  for j:=0;j<1+r.Intn(30);j++ {
   v:=make([]float64,9); v[0]=float64(r.Intn(6)); for k:=1;k<len(v);k++ {v[k]=float64(r.Intn(400)-200)/10}
   switch int(v[0]) {
   case 0: v[1]=float64(r.Intn(len(names))); v[4]=float64(1+r.Intn(30))/10; d.glyph(sym(names[int(v[1])]),v[2],v[3],v[4])
   case 1: d.rect(v[1],v[2],v[3],v[4])
   case 2: d.fill(quad(v[1],v[2],v[3],v[4],v[5],v[6],v[7],v[8]))
   case 3: v[5]=float64(1+r.Intn(20))/10; if r.Intn(2)==0 {v[6]=0} else {v[6]=0.5}; d.line(v[1],v[2],v[3],v[4],v[5],v[6])
   case 4: v[1]=float64(r.Intn(6));d.markText(byte(v[1]),"mark")
   case 5: v[1]=float64(r.Intn(len(names)));v[4]=float64(1+r.Intn(30))/10;v[5]=float64(1+r.Intn(30))/10;d.prims=append(d.prims,prim{kind:primGlyph,g:sym(names[int(v[1])]),x:v[2],y:v[3],scale:1,sx:v[4],sy:v[5]})
   }; ops=append(ops,v...)
  }
  e:=&engraver{sp:sp}; gs:=&glyphSet{index:map[glyphKey]int{}}
  for _,p:=range d.prims {if p.kind!=primGlyph {continue}; key:=glyphKey{p.g.name,p.scale*p.sx*sp,p.scale*p.sy*sp};if _,ok:=gs.index[key];ok {continue};gs.index[key]=len(gs.paths);gs.paths=append(gs.paths,p.g.outline.pathXY(key.sx,key.sy))}
  pathBytes:=bdf.EncodePathCollection(gs.paths);doc:=bdf.NewDocument(); ext:=doc.AddPaths(gs.paths)
  cv:=canvas.NewBuilder(doc,nil).New();cv.Obj.SetBBox(0,0,400,400)
  w:=&writer{e:e,cv:cv,glyphs:gs,ext:ext,refs:map[int]bdf.PathRef{}};w.draw(d.prims,ox,oy)
  out=append(out,map[string]any{"ops":ops,"sp":sp,"ox":ox,"oy":oy,"paths":pathBytes,"object":cv.Obj.Encode()})
 }
 b,err:=json.Marshal(out);if err!=nil {t.Fatal(err)};var buf bytes.Buffer;z:=gzip.NewWriter(&buf);if _,err=z.Write(b);err!=nil {t.Fatal(err)};if err=z.Close();err!=nil {t.Fatal(err)};if err=os.WriteFile(filepath.Join(root,"compat/musicnotation/painter.json.gz"),buf.Bytes(),0644);err!=nil {t.Fatal(err)}
}
