//go:build ignore

// Copy into upstream converter/internal/music and run TestCodexMusicTextFonts.
package music

import (
 "encoding/json"
 "os"
 "path/filepath"
 "testing"
 "testing/fstest"
 "github.com/shibukawa/bdf"
 "github.com/shibukawa/bdf/converter/internal/fontset"
 "github.com/shibukawa/bdf/internal/fontdb"
)
func TestCodexMusicTextFonts(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT");if root=="" {t.Fatal("BDF_FIXTURE_ROOT required")};out:=[]any{}
 for _,file:=range []string{"", "stix.ttf", "features.ttf", "stix.otf", "restricted.ttf"} {
  var fsys fstest.MapFS;if file!="" {b,err:=os.ReadFile(filepath.Join(root,"compat/font/fixtures",file));if err!=nil {t.Fatal(err)};fsys=fstest.MapFS{file:&fstest.MapFile{Data:b}}}
  for flags:=0;flags<4;flags++ {
   warnings:=[]string{};set:=fontset.New(fontdb.New(fsys,nil,false),func(s string){warnings=append(warnings,s)});tex:=&texter{set:set}
   texts:=[]string{"A song", "♩= 100", "Hello 世界", "Ω𝄞", ""}; var uses []fontset.Use
   for i,s:=range texts {line:=tex.line(s,12,float64(i)==1,i%2==0);for _,run:=range line.runs {uses=append(uses,run.fc.Use)}}
   doc:=bdf.NewDocument();set.Embed(doc,fontset.EmbedOptions{NoWOFF2:true,NoSubset:flags&1!=0,IgnoreFSType:flags&2!=0})
   records:=[]any{};for _,u:=range uses {f:=set.Font(u);hash:="";if f.Kind==bdf.FontEmbedded {hash=f.Hash.String()};records=append(records,[]any{hash,f.Family,f.Weight,f.Style})}
   hashes:=[]string{};for _,p:=range doc.Parts(){hashes=append(hashes,p.Hash.String())}
   out=append(out,map[string]any{"file":file,"flags":flags,"want":[]any{hashes,warnings,records}})
  }
 }
 b,err:=json.Marshal(out);if err!=nil {t.Fatal(err)};if err=os.WriteFile(filepath.Join(root,"compat/musicnotation/text_fonts.json"),b,0644);err!=nil {t.Fatal(err)}
}
