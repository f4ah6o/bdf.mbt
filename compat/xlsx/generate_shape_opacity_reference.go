//go:build ignore

package main

import (
	"fmt"
	"math"
	"strconv"
	"strings"
)

func main() {
	fmt.Println("///|")
	fmt.Println("// Generated with Go strconv.ParseFloat and DrawingML percentage conversion.")
	fmt.Println("test \"shape opacity percentages match Go\" {")
	fmt.Println("  let cases : Array[(String, UInt64)] = [")
	for i := 0; i < 128; i++ {
		v := (i * 7919) % 1000001
		var raw string
		if i%2 == 0 {
			raw = fmt.Sprintf("%.3f%%", float64(v)/1000)
		} else {
			raw = fmt.Sprintf("%d.25", v)
		}
		factor := 100000.0
		text := raw
		if strings.HasSuffix(raw, "%") {
			factor = 100
			text = strings.TrimSuffix(raw, "%")
		}
		n, e := strconv.ParseFloat(text, 64)
		if e != nil {
			panic(e)
		}
		fmt.Printf("    (\"%s\", 0x%016xUL),\n", raw, math.Float64bits(n/factor))
	}
	fmt.Println(`  ]
  for (raw, expected) in cases {
    let reader = @xml.NamespaceReader::from_string("<alphaMod val=\"" + raw + "\"/>")
    let element = match reader.read_event().kind {
      Empty(element) => element
      _ => fail("expected alpha modifier")
    }
    let fraction = xlsx_shape_opacity_fraction(element, "alphaMod").unwrap()
    assert_eq(fraction.reinterpret_as_uint64(), expected)
  }
}`)
}
