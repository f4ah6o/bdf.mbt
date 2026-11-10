///|
/// Little-endian u16 for the synthetic DIB headers.
fn rle8_u16(b : @buffer.Buffer, v : Int32) -> Unit {
  b.write_byte((v & 0xff).to_byte())
  b.write_byte(((v >> 8) & 0xff).to_byte())
}

///|
/// Little-endian u32 for the synthetic DIB headers.
fn rle8_u32(b : @buffer.Buffer, v : Int32) -> Unit {
  b.write_byte((v & 0xff).to_byte())
  b.write_byte(((v >> 8) & 0xff).to_byte())
  b.write_byte(((v >> 16) & 0xff).to_byte())
  b.write_byte(((v >> 24) & 0xff).to_byte())
}

///|
/// A DIB with an arbitrary biSize, a palette of (red, green, blue) entries,
/// and the given BI_RLE8 bytes. `used` is written to biClrUsed.
fn rle8_dib_with_header(
  header_size : Int32,
  width : Int32,
  height : Int32,
  bpp : Int32,
  compression : Int32,
  used : Int32,
  palette : Array[(Int32, Int32, Int32)],
  bits : Array[Int32],
) -> Bytes {
  let b = @buffer.Buffer()
  rle8_u32(b, header_size) // biSize
  rle8_u32(b, width) // biWidth
  rle8_u32(b, height) // biHeight
  rle8_u16(b, 1) // biPlanes
  rle8_u16(b, bpp) // biBitCount
  rle8_u32(b, compression) // biCompression
  rle8_u32(b, bits.length()) // biSizeImage
  rle8_u32(b, 0) // biXPelsPerMeter
  rle8_u32(b, 0) // biYPelsPerMeter
  rle8_u32(b, used) // biClrUsed
  rle8_u32(b, 0) // biClrImportant
  for (red, green, blue) in palette {
    b.write_byte(blue.to_byte())
    b.write_byte(green.to_byte())
    b.write_byte(red.to_byte())
    b.write_byte(0)
  }
  for value in bits {
    b.write_byte(value.to_byte())
  }
  b.to_bytes()
}

///|
/// A 40-byte BITMAPINFOHEADER, a palette of (red, green, blue) entries, and
/// the given BI_RLE8 bytes. `used` is written to biClrUsed.
fn rle8_dib_used(
  width : Int32,
  height : Int32,
  used : Int32,
  palette : Array[(Int32, Int32, Int32)],
  bits : Array[Int32],
) -> Bytes {
  rle8_dib_with_header(40, width, height, 8, 1, used, palette, bits)
}

///|
fn rle8_dib(
  width : Int32,
  height : Int32,
  palette : Array[(Int32, Int32, Int32)],
  bits : Array[Int32],
) -> Bytes {
  rle8_dib_used(width, height, palette.length(), palette, bits)
}

///|
fn rle8_decode_or_abort(data : Bytes) -> Dib {
  match dib_decode(data, None) {
    Some(value) => value
    None => abort("the RLE8 DIB did not decode")
  }
}

///|
fn rle8_pixel(dib : Dib, x : Int32, y : Int32) -> (Int32, Int32, Int32, Int32) {
  let at = (y * dib.width + x) * 4
  (
    dib.rgba[at].to_int(),
    dib.rgba[at + 1].to_int(),
    dib.rgba[at + 2].to_int(),
    dib.rgba[at + 3].to_int(),
  )
}

///|
fn rle8_expect(
  dib : Dib,
  x : Int32,
  y : Int32,
  red : Int32,
  green : Int32,
  blue : Int32,
) -> Unit {
  let (r, g, b, a) = rle8_pixel(dib, x, y)
  guard r == red && g == green && b == blue && a == 255 else {
    abort(
      "pixel (\\{x},\\{y}) is (\\{r},\\{g},\\{b},\\{a}), not (\\{red},\\{green},\\{blue},255)",
    )
  }
}

