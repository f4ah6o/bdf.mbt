//go:build ignore

package main

import (
	"fmt"
	"math"
)

const unit = math.Pi / 180 / 60000

func main() {
	fmt.Println("///|")
	fmt.Println("// Expected paths generated using the upstream Go ellipse geometry.")
	fmt.Println("test \"ellipse paths match Go for varied dimensions\" {")
	for i := 0; i < 64; i++ {
		w := float64((i*313)%40000+1) / 12700
		h := float64((i*719)%40000+1) / 12700
		wr, hr := w/2, h/2
		vals := []float64{0, hr}
		cx, cy := 0.0, hr
		for _, v := range []float64{10800000, 16200000, 0, 5400000} {
			st, sw := v*unit, 5400000*unit
			param := func(x float64) float64 { return math.Atan2(wr*math.Sin(x), hr*math.Cos(x)) }
			a0 := param(st)
			d := param(st+sw) - (a0 + sw)
			d -= 2 * math.Pi * math.Round(d/(2*math.Pi))
			a1 := a0 + sw + d
			ex, ey := cx-wr*math.Cos(a0), cy-hr*math.Sin(a0)
			vals = append(vals, ex, ey, wr, hr, 0, a0, a1, 0)
			cx, cy = ex+wr*math.Cos(a1), ey+hr*math.Sin(a1)
		}
		fmt.Printf("  check_ellipse_path(%0.17g, %0.17g, [", w, h)
		for _, v := range vals {
			fmt.Printf("0x%08xU,", math.Float32bits(float32(v)))
		}
		fmt.Println("])")
	}
	fmt.Println("}")
	fmt.Println(`
///|
fn check_ellipse_path(width : Double, height : Double, expected : Array[UInt32]) -> Unit raise {
  let path = sheet_ellipse_path(width, height)
  for i in 0..<expected.length() {
    assert_eq(Float::from_double(path.coordinates[i]).reinterpret_as_uint(), expected[i])
  }
}`)
}
