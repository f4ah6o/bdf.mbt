//go:build ignore

// Generate upstream-compatible HSL-to-RGBA regression values.
package main

import (
	"fmt"
	"math"
	"strconv"
)

func hsl(h, s, l float64) (float64, float64, float64) {
	if s == 0 {
		return l, l, l
	}
	var q float64
	if l < 0.5 {
		q = l * (1 + s)
	} else {
		q = l + s - l*s
	}
	p := 2*l - q
	hue := func(t float64) float64 {
		t -= math.Floor(t)
		switch {
		case t < 1.0/6:
			return p + (q-p)*6*t
		case t < 0.5:
			return q
		case t < 2.0/3:
			return p + (q-p)*(2.0/3-t)*6
		}
		return p
	}
	return hue(h + 1.0/3), hue(h), hue(h - 1.0/3)
}
func q(v float64) uint32 { return uint32(math.Round(math.Max(0, math.Min(1, v)) * 255)) }
func main() {
	fmt.Println("///|")
	fmt.Println("// Generated with the upstream Go HSL and strict percentage conversion.")
	fmt.Println("test \"strict HSL values match Go\" {")
	fmt.Println("  let cases : Array[(Int64, String, String, UInt32)] = [")
	for i := 0; i < 128; i++ {
		h, s, l := (i*293729)%21600001, (i*37199)%100001, (i*6199)%100001
		ss, ls := fmt.Sprintf("%.3f%%", float64(s)/1000), fmt.Sprintf("%.3f%%", float64(l)/1000)
		sv, _ := strconv.ParseFloat(ss[:len(ss)-1], 64)
		lv, _ := strconv.ParseFloat(ls[:len(ls)-1], 64)
		r, g, b := hsl(float64(h)/60000/360, sv/100, lv/100)
		fmt.Printf("    (%dL, \"%s\", \"%s\", 0x%08xU),\n", h, ss, ls, q(r)<<24|q(g)<<16|q(b)<<8|255)
	}
	fmt.Println(`  ]
  for (hue, sat, lum, expected) in cases {
    let color = xlsx_shape_hsl_fractions(hue.to_double() / 60000.0 / 360.0, xlsx_drawing_fraction(sat).unwrap(), xlsx_drawing_fraction(lum).unwrap())
    assert_eq(color, expected)
  }
}`)
}