///|
test "BI_RLE8 encoded runs use the palette and bottom-up rows" {
  let data = rle8_dib(
    2,
    2,
    [(0, 0, 0), (255, 0, 0), (0, 255, 0)],
    [0x02, 0x01, 0x00, 0x00, 0x02, 0x02, 0x00, 0x01],
  )
  let dib = rle8_decode_or_abort(data)
  guard dib.width == 2 && dib.height == 2 else {
    abort("the DIB is \\{dib.width}x\\{dib.height}, not 2x2")
  }
  // the first stream row is the bottom row
  rle8_expect(dib, 0, 1, 255, 0, 0)
  rle8_expect(dib, 1, 1, 255, 0, 0)
  rle8_expect(dib, 0, 0, 0, 255, 0)
  rle8_expect(dib, 1, 0, 0, 255, 0)
}

///|
test "BI_RLE8 absolute runs read literal indices and skip the pad byte" {
  let data = rle8_dib(
    3,
    1,
    [(0, 0, 0), (10, 20, 30), (40, 50, 60), (70, 80, 90)],
    [0x00, 0x03, 0x01, 0x02, 0x03, 0x00, 0x00, 0x01],
  )
  let dib = rle8_decode_or_abort(data)
  rle8_expect(dib, 0, 0, 10, 20, 30)
  rle8_expect(dib, 1, 0, 40, 50, 60)
  rle8_expect(dib, 2, 0, 70, 80, 90)
}

///|
test "BI_RLE8 delta moves the cursor without drawing" {
  let data = rle8_dib(
    3,
    3,
    [(0, 0, 0), (255, 0, 0), (0, 255, 0)],
    [
      0x01, 0x01, // one red pixel at the bottom-left
      0x00, 0x00, // end of line: stored row 1
      0x00, 0x02, 0x01, 0x01, // delta: one right, one stored row up
      0x01, 0x02, // one green pixel
      0x00, 0x01, // end of bitmap
    ],
  )
  let dib = rle8_decode_or_abort(data)
  rle8_expect(dib, 0, 2, 255, 0, 0)
  rle8_expect(dib, 1, 0, 0, 255, 0)
  // the skipped pixels keep palette index 0
  rle8_expect(dib, 0, 0, 0, 0, 0)
  rle8_expect(dib, 2, 2, 0, 0, 0)
}

///|
test "BI_RLE8 top-down rows start at the top" {
  let data = rle8_dib(
    2,
    -2,
    [(0, 0, 0), (255, 0, 0), (0, 255, 0)],
    [0x02, 0x01, 0x00, 0x00, 0x02, 0x02, 0x00, 0x01],
  )
  let dib = rle8_decode_or_abort(data)
  rle8_expect(dib, 0, 0, 255, 0, 0)
  rle8_expect(dib, 1, 0, 255, 0, 0)
  rle8_expect(dib, 0, 1, 0, 255, 0)
  rle8_expect(dib, 1, 1, 0, 255, 0)
}

///|
test "BI_RLE8 end of bitmap leaves the rest at palette index 0" {
  let data = rle8_dib(2, 2, [(1, 2, 3), (255, 0, 0)], [0x00, 0x01])
  let dib = rle8_decode_or_abort(data)
  rle8_expect(dib, 0, 0, 1, 2, 3)
  rle8_expect(dib, 1, 1, 1, 2, 3)
}

///|
test "BI_RLE8 rejects truncated records" {
  let palette = [(0, 0, 0), (255, 0, 0)]
  // a count without its value
  guard dib_decode(rle8_dib(2, 1, palette, [0x02]), None) is None else {
    abort("a truncated encoded run decoded")
  }
  // an absolute run shorter than its count
  guard dib_decode(
    rle8_dib(3, 1, palette, [0x00, 0x03, 0x01, 0x02]),
    None,
  ) is None else {
    abort("a truncated absolute run decoded")
  }
  // an absolute run without its pad byte
  guard dib_decode(
    rle8_dib(3, 1, palette, [0x00, 0x03, 0x01, 0x02, 0x03]),
    None,
  ) is None else {
    abort("an absolute run without a pad byte decoded")
  }
  // a delta without its two offsets
  guard dib_decode(rle8_dib(2, 2, palette, [0x00, 0x02, 0x01]), None) is None else {
    abort("a truncated delta decoded")
  }
  // an empty stream
  guard dib_decode(rle8_dib(2, 1, palette, []), None) is None else {
    abort("an empty RLE8 stream decoded")
  }
}

