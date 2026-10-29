///|
fn test_webp_chunk(out : @buffer.Buffer, kind : Bytes, data : Bytes) -> Unit {
  out.write_bytes(kind)
  out.write_uint_le(data.length().to_uint())
  out.write_bytes(data)
  if data.length() % 2 == 1 {
    out.write_byte(0)
  }
}

///|
fn test_webp(kind : Bytes, payload : Bytes) -> Bytes {
  let body = @buffer.Buffer()
  body.write_bytes(b"WEBP")
  test_webp_chunk(body, kind, payload)
  let file = @buffer.Buffer()
  file.write_bytes(b"RIFF")
  file.write_uint_le(body.length().to_uint())
  file.write_bytes(body.to_bytes())
  file.to_bytes()
}

///|
test "WebP reads lossy and lossless frame dimensions" {
  let lossy = convert(
    test_webp(b"VP8 ", b"\x00\x00\x00\x9d\x01\x2a\x07\x00\x05\x00"),
  )
  let lossless = convert(test_webp(b"VP8L", b"\x2f\x06\x00\x01\x00"))
  assert_eq((lossy.width, lossy.height), (7.0, 5.0))
  assert_eq((lossless.width, lossless.height), (7.0, 5.0))
  assert_eq(lossless.summary, "1 page (7 × 5 px, WebP)")
}

///|
test "animated WebP warns about EXIF orientation before animation" {
  let body = @buffer.Buffer()
  body.write_bytes(b"WEBP")
  test_webp_chunk(body, b"VP8X", b"\x00\x00\x00\x00\x06\x00\x00\x04\x00\x00")
  test_webp_chunk(
    body, b"EXIF", b"II\x2a\x00\x08\x00\x00\x00\x01\x00\x12\x01\x03\x00\x01\x00\x00\x00\x06\x00\x00\x00\x00\x00\x00\x00",
  )
  test_webp_chunk(body, b"ANMF", b"")
  test_webp_chunk(body, b"ANMF", b"")
  let file = @buffer.Buffer()
  file.write_bytes(b"RIFF")
  file.write_uint_le(body.length().to_uint())
  file.write_bytes(body.to_bytes())
  let bytes = file.to_bytes()
  let result = convert(bytes)
  assert_eq((result.width, result.height), (7.0, 5.0))
  assert_true(result.animated)
  assert_eq(result.warnings, [
    "the EXIF orientation of the WebP image is not applied: browsers draw WebP images as they are stored",
    "animated image: the first frame is drawn",
  ])
  for n in 0..<=bytes.length() {
    ignore(Some(convert(bytes[:n].to_bytes())) catch { _ => None })
  }
}
