//go:build ignore

// Copy into upstream converter/internal/music and run TestCodexMusicParams.
package music

import (
 "encoding/json"
 "math/rand"
 "os"
 "path/filepath"
 "testing"
 conv "github.com/shibukawa/bdf/converter"
)
func TestCodexMusicParams(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT");if root=="" {t.Fatal("BDF_FIXTURE_ROOT required")};out:=[]any{}
 values:=[]string{"", "C", "common", " c| ", "alla breve", "3/4", "6 / 8", "0/4", "99/64", "100/4", "4/3", "+2/4", "1/-4", "１/４", " G♭ minor ", "Bb", "F#m", "Am", "CM", "Cmin", "g Major", "-7m", "+7", "8", "-8", "C##", "♭", "\n\t", "\u200b", "true", "False", "1", "0", "yes"}
 r:=rand.New(rand.NewSource(526919));chars:=[]rune("ABCDEFGabcdefg#♯♭bmMinajor0123456789+- /|\n\t")
 for i:=0;i<4000;i++ {n:=r.Intn(12);s:=make([]rune,n);for j:=range s{s[j]=chars[r.Intn(len(chars))]};values=append(values,string(s))}
 for _,v:=range values {
  time,te:=ParseTime(v);key,ke:=ParseKey(v);tab,be:=TabEnabled(&conv.Options{Params:map[string]string{"tab":v}})
  answer:=func(value any,err error)any {if err!=nil {return []any{nil,err.Error()}};return []any{value,""}}
  out=append(out,map[string]any{"input":v,"want":[]any{answer([]any{time.Beats,time.BeatType,time.Symbol},te),answer([]any{key.Fifths,key.Minor},ke),answer(tab,be)}})
 }
 b,err:=json.Marshal(out);if err!=nil {t.Fatal(err)};if err=os.WriteFile(filepath.Join(root,"compat/musicnotation/params.json"),b,0644);err!=nil {t.Fatal(err)}
}
