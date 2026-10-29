//go:build ignore

// Copy into upstream converter/internal/music and run TestCodexPagination.
package music

import (
 "encoding/json"
 "math/rand"
 "os"
 "path/filepath"
 "testing"
)

// The staff-distance and pagination portion of build in page.go.
func TestCodexPagination(t *testing.T) {
 root := os.Getenv("BDF_FIXTURE_ROOT")
 if root == "" { t.Fatal("BDF_FIXTURE_ROOT required") }
 r := rand.New(rand.NewSource(344725))
 cases := []any{}
 for sample := 0; sample < 3000; sample++ {
  pageH := float64(250+r.Intn(1600))
  sp := float64(20+r.Intn(90))/10
  titleH := float64(r.Intn(180))
  n := 1+r.Intn(30)
  staves := 1+r.Intn(8)
  systems := make([]*system,n)
  raw := []float64{}
  breaks := make([]bool,n)
  part := make([]int,staves)
  for si:=1;si<staves;si++ { part[si]=part[si-1]; if r.Intn(3)==0 {part[si]++} }
  for i:=range systems {
   sys:=&system{staves:make([]*staffLayout,staves),y:make([]float64,staves)}
   breaks[i]=r.Intn(18)==0
   if breaks[i] { raw=append(raw,1) } else { raw=append(raw,0) }
   raw=append(raw,float64(staves))
   for si:=range sys.staves {
    a:=float64(-r.Intn(120))/10
    b:=float64(40+r.Intn(120))/10
    sys.staves[si]=&staffLayout{above:a,below:b}
    raw=append(raw,float64(part[si]),a,b)
   }
   for si:=1;si<len(sys.staves);si++ {
    minGap:=6.5; if part[si]==part[si-1] { minGap=5.5 }
    gap:=max(minGap,sys.staves[si-1].below-4-sys.staves[si].above+1.0)
    sys.y[si]=sys.y[si-1]+4+gap
   }
   sys.above=sys.staves[0].above
   last:=len(sys.staves)-1
   sys.below=sys.y[last]+sys.staves[last].below
   systems[i]=sys
  }
  type pageInfo struct { systems []*system; titleH float64 }
  pages:=[]*pageInfo{{titleH:titleH}}
  cur:=pages[0]; y:=margin+titleH; bottom:=pageH-margin
  for i,sys:=range systems {
   top:=y-sys.above*sp
   if n:=len(cur.systems); n>0 {
    prev:=cur.systems[n-1]
    top=max(top+2.5*sp,prev.top+(prev.y[len(prev.y)-1]+4+8)*sp)
   }
   brk:=i>0 && breaks[i]
   if len(cur.systems)>0 && (top+sys.below*sp>bottom || brk) {
    cur=&pageInfo{}; pages=append(pages,cur); top=margin-sys.above*sp
   }
   sys.top=top; sys.page=len(pages)-1; y=sys.top+sys.below*sp
   cur.systems=append(cur.systems,sys)
  }
  for pi,pg:=range pages {
   if pi==len(pages)-1 || len(pg.systems)<2 {continue}
   last:=pg.systems[len(pg.systems)-1]
   free:=bottom-(last.top+last.below*sp)
   start:=margin+pg.titleH
   used:=last.top+last.below*sp-start
   if used<0.6*(bottom-start) {continue}
   step:=min(free/float64(len(pg.systems)-1),10*sp)
   for k,sys:=range pg.systems {sys.top+=step*float64(k)}
  }
  want:=[]any{}
  for _,sys:=range systems {want=append(want,[]any{sys.y,sys.above,sys.below,sys.top,sys.page})}
  cases=append(cases,map[string]any{"raw":raw,"pageHeight":pageH,"staffSpace":sp,"titleHeight":titleH,"want":want})
 }
 out,err:=json.Marshal(cases); if err!=nil {t.Fatal(err)}
 if err=os.WriteFile(filepath.Join(root,"compat/musicnotation/pagination.json"),out,0644);err!=nil {t.Fatal(err)}
}
