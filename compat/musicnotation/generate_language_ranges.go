//go:build ignore

// Generate convert/music/text_language_generated.mbt using Go Unicode tables.
package main
import("fmt";"unicode")
func main(){fmt.Println("///|\n// Unicode script ranges from Go's standard library (see licenses/Go-x-text.txt).\nlet music_language_ranges : Array[(Int32, Int32, Int32, String)] = [");for _,x:=range []struct{t *unicode.RangeTable;lang string}{{unicode.Hiragana,"ja"},{unicode.Katakana,"ja"},{unicode.Hangul,"ko"}}{for _,r:=range x.t.R16{fmt.Printf("  (0x%x, 0x%x, %d, %q),\n",r.Lo,r.Hi,r.Stride,x.lang)};for _,r:=range x.t.R32{fmt.Printf("  (0x%x, 0x%x, %d, %q),\n",r.Lo,r.Hi,r.Stride,x.lang)}};fmt.Println("]")}
