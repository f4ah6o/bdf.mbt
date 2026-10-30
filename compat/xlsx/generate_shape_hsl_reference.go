//go:build ignore

// Generate upstream-compatible HSL-to-RGBA regression values.
package main

import (
	"fmt"
	"math"
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
	for i := 0; i < 4096; i++ {
		h, s, l := (i*293729)%21600001, (i*37199)%100001, (i*6199)%100001
		r, g, b := hsl(float64(h)/60000/360, float64(s)/100000, float64(l)/100000)
		fmt.Printf("    (%dL, %dL, %dL, 0x%08xU),\n", h, s, l, q(r)<<24|q(g)<<16|q(b)<<8|255)
	}
}
