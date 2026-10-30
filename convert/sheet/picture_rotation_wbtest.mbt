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

///|
test "arbitrary rotation trigonometry matches upstream float encodings" {
  for
    (units, sine, cosine) in [
      (21600001, 0x349c2b5fU, 0x3f800000U),
      (27000000, 0x3f800000U, 0x25b07d7eU),
      (43200000, 0xa60d3132U, 0x3f800000U),
      (53999999, 0x349c2b5fU, 0xbf800000U),
      (64800000, 0xa653c9caU, 0x3f800000U),
      (86399999, 0xb49c2b5fU, 0x3f800000U),
      (86400000, 0xa68d3132U, 0x3f800000U),
      (-21600001, 0xb49c2b5fU, 0x3f800000U),
      (-64800000, 0x2653c9caU, 0x3f800000U),
      (-86400000, 0x268d3132U, 0x3f800000U),
      (12345, 0x3b6b571bU, 0x3f7fff94U),
      (60000, 0x3c8ef859U, 0x3f7ff605U),
      (2700000, 0x3f3504f3U, 0x3f3504f3U),
      (5399999, 0x3f800000U, 0x349c2b5fU),
      (7230000, 0x3f5c93bbU, 0xbf01ee09U),
      (-900000, 0xbe8483eeU, 0x3f7746eaU),
      (-13800000, 0x3f441b7dU, 0xbf248dbbU),
    ] {
    let angle = units.to_double() / 60000.0 * @math.PI / 180.0
    assert_eq(Float::from_double(@math.sin(angle)).reinterpret_as_uint(), sine)
    assert_eq(
      Float::from_double(@math.cos(angle)).reinterpret_as_uint(),
      cosine,
    )
  }
}
