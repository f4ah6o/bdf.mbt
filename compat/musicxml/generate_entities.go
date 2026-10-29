//go:build ignore

package main
import("encoding/xml";"fmt";"os";"sort")
func main(){f,e:=os.Create(os.Args[1]);if e!=nil{panic(e)};defer f.Close();fmt.Fprintln(f,"// Generated from Go encoding/xml.HTMLEntity; see licenses/Go-x-text.txt.\n\n///|\nlet musicxml_html_entities : Map[String, String] = {");keys:=make([]string,0,len(xml.HTMLEntity));for k:=range xml.HTMLEntity{keys=append(keys,k)};sort.Strings(keys);for _,k:=range keys {fmt.Fprintf(f,"  %q: \"",k);for _,r:=range xml.HTMLEntity[k]{fmt.Fprintf(f,"\\u{%x}",r)};fmt.Fprintln(f,"\",")};fmt.Fprintln(f,"}")}
