///|
test "quarter-turn trigonometry matches upstream float encodings" {
  for
    (degrees, sine, cosine) in [
      (-360, 0x258d3132U, 0x3f800000U),
      (-270, 0x3f800000U, 0xa553c9caU),
      (-180, 0xa50d3132U, 0xbf800000U),
      (-90, 0xbf800000U, 0x248d3132U),
      (90, 0x3f800000U, 0x248d3132U),
      (180, 0x250d3132U, 0xbf800000U),
      (270, 0xbf800000U, 0xa553c9caU),
      (360, 0xa58d3132U, 0x3f800000U),
    ] {
    let angle = degrees.to_double() * @math.PI / 180.0
    assert_eq(Float::from_double(@math.sin(angle)).reinterpret_as_uint(), sine)
    assert_eq(
      Float::from_double(@math.cos(angle)).reinterpret_as_uint(),
      cosine,
    )
  }
}
