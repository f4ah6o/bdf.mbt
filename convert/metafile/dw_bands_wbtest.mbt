///|
/// Little-endian u16 into a buffer.
fn dw_band_u16(b : @buffer.Buffer, v : Int32) -> Unit {
  b.write_byte((v & 0xff).to_byte())
  b.write_byte(((v >> 8) & 0xff).to_byte())
}

///|
/// Little-endian u32 into a buffer.
fn dw_band_u32(b : @buffer.Buffer, v : Int32) -> Unit {
  b.write_byte((v & 0xff).to_byte())
  b.write_byte(((v >> 8) & 0xff).to_byte())
  b.write_byte(((v >> 16) & 0xff).to_byte())
  b.write_byte(((v >> 24) & 0xff).to_byte())
}

///|
/// A 40-byte BITMAPINFOHEADER for a 24-bit picture.
fn dw_band_bmi(width : Int32, height : Int32) -> @buffer.Buffer {
  let b = @buffer.Buffer()
  dw_band_u32(b, 40) // biSize
  dw_band_u32(b, width) // biWidth
  dw_band_u32(b, height) // biHeight
  dw_band_u16(b, 1) // biPlanes
  dw_band_u16(b, 24) // biBitCount
  dw_band_u32(b, 0) // biCompression
  dw_band_u32(b, width * height * 3) // biSizeImage
  dw_band_u32(b, 0) // biXPelsPerMeter
  dw_band_u32(b, 0) // biYPelsPerMeter
  dw_band_u32(b, 0) // biClrUsed
  dw_band_u32(b, 0) // biClrImportant
  b
}

///|
/// A kind 7 body: the BITMAPINFO, a band count, then each band's 12-byte
/// header (stored size, expanded size, rows) and stored bytes.
fn dw_band_body(bands : Array[(Bytes, Int32, Int32)]) -> Bytes {
  let b = dw_band_bmi(2, 2)
  dw_band_u32(b, bands.length())
  for band in bands {
    let (stored, expanded, rows) = band
    dw_band_u32(b, stored.length())
    dw_band_u32(b, expanded)
    dw_band_u32(b, rows)
    b.write_bytes(stored)
  }
  b.to_bytes()
}

///|
test "one band keeps its stored bytes and expanded size" {
  let stored = b"\x01\x02\x03\x04"[:].to_owned()
  let body = dw_band_body([(stored, 4, 1)])
  let (bmi, bands) = match dib_body_bands(body) {
    Some(value) => value
    None => abort("the single-band body did not split")
  }
  guard bmi == dw_band_bmi(2, 2).to_bytes() else {
    abort("the BITMAPINFO changed")
  }
  guard bands.length() == 1 else {
    abort("the body split into \{bands.length()} bands, not 1")
  }
  let (band_stored, band_expanded) = bands[0]
  guard band_stored == stored else { abort("the stored bytes changed") }
  guard band_expanded == 4 else {
    abort("the expanded size is \{band_expanded}, not 4")
  }
}

///|
test "four bands come back in order" {
  let body = dw_band_body([
    (b"\x01"[:].to_owned(), 1, 1),
    (b"\x02\x03"[:].to_owned(), 2, 1),
    (b"\x04\x05\x06"[:].to_owned(), 3, 1),
    (b"\x07\x08\x09\x0a"[:].to_owned(), 4, 1),
  ])
  let (_, bands) = match dib_body_bands(body) {
    Some(value) => value
    None => abort("the four-band body did not split")
  }
  guard bands.length() == 4 else {
    abort("the body split into \{bands.length()} bands, not 4")
  }
  let joined = @buffer.Buffer()
  let mut expanded_total = 0
  for band in bands {
    let (stored, expanded) = band
    joined.write_bytes(stored)
    expanded_total += expanded
  }
  guard joined.to_bytes() ==
    b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a"[:].to_owned() else {
    abort("the bands did not join in order")
  }
  guard expanded_total == 10 else {
    abort("the expanded sizes add up to \{expanded_total}, not 10")
  }
}

