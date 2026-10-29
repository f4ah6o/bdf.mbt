//go:build ignore

// Copy into upstream converter/internal/music and run TestCodexBarlines.
package music

import (
 "encoding/json"
 "math/rand"
 "os"
 "path/filepath"
 "testing"
)
func TestCodexBarlines(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT"); if root=="" {t.Fatal("BDF_FIXTURE_ROOT required")}
 r:=rand.New(rand.NewSource(485768)); out:=[]any{}
 e:=&engraver{def:fontDefaults()}
 for kind:=0;kind<9;kind++ { for side:=0;side<2;side++ { for i:=0;i<200;i++ {
  x:=float64(r.Intn(1000)-500)/10; top:=float64(r.Intn(100)-50)/10
  tops:=[]float64{top}; for j:=0;j<r.Intn(5);j++ {tops=append(tops,tops[len(tops)-1]+float64(60+r.Intn(150))/10)}
  bottom:=tops[len(tops)-1]+4
  c:=newDrawing(); e.barline(c,Barline(kind),x,top,bottom,tops,side==1)
  prims:=[]any{}; for _,p:=range c.prims {name:=""; if p.g!=nil {name=p.g.name}; prims=append(prims,[]any{int(p.kind),name,p.x,p.y,p.w,p.h,p.scale,p.width,p.dash})}
  out=append(out,map[string]any{"kind":kind,"x":x,"top":top,"bottom":bottom,"tops":tops,"left":side==1,"want":prims})
 } } }
 b,err:=json.Marshal(out); if err!=nil {t.Fatal(err)}
 if err=os.WriteFile(filepath.Join(root,"compat/musicnotation/barlines.json"),b,0644);err!=nil {t.Fatal(err)}
}
