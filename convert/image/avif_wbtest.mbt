///|
fn test_iso_box(kind : Bytes, data : Bytes) -> Bytes {
  let out = @buffer.Buffer()
  out.write_uint_be((data.length() + 8).to_uint())
  out.write_bytes(kind)
  out.write_bytes(data)
  out.to_bytes()
}

///|
test "AVIF sequence uses track dimensions and reports animation" {
  let track = Bytes::make(84, 0).to_array()
  track[77] = 64
  track[81] = 48
  let body = @buffer.Buffer()
  body.write_bytes(test_iso_box(b"ftyp", b"avis\x00\x00\x00\x00avis"))
  body.write_bytes(
    test_iso_box(
      b"moov",
      test_iso_box(b"trak", test_iso_box(b"tkhd", Bytes::from_array(track))),
    ),
  )
  let file = body.to_bytes()
  let result = convert(file, name="sequence.avif")
  assert_eq((result.format, result.width, result.height), ("avif", 64.0, 48.0))
  assert_true(result.animated)
  assert_eq(result.warnings, ["animated image: the first frame is drawn"])
  for n in 0..<=file.length() {
    ignore(Some(convert(file[:n].to_bytes())) catch { _ => None })
  }
}

///|
test "AVIF limits repeated metadata extents to one file's size" {
  let items = @buffer.Buffer()
  for _ in 0..<100 {
    items.write_uint_be(2)
    items.write_uint16_be(0)
    items.write_uint16_be(0)
    items.write_uint16_be(1)
  }
  let iloc = @buffer.Buffer()
  iloc.write_bytes(b"\x02\x00\x00\x00\x00\x00")
  iloc.write_uint_be(100)
  iloc.write_bytes(items.to_bytes())
  let file = Bytes::make(256, 0)
  let meta = iso_boxes(test_iso_box(b"iloc", iloc.to_bytes()))
  let picture : AvifMetadata = { width: 0, height: 0, exif: [], xmp: [], }
  let types : Map[UInt64, AvifItem] = {
    2UL: { kind: b"Exif", content_type: b"", },
  }
  avif_extents(meta, file, types, picture)
  assert_eq(picture.exif.length(), 1)
  assert_true(picture.exif[0].length() <= file.length())
}
