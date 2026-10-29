//go:build ignore

// Copy into upstream converter/mml and run TestCodexMMLSource.
package mml

import (
 "encoding/json"
 "math/rand"
 "os"
 "path/filepath"
 "testing"
)
func TestCodexMMLSource(t *testing.T) {
 root:=os.Getenv("BDF_FIXTURE_ROOT"); if root=="" { t.Fatal("BDF_FIXTURE_ROOT required") }
 samples:=[]string{"", "MML@c4,d4,e4;", "MML@c4; MML@d4,e4;", "#TITLE \"Music\"\n#ARTIST Composer\ncdef;", "$a=cdef;$ab=$a g;$ab $unknown;", "#INCLUDE foo\n#INCLUDE bar\nA c4; hi\nB d4", "@v1 = {\n 1 2\n}\nAB cdef\n  gfed", "a/*x\ny*/b\n#TITLE //x\nfoo://bar\n:/x/:"}
 fragments:=[]string{"#TITLE test", "#ARTIST x", "#COMPOSER \"日本 語\"", "#INCLUDE file.mml", "#OCTAVE-REV 0", "#OPM@0 {", "#TITLE\tx\ty", "@v2 = {2}", "@v3", "{", "}", "A t120 c4d4", "ABC l8 cdef", "A", "B\td8e8", "  gfed", "c8 d8 e8", "MML@c4,e4;", "//comment", "/*comment*/", "/*multiline\ncomment*/", ";comment", "://:", "$X=c8;", "$X{a}=c;", "$Xabc;", "foo://bar", "", "日本語", "$=;", "  #TITLE a//b", "#$@\t{", "a"}
 r:=rand.New(rand.NewSource(626200));for i:=0;i<9000;i++ {s:="";for j:=0;j<1+r.Intn(8);j++ {if j>0 {s+="\n"};s+=fragments[r.Intn(len(fragments))]};samples=append(samples,s)}
 out:=[]any{};for _,text:=range samples {for _,dialect:=range []string{"generic","mabinogi","ppmck"} {w:=&warner{};var s *source;switch dialect {case "mabinogi":s=splitMabinogi(text);case "ppmck":s=splitPPMCK(text,w);default:s=splitGeneric(text,w)};tracks:=[]any{};for _,tr:=range s.tracks {tracks=append(tracks,[]any{tr.name,string(tr.mml),int(tr.kind)})};warnings:=[]string{};warnings=append(warnings,w.msgs...);out=append(out,map[string]any{"input":text,"dialect":dialect,"want":[]any{s.title,s.composer,s.arranger,s.lyricist,s.copyright,s.reverse,tracks,warnings,stripComments(text,false),stripComments(text,true)}})}}
 b,err:=json.Marshal(out);if err!=nil {t.Fatal(err)};if err=os.WriteFile(filepath.Join(root,"compat/mml/source.json"),b,0644);err!=nil {t.Fatal(err)}
}
