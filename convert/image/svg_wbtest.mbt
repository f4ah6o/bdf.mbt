///|
test "SVG dimensions support CSS units and viewBox aspect ratio" {
  assert_eq(svg_length("1em"), 16.0)
  assert_eq(svg_length("2ex"), 16.0)
  assert_eq(svg_length(".5in"), 48.0)
  assert_eq(svg_length("1e-1"), 0.1)
  assert_eq(svg_length("50%"), 0.0)
  assert_eq(svg_dimensions("1.25in", "", "0 0 4 3"), (120.0, 90.0))
  assert_eq(svg_dimensions("", "", ""), (300.0, 150.0))
  assert_eq(image_px(1.0e23), "100000000000000000000000")
  assert_eq(image_px(1.2345678901234568e30), "1234567890123456800000000000000")
}

///|
test "SVG trailing content is distinguished from malformed SVG" {
  let good = "<svg xmlns=\"http://www.w3.org/2000/svg\"/>"
  assert_false(svg_has_trailing_content(good + "\n<!-- end -->"))
  assert_true(svg_has_trailing_content(good + "\n# text"))
  let invalid = try {
    ignore(convert(@utf8.encode(good + "\n# text")))
    false
  } catch {
    ImageFailure(message) => message.contains("not a supported")
    _ => false
  }
  assert_true(invalid)
  let unknown_entity = good.replace(
    old="/>",
    new="><title>&unknown;</title></svg>",
  )
  let recovered = convert(@utf8.encode(unknown_entity))
  assert_eq(recovered.format, "svg")
}

///|
test "SVG entity recovery leaves CDATA intact and is bounded" {
  let text = "<svg><title>&unknown;<![CDATA[&unknown;]]></title></svg>"
  let repaired = svg_repair_entities(text).unwrap()
  assert_eq(
    repaired, "<svg><title>&amp;unknown;<![CDATA[&unknown;]]></title></svg>",
  )
  let long = StringBuilder()
  long.write_string("<svg><title>")
  for _ in 0..<33 {
    long.write_string("&unknown;")
  }
  long.write_string("</title></svg>")
  assert_eq(svg_repair_entities(long.to_string()), None)
}