///|
test "BI_RLE8 rejects a stream that ends without end of bitmap" {
  let palette = [(0, 0, 0), (255, 0, 0)]
  // a complete encoded run, but no end of bitmap
  guard dib_decode(rle8_dib(2, 1, palette, [0x02, 0x01]), None) is None else {
    abort("a stream without end of bitmap decoded")
  }
  // repeated end-of-line escapes, but no end of bitmap
  guard dib_decode(
    rle8_dib(2, 2, palette, [0x00, 0x00, 0x00, 0x00]),
    None,
  ) is None else {
    abort("a stream of end-of-line escapes decoded")
  }
  // a complete absolute run with its pad byte, but no end of bitmap
  guard dib_decode(
    rle8_dib(3, 1, palette, [0x00, 0x03, 0x01, 0x02, 0x03, 0x00]),
    None,
  ) is None else {
    abort("an absolute run without end of bitmap decoded")
  }
  // a delta, but no end of bitmap
  guard dib_decode(
    rle8_dib(2, 2, palette, [0x00, 0x02, 0x01, 0x01]),
    None,
  ) is None else {
    abort("a delta without end of bitmap decoded")
  }
  // the same encoded run with end of bitmap still decodes
  let dib = rle8_decode_or_abort(
    rle8_dib(2, 1, palette, [0x02, 0x01, 0x00, 0x01]),
  )
  rle8_expect(dib, 0, 0, 255, 0, 0)
  rle8_expect(dib, 1, 0, 255, 0, 0)
}

///|
test "BI_RLE8 rejects runs and deltas outside the bitmap" {
  let palette = [(0, 0, 0), (255, 0, 0)]
  // an encoded run wider than the row
  guard dib_decode(
    rle8_dib(2, 1, palette, [0x03, 0x01, 0x00, 0x01]),
    None,
  ) is None else {
    abort("an encoded run past the row decoded")
  }
  // an absolute run wider than the row
  guard dib_decode(
    rle8_dib(2, 1, palette, [0x00, 0x03, 0x01, 0x01, 0x01, 0x00, 0x00, 0x01]),
    None,
  ) is None else {
    abort("an absolute run past the row decoded")
  }
  // a delta past the right edge
  guard dib_decode(
    rle8_dib(2, 2, palette, [0x00, 0x02, 0x03, 0x00, 0x00, 0x01]),
    None,
  ) is None else {
    abort("a delta past the right edge decoded")
  }
  // a delta past the bottom edge
  guard dib_decode(
    rle8_dib(2, 2, palette, [0x00, 0x02, 0x00, 0x02, 0x00, 0x01]),
    None,
  ) is None else {
    abort("a delta past the bottom edge decoded")
  }
  // a run after an end of line past the last row
  guard dib_decode(
    rle8_dib(2, 1, palette, [0x00, 0x00, 0x01, 0x01, 0x00, 0x01]),
    None,
  ) is None else {
    abort("a run after the last row decoded")
  }
}

///|
test "BI_RLE8 rejects palette indices outside biClrUsed" {
  let palette = [(0, 0, 0), (255, 0, 0)]
  guard dib_decode(
    rle8_dib(1, 1, palette, [0x01, 0x02, 0x00, 0x01]),
    None,
  ) is None else {
    abort("an out-of-range palette index decoded")
  }
}

///|
test "BI_RLE8 rejects a bitmap above the pixel limit before allocating" {
  let data = rle8_dib(100000, 100000, [(0, 0, 0)], [0x00, 0x01])
  guard dib_decode(data, None) is None else {
    abort("a 100000x100000 RLE8 DIB decoded")
  }
}