///|
test "a zero or oversized band count is refused" {
  let bmi = dw_band_bmi(2, 2).to_bytes()
  // a count of zero
  let zero = @buffer.Buffer()
  zero.write_bytes(bmi)
  dw_band_u32(zero, 0)
  guard dib_body_bands(zero.to_bytes()) is None else {
    abort("a zero count split")
  }
  // a count of 0xffffffff
  let huge = @buffer.Buffer()
  huge.write_bytes(bmi)
  dw_band_u32(huge, -1)
  guard dib_body_bands(huge.to_bytes()) is None else {
    abort("a huge count split")
  }
  // a count past the cap
  let capped = @buffer.Buffer()
  capped.write_bytes(bmi)
  dw_band_u32(capped, 4097)
  guard dib_body_bands(capped.to_bytes()) is None else {
    abort("a count past the cap split")
  }
  // a count with fewer headers than it claims
  let short = @buffer.Buffer()
  short.write_bytes(bmi)
  dw_band_u32(short, 5)
  dw_band_u32(short, 0)
  dw_band_u32(short, 0)
  dw_band_u32(short, 0)
  guard dib_body_bands(short.to_bytes()) is None else {
    abort("a count with too few headers split")
  }
}

///|
test "a stored size past the end is refused" {
  let b = dw_band_bmi(2, 2)
  dw_band_u32(b, 1)
  dw_band_u32(b, 100) // stored
  dw_band_u32(b, 100) // expanded
  dw_band_u32(b, 1) // rows
  b.write_bytes(b"\x01\x02\x03\x04"[:])
  guard dib_body_bands(b.to_bytes()) is None else {
    abort("a stored size past the end split")
  }
}

///|
test "a truncated band header is refused" {
  let b = dw_band_bmi(2, 2)
  dw_band_u32(b, 2)
  dw_band_u32(b, 0)
  dw_band_u32(b, 0)
  dw_band_u32(b, 0)
  // the second header is missing
  guard dib_body_bands(b.to_bytes()) is None else {
    abort("a truncated header split")
  }
}

///|
test "an expanded size past the cap is refused" {
  let b = dw_band_bmi(2, 2)
  dw_band_u32(b, 1)
  dw_band_u32(b, 0) // stored
  dw_band_u32(b, 268435457) // 256 MiB + 1
  dw_band_u32(b, 1) // rows
  guard dib_body_bands(b.to_bytes()) is None else {
    abort("an expanded size past the cap split")
  }
}

///|
test "the bands of one picture share the expanded cap" {
  let b = dw_band_bmi(2, 2)
  dw_band_u32(b, 2)
  for _ in 0..<2 {
    dw_band_u32(b, 0) // stored
    dw_band_u32(b, 209715200) // 200 MiB
    dw_band_u32(b, 1) // rows
  }
  guard dib_body_bands(b.to_bytes()) is None else {
    abort("two bands past the shared cap split")
  }
}

///|
test "a zero-expanded band counts its stored bytes against the cap" {
  // a stored band (expanded 0) contributes its stored bytes, not zero
  guard dib_band_output_size(4L, 0L) == 4L else {
    abort("a zero-expanded band counted as zero")
  }
  guard dib_band_output_size(4L, 4L) == 4L else {
    abort("a stored band counted wrong")
  }
  guard dib_band_output_size(7L, 8L) == 8L else {
    abort("a compressed band counted its stored size")
  }
  // the caps are checked without allocating the bytes
  let cap = MAX_DIB_BAND_BYTES
  guard dib_band_sizes_ok(cap, cap, 0L, 0L) else {
    abort("a band exactly at the cap was refused")
  }
  guard !dib_band_sizes_ok(cap + 1L, cap + 1L, 0L, 0L) else {
    abort("a band past the cap was accepted")
  }
  guard !dib_band_sizes_ok(1L, 1L, cap, 0L) else {
    abort("a band past the output total was accepted")
  }
  guard !dib_band_sizes_ok(1L, 1L, 0L, cap) else {
    abort("a band past the stored total was accepted")
  }
  // 300 MiB stored with expanded 0 is 300 MiB of output, not zero
  let large = 300L << 20
  guard !dib_band_sizes_ok(dib_band_output_size(large, 0L), large, 0L, 0L) else {
    abort("a zero-expanded band past the cap was accepted")
  }
}

///|
test "a zero-expanded band is stored, not compressed" {
  let body = dw_band_body([
    (b"\x01\x02"[:].to_owned(), 0, 1),
    (b"\x03\x04"[:].to_owned(), 0, 1),
  ])
  let (_, bands) = match dib_body_bands(body) {
    Some(value) => value
    None => abort("the zero-expanded body did not split")
  }
  guard bands.length() == 2 else {
    abort("the body split into \{bands.length()} bands, not 2")
  }
  let (first, first_expanded) = bands[0]
  guard first == b"\x01\x02"[:].to_owned() && first_expanded == 0 else {
    abort("the first zero-expanded band changed")
  }
  let (second, second_expanded) = bands[1]
  guard second == b"\x03\x04"[:].to_owned() && second_expanded == 0 else {
    abort("the second zero-expanded band changed")
  }
}

