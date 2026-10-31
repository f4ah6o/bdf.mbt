//go:build ignore

package main

import (
	"fmt"
	"math"
)

const unit = math.Pi / 180 / 60000

func main() {
	fmt.Println("///|")
	fmt.Println("// Expected paths generated using upstream Go rounded-rectangle geometry.")
	fmt.Println("test \"rounded rectangle paths match Go for varied dimensions\" {")
	for i := 0; i < 64; i++ {
		w := float64((i*313)%40000+1) / 12700
		h := float64((i*719)%40000+1) / 12700
		adj := (i * 7919) % 100001
		r := math.Min(w, h) * math.Min(float64(adj), 50000) / 100000
		right, bottom := w-r, h-r
		vals := []float64{0, r}
		verbs := []byte{0}
		cx, cy := 0.0, r
		for j, v := range []float64{10800000, 16200000, 0, 5400000} {
			if r > 0 {
				st, sw := v*unit, 5400000*unit
				param := func(x float64) float64 { return math.Atan2(r*math.Sin(x), r*math.Cos(x)) }
				a0 := param(st)
				d := param(st+sw) - (a0 + sw)
				d -= 2 * math.Pi * math.Round(d/(2*math.Pi))
				a1 := a0 + sw + d
				ex, ey := cx-r*math.Cos(a0), cy-r*math.Sin(a0)
				verbs = append(verbs, 6)
				vals = append(vals, ex, ey, r, r, 0, a0, a1, 0)
				cx, cy = ex+r*math.Cos(a1), ey+r*math.Sin(a1)
			}
			if j < 3 {
				switch j {
				case 0:
					cx, cy = right, 0
				case 1:
					cx, cy = w, bottom
				case 2:
					cx, cy = r, h
				}
				verbs = append(verbs, 1)
				vals = append(vals, cx, cy)
			}
		}
		verbs = append(verbs, 4)
		fmt.Printf("  check_round_rect_path(%0.17g, %0.17g, %dL, b\"", w, h, adj)
		for _, v := range verbs {
			fmt.Printf("\\x%02x", v)
		}
		fmt.Print("\", [")
		for _, v := range vals {
			fmt.Printf("0x%08xU,", math.Float32bits(float32(v)))
		}
		fmt.Println("])")
	}
	fmt.Println("}")
	fmt.Println(`
///|
fn check_round_rect_path(width : Double, height : Double, adjustment : Int64, verbs : Bytes, expected : Array[UInt32]) -> Unit raise {
  let path = sheet_round_rect_path(width, height, adjustment)
  assert_eq(path.verbs, verbs)
  for i in 0..<expected.length() {
    assert_eq(Float::from_double(path.coordinates[i]).reinterpret_as_uint(), expected[i])
  }
}`)
}
