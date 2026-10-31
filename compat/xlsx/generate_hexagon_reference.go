//go:build ignore

package main

import (
	"fmt"
	"math"
)

const unit = math.Pi / 180 / 60000

func main() {
	fmt.Println("///|")
	fmt.Println("// Expected paths generated using the upstream Go hexagon geometry.")
	fmt.Println("test \"hexagon paths match Go for varied dimensions\" {")
	for i := 0; i < 64; i++ {
		w := float64((i*313)%40000+1) / 12700
		h := float64((i*719)%40000+1) / 12700
		adj := (i * 7919) % 100001
		ss := math.Min(w, h)
		max := 50000 * w / ss
		a := math.Min(float64(adj), max)
		x1 := ss * a / 100000
		x2 := w - x1
		vc := h / 2
		shd2 := vc * 115470 / 100000
		angle := 3600000.0
		dy1 := shd2 * math.Sin(angle*unit)
		y1 := vc - dy1
		y2 := vc + dy1
		vals := []float64{0, vc, x1, y1, x2, y1, w, vc, x2, y2, x1, y2}
		fmt.Printf("  check_hexagon_path(%0.17g, %0.17g, %dL, [", w, h, adj)
		for _, v := range vals {
			fmt.Printf("0x%08xU,", math.Float32bits(float32(v)))
		}
		fmt.Println("])")
	}
	fmt.Println("}")
	fmt.Println(`
///|
fn check_hexagon_path(width : Double, height : Double, adjustment : Int64, expected : Array[UInt32]) -> Unit raise {
  let path = sheet_hexagon_path(width, height, adjustment)
  for i in 0..<expected.length() {
    assert_eq(Float::from_double(path.coordinates[i]).reinterpret_as_uint(), expected[i])
  }
}`)
}
