//go:build ignore

// Generate Go's quantized sRGB values for DrawingML scRGB percentages.
package main

import (
	"fmt"
	"math"
)

func main() {
	thresholds := [256]int{}
	for i := range thresholds {
		thresholds[i] = -1
	}
	for i := 0; i <= 100000; i++ {
		v := float64(i) / 100000
		var srgb float64
		if v <= 0.0031308 {
			srgb = v * 12.92
		} else {
			srgb = 1.055*math.Pow(v, 1/2.4) - 0.055
		}
		q := int(math.Round(srgb * 255))
		if q < 0 || q > 255 {
			panic("component out of range")
		}
		if thresholds[q] < 0 {
			thresholds[q] = i
		}
	}
	for _, threshold := range thresholds {
		if threshold < 0 {
			panic("missing component value")
		}
		fmt.Printf("%d\n", threshold)
	}
}