///|
test "a malformed LZH band is returned as stored and does not decode" {
  let garbage = b"\xff\xff\xff\xff"[:].to_owned()
  let body = dw_band_body([(garbage, 16, 2)])
  let (bmi, bands) = match dib_body_bands(body) {
    Some(value) => value
    None => abort("the malformed band did not split")
  }
  guard bands.length() == 1 else {
    abort("the body split into \{bands.length()} bands, not 1")
  }
  let (stored, expanded) = bands[0]
  guard stored == garbage && expanded == 16 else {
    abort("the malformed band changed")
  }
  // the caller hands the stored bytes to the LZH decoder; the DIB decoder
  // refuses them because they are shorter than one row
  guard dib_to_png(bmi, Some(stored)) is None else {
    abort("a malformed band decoded")
  }
}

///|
test "dib_body_split keeps the first band of a multi-band body" {
  let first = b"\x01\x02"[:].to_owned()
  let second = b"\x03\x04\x05"[:].to_owned()
  let body = dw_band_body([(first, 2, 1), (second, 3, 1)])
  let (bmi, stored, stored_len, expanded) = match dib_body_split(body) {
    Some(value) => value
    None => abort("the two-band body did not split")
  }
  guard bmi == dw_band_bmi(2, 2).to_bytes() else {
    abort("the BITMAPINFO changed")
  }
  guard stored == first else { abort("the first band changed") }
  guard stored_len == 2 && expanded == 2 else {
    abort("the first band sizes are \{stored_len} and \{expanded}, not 2 and 2")
  }
}

///|
test "a body without a band count is refused" {
  guard dib_body_bands(dw_band_bmi(2, 2).to_bytes()) is None else {
    abort("a body without a count split")
  }
  guard dib_body_bands(Bytes::make(0, b'\x00')) is None else {
    abort("an empty body split")
  }
}

///|
test "a BITMAPINFOHEADER with a huge biSize is refused without a read" {
  // biSize 0x7fffffff: dib_bits_offset returns it as a large positive
  // offset, and the old `n + 4` check wrapped to a negative number
  let b = @buffer.Buffer()
  dw_band_u32(b, 0x7fffffff) // biSize
  dw_band_u32(b, 2) // biWidth
  dw_band_u32(b, 2) // biHeight
  dw_band_u16(b, 1) // biPlanes
  dw_band_u16(b, 24) // biBitCount
  dw_band_u32(b, 0) // biCompression
  dw_band_u32(b, 16) // biSizeImage
  dw_band_u32(b, 0) // biXPelsPerMeter
  dw_band_u32(b, 0) // biYPelsPerMeter
  dw_band_u32(b, 0) // biClrUsed
  dw_band_u32(b, 0) // biClrImportant
  guard dib_body_bands(b.to_bytes()) is None else {
    abort("a huge biSize split")
  }
}

///|
test "a BITMAPINFOHEADER with a huge biClrUsed is refused without a read" {
  // biClrUsed 0x1ffffff5: 8-bit colours make the offset 0x7ffffffc, and
  // the old `n + 4` check wrapped to a negative number
  let b = @buffer.Buffer()
  dw_band_u32(b, 40) // biSize
  dw_band_u32(b, 2) // biWidth
  dw_band_u32(b, 2) // biHeight
  dw_band_u16(b, 1) // biPlanes
  dw_band_u16(b, 8) // biBitCount
  dw_band_u32(b, 0) // biCompression
  dw_band_u32(b, 16) // biSizeImage
  dw_band_u32(b, 0) // biXPelsPerMeter
  dw_band_u32(b, 0) // biYPelsPerMeter
  dw_band_u32(b, 0x1ffffff5) // biClrUsed
  dw_band_u32(b, 0) // biClrImportant
  guard dib_body_bands(b.to_bytes()) is None else {
    abort("a huge biClrUsed split")
  }
}

