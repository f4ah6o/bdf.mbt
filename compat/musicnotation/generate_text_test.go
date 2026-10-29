//go:build ignore

// Copy into upstream converter/internal/music and run TestCodexMusicText.
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
 "github.com/shibukawa/bdf/converter/internal/fontset"
 "github.com/shibukawa/bdf/internal/fontdb"
)
func TestCodexMusicText(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT"); if root=="" {t.Fatal("BDF_FIXTURE_ROOT required")}
 r:=rand.New(rand.NewSource(839744)); chars:=[]rune("AbcdXYZ09 .,;éΩαЖ東京あ한𝄞🕊\n\t\u200b\u00a0")
 files:=[]string{"", "stix.ttf", "features.ttf", "stix.otf"}; cases:=[]any{}
 for _,file:=range files {
  var fsys fstest.MapFS
  if file!="" { b,err:=os.ReadFile(filepath.Join(root,"compat/font/fixtures",file));if err!=nil {t.Fatal(err)};fsys=fstest.MapFS{file:&fstest.MapFile{Data:b}} }
  tex:=&texter{set:fontset.New(fontdb.New(fsys,nil,false),func(string){})}
  for i:=0;i<500;i++ {
   s:=make([]rune,r.Intn(28)); for j:=range s {s[j]=chars[r.Intn(len(chars))]}; str:=string(s)
   size:=float64(10+r.Intn(400))/10; bold:=r.Intn(2)==1;italic:=r.Intn(2)==1
   line:=tex.line(str,size,bold,italic); runs:=[]any{}
   for _,run:=range line.runs { face:="";if run.fc.Use.Face!=nil {face=run.fc.Use.Face.Path};u:=run.fc.Use;runs=append(runs,[]any{face,u.Requested,u.Generic,u.Bold,u.Italic,u.SynthBold,u.SynthItalic,run.s,run.cjk,run.x,run.w}) }
   cases=append(cases,map[string]any{"file":file,"text":str,"size":size,"bold":bold,"italic":italic,"want":[]any{line.width,line.asc,line.desc,runs}})
  }
 }
 b,err:=json.Marshal(cases);if err!=nil {t.Fatal(err)};var buf bytes.Buffer;z:=gzip.NewWriter(&buf);if _,err=z.Write(b);err!=nil {t.Fatal(err)};if err=z.Close();err!=nil {t.Fatal(err)};if err=os.WriteFile(filepath.Join(root,"compat/musicnotation/text.json.gz"),buf.Bytes(),0644);err!=nil {t.Fatal(err)}
}
