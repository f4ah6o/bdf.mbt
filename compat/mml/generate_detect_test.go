//go:build ignore

// Copy into upstream converter/mml and run TestCodexMMLDetect.
package mml

import (
 "encoding/json"
 "math/rand"
 "os"
 "path/filepath"
 "testing"
)
func TestCodexMMLDetect(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT");if root=="" {t.Fatal("BDF_FIXTURE_ROOT required")};r:=rand.New(rand.NewSource(526233))
 samples:=[]string{"", "MML@c4,d4;", "MML@cdef;", "a@MML@c4;", "#TITLE song\nc4d4e4", "#ARTIST X\nc8d8e8", "A t120 o4 c8d8\nB o4 e8f8", "#OCTAVE-REV\nA c4\nB d4", "```\n#TITLE x\nc4d4e4\n```", "\ufeffMML@c4;", "MML@c4\x00;", "@v0 = {1,2}\nA c4", "#title song\nc4d4e4", "#TITLE x\rA c4\rB d4", "#TITLE x\r\nA c4\r\nB d4"}
 fragments:=[]string{"#TITLE test", "#ARTIST x", "#COMPOSER x", "#WAV9 0", "#EX-FOO 1", "MML@c4,e4;", "aMML@c4;", "A t120 c4d4", "B l8 cdef", "c8 d8 e8", "@v2 = {2}", ";comment", "//comment", "  A c4", "~~~", "", "日本語", "email@x.y", "$X=c8;", "C4R4", "f#m", "\x00"}
 for i:=0;i<7000;i++ {s:="";for j:=0;j<1+r.Intn(5);j++ {if j>0 {s+="\n"};s+=fragments[r.Intn(len(fragments))]};samples=append(samples,s)}
 chars:=[]rune("abcdefgrlotvnq@ABCDEFGRLOTVNQ0123456789 <>[]{}&^.+-#|:/%,@;$=()_!xyz日本語\t")
 for i:=0;i<3000;i++ {s:=make([]rune,r.Intn(35));for j:=range s {s[j]=chars[r.Intn(len(chars))]};samples=append(samples,string(s))}
 out:=[]any{};for _,s:=range samples {ok,tokens,notes:=mmlLike(s);out=append(out,map[string]any{"input":s,"want":[]any{Detect([]byte(s),nil,0),detectDialect(s),ok,tokens,notes}})}
 b,err:=json.Marshal(out);if err!=nil {t.Fatal(err)};if err=os.WriteFile(filepath.Join(root,"compat/mml/detect.json"),b,0644);err!=nil {t.Fatal(err)}
}