///|
test "an uncompressed DIB above the pixel limit is rejected" {
  let b = @buffer.Buffer()
  rle8_u32(b, 40)
  rle8_u32(b, 100000)
  rle8_u32(b, 100000)
  rle8_u16(b, 1)
  rle8_u16(b, 8)
  rle8_u32(b, 0) // BI_RGB
  rle8_u32(b, 0)
  rle8_u32(b, 0)
  rle8_u32(b, 0)
  rle8_u32(b, 2) // biClrUsed
  rle8_u32(b, 0)
  for (red, green, blue) in [(0, 0, 0), (255, 0, 0)] {
    b.write_byte(blue.to_byte())
    b.write_byte(green.to_byte())
    b.write_byte(red.to_byte())
    b.write_byte(0)
  }
  // no pixel data: the pixel limit must reject before the stride check
  guard dib_decode(b.to_bytes(), None) is None else {
    abort("a 100000x100000 uncompressed DIB decoded")
  }
}

///|
test "BI_RLE8 with biClrUsed 0 reads a 256-entry palette" {
  let palette : Array[(Int32, Int32, Int32)] = []
  for _ in 0..<256 {
    palette.push((0, 0, 0))
  }
  palette[1] = (255, 0, 0)
  let data = rle8_dib_used(1, 1, 0, palette, [0x01, 0x01, 0x00, 0x01])
  let dib = rle8_decode_or_abort(data)
  rle8_expect(dib, 0, 0, 255, 0, 0)
}

///|
test "BI_RLE8 rejects a palette shorter than biClrUsed" {
  let b = @buffer.Buffer()
  rle8_u32(b, 40)
  rle8_u32(b, 1)
  rle8_u32(b, 1)
  rle8_u16(b, 1)
  rle8_u16(b, 8)
  rle8_u32(b, 1) // BI_RLE8
  rle8_u32(b, 4)
  rle8_u32(b, 0)
  rle8_u32(b, 0)
  rle8_u32(b, 0) // biClrUsed 0 means 256 entries
  rle8_u32(b, 0)
  // only two palette entries follow
  for (red, green, blue) in [(0, 0, 0), (255, 0, 0)] {
    b.write_byte(blue.to_byte())
    b.write_byte(green.to_byte())
    b.write_byte(red.to_byte())
    b.write_byte(0)
  }
  for value in [0x01, 0x01, 0x00, 0x01] {
    b.write_byte(value.to_byte())
  }
  guard dib_decode(b.to_bytes(), None) is None else {
    abort("a truncated palette decoded")
  }
}

///|
test "BI_RLE8 requires 8 bits per pixel" {
  let b = @buffer.Buffer()
  rle8_u32(b, 40)
  rle8_u32(b, 1)
  rle8_u32(b, 1)
  rle8_u16(b, 1)
  rle8_u16(b, 4) // 4 bpp
  rle8_u32(b, 1) // BI_RLE8
  rle8_u32(b, 2)
  rle8_u32(b, 0)
  rle8_u32(b, 0)
  rle8_u32(b, 16)
  rle8_u32(b, 0)
  for _ in 0..<16 {
    rle8_u32(b, 0)
  }
  for value in [0x01, 0x01, 0x00, 0x01] {
    b.write_byte(value.to_byte())
  }
  guard dib_decode(b.to_bytes(), None) is None else {
    abort("a 4-bpp BI_RLE8 DIB decoded")
  }
}

///|
test "BI_RLE8 accepts a 255-pixel encoded run" {
  let palette = [(0, 0, 0), (255, 0, 0)]
  let bits = [0xff, 0x01]
  bits.push(0x00)
  bits.push(0x01)
  let dib = rle8_decode_or_abort(rle8_dib(255, 1, palette, bits))
  rle8_expect(dib, 0, 0, 255, 0, 0)
  rle8_expect(dib, 254, 0, 255, 0, 0)
}

