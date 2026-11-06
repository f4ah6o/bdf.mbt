///|
fn raster_u32(data : Bytes, offset : Int) -> Int {
  (data[offset].to_int() << 24) |
  (data[offset + 1].to_int() << 16) |
  (data[offset + 2].to_int() << 8) |
  data[offset + 3].to_int()
}

///|
fn raster_bytes(data : Bytes) -> Array[Int] {
  data.to_array().map(fn(byte) { byte.to_int() })
}

///|
test "pwg header" {
  let page : Page = {
    ..Page::new(144, 216, 144, 144, SGRAY_8),
    page_width: 72,
    page_height: 108,
    page_size_name: "custom_25.4x38.1mm",
    total_pages: 2,
    cross_feed: 1,
    feed: 1,
  }
  let header = page.header()
  assert_eq(header.length(), HEADER_SIZE)
  assert_eq(header[0].to_int(), 'P'.to_int())
  assert_eq(raster_u32(header, 276), 144)
  assert_eq(raster_u32(header, 280), 144)
  assert_eq(raster_u32(header, 340), 1)
  assert_eq(raster_u32(header, 352), 72)
  assert_eq(raster_u32(header, 356), 108)
  assert_eq(raster_u32(header, 372), 144)
  assert_eq(raster_u32(header, 376), 216)
  assert_eq(raster_u32(header, 384), 8)
  assert_eq(raster_u32(header, 388), 8)
  assert_eq(raster_u32(header, 392), 144)
  assert_eq(raster_u32(header, 400), 18)
  assert_eq(raster_u32(header, 420), 1)
  assert_eq(raster_u32(header, 452), 2)
  assert_eq(raster_u32(header, 456), 1)
  assert_eq(raster_u32(header, 460), 1)
  let name = header[1732:1732 + 18]
  assert_eq(@utf8.decode(name), "custom_25.4x38.1mm")
  let rgb : Page = { ..Page::new(10, 20, 300, 300, SRGB_8) }
  let rgb_header = rgb.header()
  assert_eq(raster_u32(rgb_header, 388), 24)
  assert_eq(raster_u32(rgb_header, 392), 30)
  assert_eq(raster_u32(rgb_header, 400), 19)
  assert_eq(raster_u32(rgb_header, 420), 3)
  let bad = try {
    ignore(Page::new(4, 2, 300, 300, "cmyk_8").header())
    false
  } catch {
    RasterError(_) => true
  }
  assert_true(bad, msg="an unknown type")
}

///|
test "pwg line encoding" {
  let cases : Array[(Array[Int], Int, Array[Int])] = [
    ([7], 1, [0, 0, 7]),
    ([7, 7, 7], 1, [0, 2, 7]),
    ([1, 2, 3], 1, [0, 254, 1, 2, 3]),
    ([1, 2, 2, 2, 3], 1, [0, 0, 1, 2, 2, 0, 3]),
    ([1, 2, 3, 3], 1, [0, 255, 1, 2, 1, 3]),
    ([1, 2, 3, 1, 2, 3, 9, 9, 9], 3, [0, 1, 1, 2, 3, 0, 9, 9, 9]),
  ]
  for entry in cases {
    let line = Bytes::from_array(entry.0.map(fn(value) { value.to_byte() }))
    let got = encode_line(line, entry.1)
    assert_eq(raster_bytes(got), entry.2)
  }
  let long = Bytes::make(300, b'\x05')
  assert_eq(raster_bytes(encode_line(long, 1)), [0, 127, 5, 127, 5, 43, 5])
  let literal : Array[Byte] = []
  for i in 0..<200 {
    literal.push(i.to_byte())
  }
  let encoded = encode_line(Bytes::from_array(literal), 1)
  let got = raster_bytes(encoded)
  assert_eq(got.length(), 1 + 1 + 128 + 1 + 72)
  assert_eq(got[1], 129)
  assert_eq(got[130], 257 - 72)
}