///|
/// A 40-byte BITMAPINFOHEADER with a palette of (red, green, blue) entries.
fn dw_band_bmi_paletted(
  width : Int32,
  height : Int32,
  bpp : Int32,
  palette : Array[(Int32, Int32, Int32)],
) -> @buffer.Buffer {
  let b = @buffer.Buffer()
  dw_band_u32(b, 40) // biSize
  dw_band_u32(b, width) // biWidth
  dw_band_u32(b, height) // biHeight
  dw_band_u16(b, 1) // biPlanes
  dw_band_u16(b, bpp) // biBitCount
  dw_band_u32(b, 0) // biCompression
  dw_band_u32(b, 0) // biSizeImage
  dw_band_u32(b, 0) // biXPelsPerMeter
  dw_band_u32(b, 0) // biYPelsPerMeter
  dw_band_u32(b, palette.length()) // biClrUsed
  dw_band_u32(b, 0) // biClrImportant
  for (red, green, blue) in palette {
    b.write_byte(blue.to_byte())
    b.write_byte(green.to_byte())
    b.write_byte(red.to_byte())
    b.write_byte(0)
  }
  b
}

///|
/// One RGBA pixel of a decoded DIB.
fn dw_band_pixel(dib : Dib, x : Int32, y : Int32) -> (Int32, Int32, Int32, Int32) {
  let at = (y * dib.width + x) * 4
  (
    dib.rgba[at].to_int(),
    dib.rgba[at + 1].to_int(),
    dib.rgba[at + 2].to_int(),
    dib.rgba[at + 3].to_int(),
  )
}

///|
fn dw_band_expect(
  dib : Dib,
  x : Int32,
  y : Int32,
  red : Int32,
  green : Int32,
  blue : Int32,
) -> Unit {
  let (r, g, b, a) = dw_band_pixel(dib, x, y)
  guard r == red && g == green && b == blue && a == 255 else {
    abort(
      "pixel (\{x},\{y}) is (\{r},\{g},\{b},\{a}), not (\{red},\{green},\{blue},255)",
    )
  }
}

///|
/// Two 24-bit rows: red on top, blue below, as a kind 7 body stores them.
fn dw_band_red_blue_bits() -> Bytes {
  b"\x00\x00\xff\x00\x00\xff\x00\x00\xff\x00\x00\xff\x00\x00\x00\x00"[:].to_owned()
}

///|
test "kind 7 top-down reads a positive height as stored rows" {
  let bmi = dw_band_bmi(2, 2).to_bytes()
  let bits = dw_band_red_blue_bits()
  let bmi_before = bmi[0:bmi.length()].to_owned()
  let bits_before = bits[0:bits.length()].to_owned()
  let top = match dib_decode_top_down(bmi, Some(bits)) {
    Some(value) => value
    None => abort("the kind 7 DIB did not decode top-down")
  }
  dw_band_expect(top, 0, 0, 255, 0, 0)
  dw_band_expect(top, 1, 0, 255, 0, 0)
  dw_band_expect(top, 0, 1, 0, 0, 255)
  dw_band_expect(top, 1, 1, 0, 0, 255)
  // the generic reading still treats a positive height as bottom-up
  let generic = match dib_decode(bmi, Some(bits)) {
    Some(value) => value
    None => abort("the generic DIB did not decode")
  }
  dw_band_expect(generic, 0, 0, 0, 0, 255)
  dw_band_expect(generic, 0, 1, 255, 0, 0)
  guard bmi == bmi_before && bits == bits_before else {
    abort("decoding changed the input bytes")
  }
}

///|
test "kind 7 top-down keeps a negative height top-down" {
  let bmi = dw_band_bmi(2, -2).to_bytes()
  let bits = dw_band_red_blue_bits()
  let top = match dib_decode_top_down(bmi, Some(bits)) {
    Some(value) => value
    None => abort("the negative-height kind 7 DIB did not decode")
  }
  dw_band_expect(top, 0, 0, 255, 0, 0)
  dw_band_expect(top, 0, 1, 0, 0, 255)
  // a negative height already means top-down for the generic reading too
  let generic = match dib_decode(bmi, Some(bits)) {
    Some(value) => value
    None => abort("the negative-height generic DIB did not decode")
  }
  dw_band_expect(generic, 0, 0, 255, 0, 0)
  dw_band_expect(generic, 0, 1, 0, 0, 255)
}

///|
test "kind 7 top-down reads a paletted positive height as stored rows" {
  let bmi = dw_band_bmi_paletted(
    2,
    2,
    8,
    [(0, 0, 0), (0, 255, 0), (255, 0, 0)],
  ).to_bytes()
  // row 0 index 1 (green), row 1 index 2 (red), each padded to 4 bytes
  let bits = b"\x01\x01\x00\x00\x02\x02\x00\x00"[:].to_owned()
  let top = match dib_decode_top_down(bmi, Some(bits)) {
    Some(value) => value
    None => abort("the paletted kind 7 DIB did not decode top-down")
  }
  dw_band_expect(top, 0, 0, 0, 255, 0)
  dw_band_expect(top, 1, 0, 0, 255, 0)
  dw_band_expect(top, 0, 1, 255, 0, 0)
  dw_band_expect(top, 1, 1, 255, 0, 0)
  let generic = match dib_decode(bmi, Some(bits)) {
    Some(value) => value
    None => abort("the paletted generic DIB did not decode")
  }
  dw_band_expect(generic, 0, 0, 255, 0, 0)
  dw_band_expect(generic, 0, 1, 0, 255, 0)
}