///|
test "BI_RLE8 accepts a 255-pixel absolute run with padding" {
  let palette = [(0, 0, 0), (255, 0, 0)]
  let bits = [0x00, 0xff]
  for _ in 0..<255 {
    bits.push(0x01)
  }
  bits.push(0x00) // pad byte for the odd run
  bits.push(0x00)
  bits.push(0x01)
  let dib = rle8_decode_or_abort(rle8_dib(255, 1, palette, bits))
  rle8_expect(dib, 0, 0, 255, 0, 0)
  rle8_expect(dib, 254, 0, 255, 0, 0)
}

///|
test "BI_RLE8 accepts a delta followed by end of bitmap" {
  let palette = [(1, 2, 3), (255, 0, 0)]
  let dib = rle8_decode_or_abort(
    rle8_dib(2, 2, palette, [0x00, 0x02, 0x01, 0x01, 0x00, 0x01]),
  )
  rle8_expect(dib, 0, 0, 1, 2, 3)
  rle8_expect(dib, 1, 1, 1, 2, 3)
}

///|
test "dib_to_png encodes a BI_RLE8 DIB" {
  let data = rle8_dib(
    2,
    1,
    [(0, 0, 0), (255, 0, 0)],
    [0x02, 0x01, 0x00, 0x01],
  )
  let png = match dib_to_png(data, None) {
    Some(value) => value
    None => abort("the RLE8 DIB did not become a PNG")
  }
  guard png.length() > 8 && png[0].to_int() == 0x89 && png[1].to_int() == 0x50 else {
    abort("the PNG signature is missing")
  }
}

///|
test "dib_body_split keeps a BI_RLE8 stream behind the trailer" {
  let b = @buffer.Buffer()
  rle8_u32(b, 40)
  rle8_u32(b, 2)
  rle8_u32(b, 1)
  rle8_u16(b, 1)
  rle8_u16(b, 8)
  rle8_u32(b, 1) // BI_RLE8
  rle8_u32(b, 4)
  rle8_u32(b, 0)
  rle8_u32(b, 0)
  rle8_u32(b, 2) // biClrUsed
  rle8_u32(b, 0)
  for (red, green, blue) in [(0, 0, 0), (255, 0, 0)] {
    b.write_byte(blue.to_byte())
    b.write_byte(green.to_byte())
    b.write_byte(red.to_byte())
    b.write_byte(0)
  }
  rle8_u32(b, 1) // trailer marker
  rle8_u32(b, 4) // stored size
  rle8_u32(b, 4) // expanded size
  rle8_u32(b, 1) // rows
  for value in [0x02, 0x01, 0x00, 0x01] {
    b.write_byte(value.to_byte())
  }
  let (bmi, bits, stored, expanded) = match dib_body_split(b.to_bytes()) {
    Some(value) => value
    None => abort("the RLE8 body did not split")
  }
  guard stored == 4 && expanded == 4 else {
    abort("the trailer sizes are \\{stored}/\\{expanded}, not 4/4")
  }
  let dib = match dib_decode(bmi, Some(bits)) {
    Some(value) => value
    None => abort("the split RLE8 stream did not decode")
  }
  rle8_expect(dib, 0, 0, 255, 0, 0)
  rle8_expect(dib, 1, 0, 255, 0, 0)
}

///|
test "an uncompressed 8-bit DIB still decodes after the RLE8 path" {
  let b = @buffer.Buffer()
  rle8_u32(b, 40)
  rle8_u32(b, 2)
  rle8_u32(b, 2)
  rle8_u16(b, 1)
  rle8_u16(b, 8)
  rle8_u32(b, 0) // BI_RGB
  rle8_u32(b, 8)
  rle8_u32(b, 0)
  rle8_u32(b, 0)
  rle8_u32(b, 3) // biClrUsed
  rle8_u32(b, 0)
  for (red, green, blue) in [(0, 0, 0), (255, 0, 0), (0, 255, 0)] {
    b.write_byte(blue.to_byte())
    b.write_byte(green.to_byte())
    b.write_byte(red.to_byte())
    b.write_byte(0)
  }
  // bottom row: red, green; top row: green, red; each row padded to 4 bytes
  for value in [0x01, 0x02, 0x00, 0x00, 0x02, 0x01, 0x00, 0x00] {
    b.write_byte(value.to_byte())
  }
  let dib = rle8_decode_or_abort(b.to_bytes())
  rle8_expect(dib, 0, 1, 255, 0, 0)
  rle8_expect(dib, 1, 1, 0, 255, 0)
  rle8_expect(dib, 0, 0, 0, 255, 0)
  rle8_expect(dib, 1, 0, 255, 0, 0)
}

