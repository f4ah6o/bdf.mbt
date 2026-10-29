//go:build ignore

// Copy into upstream converter/internal/music and run TestCodexTextPainter.
package music

import (
 "bytes"
 "compress/gzip"
 "encoding/json"
 "math/rand"
 "os"
 "path/filepath"
 "testing"
 "testing/fstest"
 "github.com/shibukawa/bdf"
 "github.com/shibukawa/bdf/converter/internal/canvas"
 "github.com/shibukawa/bdf/converter/internal/fontset"
 "github.com/shibukawa/bdf/internal/fontdb"
)
func TestCodexTextPainter(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT");if root=="" {t.Fatal("BDF_FIXTURE_ROOT required")}
 r:=rand.New(rand.NewSource(564720));chars:=[]rune("AbcdXYZ09 .,éΩЖ東京あ한𝄞🕊\n\t\u200b\u00a0")
 out:=[]any{}
 for _,file:=range []string{"", "stix.ttf", "features.ttf", "stix.otf"} {
  var fsys fstest.MapFS;if file!="" {b,err:=os.ReadFile(filepath.Join(root,"compat/font/fixtures",file));if err!=nil {t.Fatal(err)};fsys=fstest.MapFS{file:&fstest.MapFile{Data:b}}}
  for sample:=0;sample<100;sample++ {
   set:=fontset.New(fontdb.New(fsys,nil,false),func(string){});e:=&engraver{text:&texter{set:set}}
   doc:=bdf.NewDocument();lang:=[]string{"","ja-JP","ko","zh-CN"}[r.Intn(4)];if lang!="" {doc.Meta.DC.Language=bdf.DCValues{lang}}
   cvs:=canvas.NewBuilder(doc,set);cv:=cvs.New();cv.Obj.SetBBox(0,0,400,400);w:=&writer{e:e,cv:cv}
   lines:=[]any{}
   for i:=0;i<1+r.Intn(12);i++ {
    charsHere:=make([]rune,r.Intn(25));for j:=range charsHere {charsHere[j]=chars[r.Intn(len(chars))]};s:=string(charsHere)
    size:=float64(10+r.Intn(200))/10;x:=float64(r.Intn(1500)-500)/10;y:=float64(r.Intn(1500)-500)/10;align:=r.Intn(3);bold:=r.Intn(2)==1;italic:=r.Intn(2)==1
    w.text(e.text.line(s,size,bold,italic),x,y,align);lines=append(lines,[]any{s,size,x,y,align,bold,italic})
   }
   cvs.Encode();out=append(out,map[string]any{"file":file,"lang":lang,"lines":lines,"want":doc.Part(cv.Hash()).Data})
  }
 }
 b,err:=json.Marshal(out);if err!=nil {t.Fatal(err)};var buf bytes.Buffer;z:=gzip.NewWriter(&buf);if _,err=z.Write(b);err!=nil {t.Fatal(err)};if err=z.Close();err!=nil {t.Fatal(err)};if err=os.WriteFile(filepath.Join(root,"compat/musicnotation/text_painter.json.gz"),buf.Bytes(),0644);err!=nil {t.Fatal(err)}
}
