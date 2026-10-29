//go:build ignore

// Copy into upstream converter/xlsx and run TestCodexXLSXGeneral.
package xlsx
import("encoding/json";"fmt";"math";"math/rand";"os";"path/filepath";"testing";"strconv";"strings")
func TestCodexXLSXGeneral(t *testing.T){root:=os.Getenv("BDF_FIXTURE_ROOT");if root==""{t.Fatal("BDF_FIXTURE_ROOT required")};values:=[]float64{0,math.Copysign(0,-1),math.Inf(1),math.Inf(-1),math.NaN(),math.SmallestNonzeroFloat64,math.MaxFloat64,1e15,999999999999999.5,1.2345678901234567,1e-9,1e-10,9.9999999999995,1e11,-123456789.12345};r:=rand.New(rand.NewSource(242012));for i:=0;i<20000;i++{values=append(values,math.Float64frombits(r.Uint64()))};out:=[]any{};for i,v:=range values{n:=1+r.Intn(20);if generalTerminates(v,n,0){out=append(out,map[string]any{"bits":fmt.Sprintf("%016x",math.Float64bits(v)),"width":n,"want":formatGeneral(v,n),"index":i})}};b,e:=json.Marshal(out);if e!=nil{t.Fatal(e)};if e=os.WriteFile(filepath.Join(root,"compat/xlsx/general.json"),b,0644);e!=nil{t.Fatal(e)}}

// Avoid crashing the oracle on upstream values which recurse indefinitely.
func generalTerminates(v float64, width, depth int) bool {
 if depth > 8 { return false }; if v == 0 || math.IsNaN(v) || math.IsInf(v,0) { return true }; sign:=1.0; if v<0 { sign=-1;v=-v }; v=round15(v); exp:=int(math.Floor(math.Log10(v))); if v>=math.Pow(10,float64(exp+1)){exp++}else if v<math.Pow(10,float64(exp)){exp--}; if exp<11 && exp>= -9 { digits:=max(exp+1,1); if digits<=width { dec:=max(width-digits-1,0); text:=strconv.FormatFloat(v,'f',min(dec,30),64); if strings.Contains(text,"."){text=strings.TrimRight(strings.TrimRight(text,"0"),".")}; if text!="0" && len(text)<=width{return true} } }; n:=exp;if n<0{n= -n};room:=width-len("E+")+0-len(pad2(n));if room<1{return true};m:=v/math.Pow(10,float64(exp));ms:=strconv.FormatFloat(m,'f',max(room-2,0),64);if strings.HasPrefix(ms,"10"){return generalTerminates(sign*math.Pow(10,float64(exp+1)),width,depth+1)};return true
}