///|
test "BI_RLE8 rejects biClrUsed that would wrap the palette offset" {
  let palette = [(0, 0, 0), (255, 0, 0)]
  let bits = [0x01, 0x01, 0x00, 0x01]
  // 0x40000001 * 4 wraps to 4 in 32-bit arithmetic, which would place the
  // bits just behind a two-entry palette.
  let wrapped = rle8_dib_used(1, 1, 0x40000001, palette, bits)
  guard dib_bits_offset(wrapped) == 0 else {
    abort("a wrapped biClrUsed produced a bits offset")
  }
  guard dib_decode(wrapped, None) is None else {
    abort("a wrapped biClrUsed decoded")
  }
  // the unsigned maximum is also outside the 256-entry table
  let all_ones = rle8_dib_used(1, 1, -1, palette, bits)
  guard dib_bits_offset(all_ones) == 0 else {
    abort("biClrUsed 0xffffffff produced a bits offset")
  }
  guard dib_decode(all_ones, None) is None else {
    abort("biClrUsed 0xffffffff decoded")
  }
  // 256 entries are the largest valid table for 8 bpp
  let full : Array[(Int32, Int32, Int32)] = []
  for _ in 0..<256 {
    full.push((0, 0, 0))
  }
  full[1] = (255, 0, 0)
  let accepted = rle8_dib_used(1, 1, 256, full, bits)
  guard dib_bits_offset(accepted) == 40 + 256 * 4 else {
    abort("a 256-entry palette has the wrong bits offset")
  }
  let dib = rle8_decode_or_abort(accepted)
  rle8_expect(dib, 0, 0, 255, 0, 0)
  // one entry more is rejected
  let too_many = rle8_dib_used(1, 1, 257, full, bits)
  guard dib_decode(too_many, None) is None else {
    abort("biClrUsed 257 decoded")
  }
}

///|
test "BI_RLE8 rejects undersized and oversized bitmap headers" {
  let palette = [(0, 0, 0), (255, 0, 0)]
  let bits = [0x01, 0x01, 0x00, 0x01]
  // a header smaller than BITMAPINFOHEADER
  let undersized = rle8_dib_with_header(39, 1, 1, 8, 1, 2, palette, bits)
  guard dib_bits_offset(undersized) == 0 else {
    abort("a 39-byte header produced a bits offset")
  }
  guard dib_decode(undersized, None) is None else {
    abort("a 39-byte header decoded")
  }
  // a header that does not fit in the data
  let truncated = rle8_dib_with_header(108, 1, 1, 8, 1, 2, palette, bits)
  guard dib_bits_offset(truncated) == 0 else {
    abort("a 108-byte header in 48 bytes produced a bits offset")
  }
  guard dib_decode(truncated, None) is None else {
    abort("a 108-byte header in 48 bytes decoded")
  }
  // unsigned header sizes near 2^32 must not wrap to a small offset
  let huge = rle8_dib_with_header(0x7fffffff, 1, 1, 8, 1, 2, palette, bits)
  guard dib_bits_offset(huge) == 0 else {
    abort("a 0x7fffffff header produced a bits offset")
  }
  guard dib_decode(huge, None) is None else {
    abort("a 0x7fffffff header decoded")
  }
  let wrapped = rle8_dib_with_header(-16, 1, 1, 8, 1, 2, palette, bits)
  guard dib_bits_offset(wrapped) == 0 else {
    abort("a 0xfffffff0 header produced a bits offset")
  }
  guard dib_decode(wrapped, None) is None else {
    abort("a 0xfffffff0 header decoded")
  }
  // a header above the accepted cap
  let capped = rle8_dib_with_header(65537, 1, 1, 8, 1, 2, palette, bits)
  guard dib_decode(capped, None) is None else {
    abort("a 65537-byte header decoded")
  }
}

