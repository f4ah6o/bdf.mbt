package main

import (
	"fmt"
	"math"
	"runtime"
	"strconv"
)

func main() {
	fmt.Printf("runtime=%s os=%s arch=%s\n", runtime.Version(), runtime.GOOS, runtime.GOARCH)
	v := math.Float64frombits(0x0000a16d71638eb5)
	fmt.Printf("subnormal=%g log10=%.17g floor=%g\n", v, math.Log10(v), math.Floor(math.Log10(v)))
	for _, s := range []string{"NaN", "9223372036854775808", "1e100", "-0.5", "0.5", "1.9"} {
		f, _ := strconv.ParseFloat(s, 64)
		fmt.Printf("AttrInt fallback %s => %d\n", s, int64(f))
	}
}