///|
test "kind 7 top-down refuses malformed and out-of-range DIBs" {
  let bmi = dw_band_bmi(2, 2).to_bytes()
  // one row short
  guard dib_decode_top_down(bmi, Some(Bytes::make(6, b'\x00'))) is None else {
    abort("a truncated kind 7 DIB decoded")
  }
  // a palette index outside the declared table
  let paletted = dw_band_bmi_paletted(
    2,
    2,
    8,
    [(0, 0, 0), (0, 255, 0), (255, 0, 0)],
  ).to_bytes()
  guard dib_decode_top_down(
    paletted,
    Some(b"\x03\x03\x00\x00\x00\x00\x00\x00"[:].to_owned()),
  ) is None else {
    abort("an out-of-range palette index decoded")
  }
  // zero and oversized heights
  guard dib_decode_top_down(dw_band_bmi(2, 0).to_bytes(), Some(Bytes::make(12, b'\x00'))) is None else {
    abort("a zero height decoded")
  }
  guard dib_decode_top_down(dw_band_bmi(2, 100001).to_bytes(), Some(Bytes::make(12, b'\x00'))) is None else {
    abort("an oversized height decoded")
  }
  guard dib_decode_top_down(dw_band_bmi(2, -100001).to_bytes(), Some(Bytes::make(12, b'\x00'))) is None else {
    abort("an oversized negative height decoded")
  }
  // an unsupported bit depth
  guard dib_decode_top_down(dw_band_bmi_paletted(2, 2, 7, []).to_bytes(), Some(Bytes::make(12, b'\x00'))) is None else {
    abort("a 7-bit DIB decoded")
  }
}

///|
test "the generic DIB reading keeps bottom-up rows and the kind 7 reading differs" {
  let bmi = dw_band_bmi(2, 2).to_bytes()
  let bits = dw_band_red_blue_bits()
  let bottom_up = Bytes::from_array(
    FixedArray::from_array([
      0, 0, 255, 255, 0, 0, 255, 255, // row 0 blue
      255, 0, 0, 255, 255, 0, 0, 255, // row 1 red
    ].map((v) => v.to_byte())),
  )
  let top_down = Bytes::from_array(
    FixedArray::from_array([
      255, 0, 0, 255, 255, 0, 0, 255, // row 0 red
      0, 0, 255, 255, 0, 0, 255, 255, // row 1 blue
    ].map((v) => v.to_byte())),
  )
  let generic = match dib_to_png(bmi, Some(bits)) {
    Some(value) => value
    None => abort("the generic DIB did not encode")
  }
  let expected_generic = @raster.encode_png(2, 2, bottom_up) catch {
    _ => abort("the bottom-up reference did not encode")
  }
  guard generic == expected_generic else {
    abort("the generic DIB reading changed")
  }
  let kind7 = match dib_to_png_top_down(bmi, Some(bits)) {
    Some(value) => value
    None => abort("the kind 7 DIB did not encode")
  }
  let expected_kind7 = @raster.encode_png(2, 2, top_down) catch {
    _ => abort("the top-down reference did not encode")
  }
  guard kind7 == expected_kind7 else {
    abort("the kind 7 DIB is not top-down")
  }
  guard kind7 != generic else {
    abort("the kind 7 and generic readings are the same")
  }
}

///|
test "kind 7 top-down leaves BI_RLE8 orientation alone" {
  let data = rle8_dib(
    2,
    2,
    [(0, 0, 0), (255, 0, 0), (0, 255, 0)],
    [0x02, 0x01, 0x00, 0x00, 0x02, 0x02, 0x00, 0x01],
  )
  let generic = match dib_to_png(data, None) {
    Some(value) => value
    None => abort("the RLE8 DIB did not encode")
  }
  let kind7 = match dib_to_png_top_down(data, None) {
    Some(value) => value
    None => abort("the RLE8 kind 7 DIB did not encode")
  }
  guard kind7 == generic else {
    abort("the kind 7 reading changed BI_RLE8 orientation")
  }
}