///|
test "BI_RLE8 rejects an end of line beyond the image height" {
  let palette = [(0, 0, 0), (255, 0, 0)]
  // one row: the end of line after the last row is allowed before EOB
  let dib = rle8_decode_or_abort(
    rle8_dib(1, 1, palette, [0x01, 0x01, 0x00, 0x00, 0x00, 0x01]),
  )
  rle8_expect(dib, 0, 0, 255, 0, 0)
  // a second end of line is past the image
  guard dib_decode(
    rle8_dib(1, 1, palette, [0x00, 0x00, 0x00, 0x00, 0x00, 0x01]),
    None,
  ) is None else {
    abort("two end-of-line escapes on a one-row image decoded")
  }
  // two rows: two end-of-line escapes reach the last row, a third is past it
  let two_rows = rle8_decode_or_abort(
    rle8_dib(1, 2, palette, [0x00, 0x00, 0x00, 0x00, 0x00, 0x01]),
  )
  rle8_expect(two_rows, 0, 0, 0, 0, 0)
  guard dib_decode(
    rle8_dib(1, 2, palette, [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]),
    None,
  ) is None else {
    abort("three end-of-line escapes on a two-row image decoded")
  }
}

///|
test "the pixel limit admits a 600 dpi A4 page" {
  // A4 at 600 dpi is 4962 x 7016 pixels, about 34.8 Mi pixels
  let a4_600 = 4962L * 7016L
  guard a4_600 <= MAX_DIB_PIXELS else {
    abort("a 600 dpi A4 page is above the pixel limit")
  }
  guard MAX_DIB_PIXELS == 67108864L else {
    abort("the pixel limit is \{MAX_DIB_PIXELS}, not 64 Mi")
  }
}

///|
test "BI_RLE8 decodes a bitmap above the old 16 Mi pixel limit" {
  let palette = [(0, 0, 0), (255, 0, 0)]
  // 4097 x 4096 is 16,781,312 pixels, just above the old 16 Mi limit
  let data = rle8_dib(4097, 4096, palette, [0x00, 0x01])
  let dib = rle8_decode_or_abort(data)
  guard dib.width == 4097 && dib.height == 4096 else {
    abort("the DIB is \{dib.width}x\{dib.height}, not 4097x4096")
  }
  rle8_expect(dib, 0, 0, 0, 0, 0)
  rle8_expect(dib, 4096, 4095, 0, 0, 0)
}

///|
test "BI_RLE8 rejects a bitmap above 64 Mi pixels" {
  let palette = [(0, 0, 0)]
  // 8193 x 8192 is 67,117,056 pixels, just above the 64 Mi limit
  let data = rle8_dib(8193, 8192, palette, [0x00, 0x01])
  guard dib_decode(data, None) is None else {
    abort("a 8193x8192 RLE8 DIB decoded")
  }
}

///|
test "BI_RLE8 validates the palette end before reading entries" {
  // a 256-entry palette that is one byte short
  let b = @buffer.Buffer()
  rle8_u32(b, 40)
  rle8_u32(b, 1)
  rle8_u32(b, 1)
  rle8_u16(b, 1)
  rle8_u16(b, 8)
  rle8_u32(b, 1) // BI_RLE8
  rle8_u32(b, 4)
  rle8_u32(b, 0)
  rle8_u32(b, 0)
  rle8_u32(b, 256) // biClrUsed
  rle8_u32(b, 0)
  for _ in 0..<255 {
    rle8_u32(b, 0)
  }
  // three bytes of the last entry, then the stream
  b.write_byte(0)
  b.write_byte(0)
  b.write_byte(0)
  let bits = @buffer.Buffer()
  for value in [0x01, 0x01, 0x00, 0x01] {
    bits.write_byte(value.to_byte())
  }
  guard dib_decode(b.to_bytes(), Some(bits.to_bytes())) is None else {
    abort("a palette one byte short decoded")
  }
}

