//go:build ignore

package main

import (
	"fmt"
	"math"
)

func comp(v float64) int {
	var c float64
	if v <= 0.0031308 {
		c = v * 12.92
	} else {
		c = 1.055*math.Pow(v, 1/2.4) - 0.055
	}
	return int(math.Round(c * 255))
}
func main() {
	hiBits := math.Float64bits(1.0)
	fmt.Println("///|\n// Generated with compat/xlsx/generate_linear_double_reference.go.\ntest \"linear RGB floating boundaries match Go\" {\n  let cases : Array[(UInt64, UInt32)] = [")
	for q := 1; q < 256; q++ {
		lo, hi := uint64(0), hiBits
		for lo < hi {
			mid := lo + (hi-lo)/2
			if comp(math.Float64frombits(mid)) >= q {
				hi = mid
			} else {
				lo = mid + 1
			}
		}
		for d := -8; d <= 8; d++ {
			x := uint64(int64(lo) + int64(d))
			want := q
			if d < 0 {
				want = q - 1
			}
			if comp(math.Float64frombits(x)) != want {
				panic(fmt.Sprintf("nonmonotonic q=%d d=%d", q, d))
			}
		}
		for _, bits := range []uint64{lo - 1, lo} {
			fmt.Printf("    (0x%016xUL, %dU),\n", bits, comp(math.Float64frombits(bits)))
		}
	}
	fmt.Println("  ]\n  for (bits, expected) in cases {\n    assert_eq(xlsx_shape_linear_fraction(bits.reinterpret_as_double()), expected)\n  }\n  assert_eq(xlsx_shape_linear_fraction(-0.0), 0U)\n  for i = 0; i <= 100000; i = i + 1 {\n    assert_eq(xlsx_shape_linear_fraction(i.to_double() / 100000.0), xlsx_shape_linear_component(i))\n  }\n}")
}