///|
test "a BITMAPCOREHEADER palette must fit before the bits" {
  let b = @buffer.Buffer()
  rle8_u32(b, 12)
  rle8_u16(b, 1)
  rle8_u16(b, 1)
  rle8_u16(b, 1)
  rle8_u16(b, 8)
  // only two of the 256 three-byte entries
  for _ in 0..<2 {
    b.write_byte(0)
    b.write_byte(0)
    b.write_byte(0)
  }
  guard dib_bits_offset(b.to_bytes()) == 0 else {
    abort("a truncated core palette produced a bits offset")
  }
  guard dib_decode(b.to_bytes(), None) is None else {
    abort("a truncated core palette decoded")
  }
}

///|
test "an uncompressed DIB rejects a palette index outside biClrUsed" {
  let b = @buffer.Buffer()
  rle8_u32(b, 40)
  rle8_u32(b, 1)
  rle8_u32(b, 1)
  rle8_u16(b, 1)
  rle8_u16(b, 8)
  rle8_u32(b, 0) // BI_RGB
  rle8_u32(b, 4)
  rle8_u32(b, 0)
  rle8_u32(b, 0)
  rle8_u32(b, 2) // biClrUsed
  rle8_u32(b, 0)
  for (red, green, blue) in [(0, 0, 0), (255, 0, 0)] {
    b.write_byte(blue.to_byte())
    b.write_byte(green.to_byte())
    b.write_byte(red.to_byte())
    b.write_byte(0)
  }
  // index 2 is outside the two-entry table
  b.write_byte(2)
  b.write_byte(0)
  b.write_byte(0)
  b.write_byte(0)
  guard dib_decode(b.to_bytes(), None) is None else {
    abort("an uncompressed palette index outside biClrUsed decoded")
  }
}

///|
test "an unsupported bit depth is rejected before the stride calculation" {
  // bpp is an untrusted u16: 100000 * 65535 overflows Int32, and 16384
  // would otherwise produce a positive stride and allocate before the pixel
  // loop rejects it.
  let huge = rle8_dib_with_header(40, 100000, 1, 65535, 0, 0, [], [0x00, 0x01])
  guard dib_decode(huge, None) is None else {
    abort("a 65535-bpp DIB decoded")
  }
  let wide = rle8_dib_with_header(40, 100000, 1, 16384, 0, 0, [], [0x00, 0x01])
  guard dib_decode(wide, None) is None else {
    abort("a 16384-bpp DIB decoded")
  }
  // every bit depth outside 1, 4, 8, 16, 24 and 32 is rejected
  let unsupported : Array[Int32] = [0, 2, 3, 5, 7, 9, 15, 31, 33, 255]
  for bpp in unsupported {
    let colors = if bpp <= 8 { 1 << bpp } else { 0 }
    let palette : Array[(Int32, Int32, Int32)] = []
    for _ in 0..<colors {
      palette.push((0, 0, 0))
    }
    let data = rle8_dib_with_header(40, 1, 1, bpp, 0, 0, palette, [0x00, 0x01])
    guard dib_decode(data, None) is None else {
      abort("a \{bpp}-bpp DIB decoded")
    }
  }
  // a supported 24-bit DIB still reaches the pixel loop
  let rgb = rle8_dib_with_header(
    40,
    1,
    1,
    24,
    0,
    0,
    [],
    [0x10, 0x20, 0x30, 0x00],
  )
  let dib = rle8_decode_or_abort(rgb)
  rle8_expect(dib, 0, 0, 0x30, 0x20, 0x10)
}
