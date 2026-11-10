///|
/// A 2x2 24-bit BITMAPINFOHEADER.
fn dw_band_bmi() -> Bytes {
  let b = @buffer.Buffer()
  x_u32(b, 40) // biSize
  x_u32(b, 2) // biWidth
  x_u32(b, 2) // biHeight
  x_u16(b, 1) // biPlanes
  x_u16(b, 24) // biBitCount
  x_u32(b, 0) // biCompression
  x_u32(b, 16) // biSizeImage
  x_u32(b, 0) // biXPelsPerMeter
  x_u32(b, 0) // biYPelsPerMeter
  x_u32(b, 0) // biClrUsed
  x_u32(b, 0) // biClrImportant
  b.to_bytes()
}

///|
/// A kind 7 body: the BITMAPINFO, a band count, then each band's 12-byte
/// header (stored size, expanded size, rows) and stored bytes.
fn dw_band_dib(bands : Array[(Bytes, Int32, Int32)]) -> Bytes {
  let b = @buffer.Buffer()
  b.write_bytes(dw_band_bmi())
  x_u32(b, bands.length())
  for band in bands {
    let (stored, expanded, rows) = band
    x_u32(b, stored.length())
    x_u32(b, expanded)
    x_u32(b, rows)
    b.write_bytes(stored)
  }
  b.to_bytes()
}

///|
/// Append `n` bits of `v`, most significant first, to a bit list.
fn dw_band_bits(bits : Array[Bool], v : Int, n : Int) -> Unit {
  for i in 0..<n {
    bits.push(((v >> (n - 1 - i)) & 1) == 1)
  }
}

///|
/// Pack bits most significant first into bytes, padding the last byte.
fn dw_band_pack(bits : Array[Bool]) -> Bytes {
  let out = @buffer.Buffer()
  let mut i = 0
  while i < bits.length() {
    let mut v = 0
    for k in 0..<8 {
      v = v << 1
      if i + k < bits.length() && bits[i + k] {
        v = v | 1
      }
    }
    out.write_byte(v.to_byte())
    i += 8
  }
  out.to_bytes()
}

///|
/// A minimal `-lh5-` stream that expands to `count` copies of `value`: one
/// block whose literal table has a single symbol, so no code bits follow.
fn dw_band_lzh(value : Int, count : Int) -> Bytes {
  let bits : Array[Bool] = []
  dw_band_bits(bits, count, 16) // block size: one code per output byte
  dw_band_bits(bits, 0, 5) // pt table: a single symbol
  dw_band_bits(bits, 0, 5)
  dw_band_bits(bits, 0, 9) // literal table: a single symbol
  dw_band_bits(bits, value, 9)
  dw_band_bits(bits, 0, 4) // position table: a single symbol
  dw_band_bits(bits, 0, 4)
  dw_band_pack(bits)
}

///|
/// Draw one object and return the encoded page, the warnings and the stored
/// parts by hash.
fn dw_band_draw(
  doc : XdwDocument,
  obj : XdwObject,
) -> (Bytes, Array[String], Array[@core.SplitPart]) {
  let object = @core.ObjectBuilder::new()
  let writer = @core.DocumentWriter::new()
  let warnings : Array[String] = []
  doc.xdw_draw_object(obj, object, writer, warnings) catch {
    e => abort("draw failed: " + e.to_string())
  }
  let encoded = object.encode() catch {
    e => abort("encode failed: " + e.to_string())
  }
  let split = writer.write_split() catch {
    e => abort("split failed: " + e.to_string())
  }
  (encoded, warnings, split.parts)
}

///|
/// The number of image commands in an encoded page.
fn dw_band_images(encoded : Bytes) -> Int32 {
  let commands = @render.decode_commands(encoded) catch {
    e => abort("decode failed: " + e.to_string())
  }
  let mut images = 0
  for c in commands {
    match c {
      @render.Image(_, _, _, _, _) => images += 1
      _ => ()
    }
  }
  images
}

///|
/// The stored bytes of the first image the page draws.
fn dw_band_image(
  encoded : Bytes,
  parts : Array[@core.SplitPart],
) -> Bytes? {
  let commands = @render.decode_commands(encoded) catch {
    e => abort("decode failed: " + e.to_string())
  }
  for c in commands {
    match c {
      @render.Image(hash, _, _, _, _) =>
        for part in parts {
          if part.hash == hash {
            return Some(part.data)
          }
        }
      _ => ()
    }
  }
  None
}

///|
test "a kind 7 body with two bands draws the joined pixels" {
  let row0 = Bytes::make(8, b'\x10')
  let row1 = Bytes::make(8, b'\x20')
  let body = dw_band_dib([(row0, 8, 1), (row1, 8, 1)])
  let doc = x_doc([x_record_with_drawing(K_PICTURE, 7, body, false)], [])
  let (encoded, warnings, parts) = dw_band_draw(doc, x_object(0L))
  guard warnings.is_empty() else {
    abort("unexpected warnings: \{warnings.join(",")}")
  }
  let image = match dw_band_image(encoded, parts) {
    Some(value) => value
    None => abort("the two-band body drew no image")
  }
  let joined = @buffer.Buffer()
  joined.write_bytes(row0)
  joined.write_bytes(row1)
  let expected = match @metafile.dib_to_png_top_down(dw_band_bmi(), Some(joined.to_bytes())) {
    Some(value) => value
    None => abort("the joined bands did not encode")
  }
  guard image == expected else {
    abort("the drawn image is not the joined bands")
  }
}

///|
test "a kind 7 body with four bands draws one image" {
  let body = dw_band_dib([
    (Bytes::make(4, b'\x01'), 4, 1),
    (Bytes::make(4, b'\x02'), 4, 1),
    (Bytes::make(4, b'\x03'), 4, 1),
    (Bytes::make(4, b'\x04'), 4, 1),
  ])
  let doc = x_doc([x_record_with_drawing(K_PICTURE, 7, body, false)], [])
  let (encoded, warnings) = x_draw(doc, x_object(0L))
  guard warnings.is_empty() else {
    abort("unexpected warnings: \{warnings.join(",")}")
  }
  let images = dw_band_images(encoded)
  guard images == 1 else {
    abort("the four-band body drew \{images} images, not 1")
  }
}

///|
test "a kind 7 annotation body with two bands draws one image" {
  let body = dw_band_dib([
    (Bytes::make(8, b'\x10'), 8, 1),
    (Bytes::make(8, b'\x20'), 8, 1),
  ])
  let doc = x_doc([x_record_with_drawing(K_PICTURE, 7, body, true)], [])
  let (encoded, warnings) = x_draw(doc, x_object(0L))
  guard warnings.is_empty() else {
    abort("unexpected warnings: \{warnings.join(",")}")
  }
  let images = dw_band_images(encoded)
  guard images == 1 else {
    abort("the annotation body drew \{images} images, not 1")
  }
}

///|
test "a malformed second band is reported and draws nothing" {
  let body = dw_band_dib([
    (Bytes::make(8, b'\x10'), 8, 1),
    (b"\xff\xff\xff\xff"[:].to_owned(), 8, 1),
  ])
  let doc = x_doc([x_record_with_drawing(K_PICTURE, 7, body, false)], [])
  let (encoded, warnings) = x_draw(doc, x_object(0L))
  guard warnings.length() == 1 else {
    abort(
      "expected one warning, got \{warnings.length()}: \{warnings.join(",")}",
    )
  }
  guard warnings[0].contains("not readable") else {
    abort("unexpected warning: \{warnings[0]}")
  }
  let images = dw_band_images(encoded)
  guard images == 0 else { abort("a malformed band drew \{images} images") }
}

///|
test "a kind 7 body with a truncated band list is reported" {
  let b = @buffer.Buffer()
  b.write_bytes(dw_band_bmi())
  x_u32(b, 2) // two bands claimed
  x_u32(b, 8) // one header only
  x_u32(b, 8)
  x_u32(b, 1)
  b.write_bytes(Bytes::make(8, b'\x10'))
  let doc = x_doc([x_record_with_drawing(K_PICTURE, 7, b.to_bytes(), false)], [])
  let (encoded, warnings) = x_draw(doc, x_object(0L))
  guard warnings.length() == 1 && warnings[0].contains("not readable") else {
    abort("a truncated band list was not reported: \{warnings.join(",")}")
  }
  let images = dw_band_images(encoded)
  guard images == 0 else {
    abort("a truncated band list drew \{images} images")
  }
}

///|
test "a minimal LZH stream expands to its literal" {
  let stream = dw_band_lzh(0x41, 8)
  let out = lzh_decompress(stream, 8, Limits::default()) catch {
    e => abort("the minimal stream did not expand: " + e.to_string())
  }
  guard out == Bytes::make(8, b'\x41') else {
    abort("the minimal stream expanded to the wrong bytes")
  }
}

///|
test "a kind 7 body with two compressed bands draws the joined pixels" {
  let row0 = Bytes::make(8, b'\x10')
  let row1 = Bytes::make(8, b'\x20')
  let body = dw_band_dib([
    (dw_band_lzh(0x10, 8), 8, 1),
    (dw_band_lzh(0x20, 8), 8, 1),
  ])
  let doc = x_doc([x_record_with_drawing(K_PICTURE, 7, body, false)], [])
  let (encoded, warnings, parts) = dw_band_draw(doc, x_object(0L))
  guard warnings.is_empty() else {
    abort("unexpected warnings: \{warnings.join(",")}")
  }
  let image = match dw_band_image(encoded, parts) {
    Some(value) => value
    None => abort("the compressed body drew no image")
  }
  let joined = @buffer.Buffer()
  joined.write_bytes(row0)
  joined.write_bytes(row1)
  let expected = match @metafile.dib_to_png_top_down(dw_band_bmi(), Some(joined.to_bytes())) {
    Some(value) => value
    None => abort("the joined bands did not encode")
  }
  guard image == expected else {
    abort("the compressed bands did not join")
  }
}

///|
test "a kind 7 body with zero-expanded bands draws the stored bytes" {
  let row0 = Bytes::make(8, b'\x10')
  let row1 = Bytes::make(8, b'\x20')
  let body = dw_band_dib([(row0, 0, 1), (row1, 0, 1)])
  let doc = x_doc([x_record_with_drawing(K_PICTURE, 7, body, false)], [])
  let (encoded, warnings, parts) = dw_band_draw(doc, x_object(0L))
  guard warnings.is_empty() else {
    abort("unexpected warnings: \{warnings.join(",")}")
  }
  let image = match dw_band_image(encoded, parts) {
    Some(value) => value
    None => abort("the zero-expanded body drew no image")
  }
  let joined = @buffer.Buffer()
  joined.write_bytes(row0)
  joined.write_bytes(row1)
  let expected = match @metafile.dib_to_png_top_down(dw_band_bmi(), Some(joined.to_bytes())) {
    Some(value) => value
    None => abort("the joined bands did not encode")
  }
  guard image == expected else {
    abort("the zero-expanded bands did not join")
  }
}

///|
/// The first image command of an encoded page: (hash, x, y, w, h).
fn dw_band_image_command(
  encoded : Bytes,
) -> (String, Double, Double, Double, Double)? {
  let commands = @render.decode_commands(encoded) catch {
    e => abort("decode failed: " + e.to_string())
  }
  for c in commands {
    match c {
      @render.Image(hash, x, y, w, h) => return Some((hash, x, y, w, h))
      _ => ()
    }
  }
  None
}

///|
/// The same object box as `x_object`, with the object kind under test.
fn x_object_kind(kind : Int64, rotation : Int64) -> XdwObject {
  let obj = x_object(rotation)
  {
    place: obj.place,
    record: obj.record,
    kind,
    x: obj.x,
    y: obj.y,
    w: obj.w,
    h: obj.h,
    rotation: obj.rotation,
    text: obj.text,
  }
}

///|
test "a kind 7 body draws its bands top-down at the annotation box" {
  // two 2-pixel rows: red on top, blue below, as the kind 7 body stores them
  let row0 = b"\x00\x00\xff\x00\x00\xff\x00\x00"[:].to_owned()
  let row1 = b"\xff\x00\x00\xff\x00\x00\x00\x00"[:].to_owned()
  let body = dw_band_dib([(row0, 8, 1), (row1, 8, 1)])
  let doc = x_doc([x_record_with_drawing(K_PICTURE, 7, body, true)], [])
  let (encoded, warnings, parts) = dw_band_draw(doc, x_object_kind(K_PICTURE, 0L))
  guard warnings.is_empty() else {
    abort("unexpected warnings: \{warnings.join(",")}")
  }
  let (hash, x, y, w, h) = match dw_band_image_command(encoded) {
    Some(value) => value
    None => abort("the annotation body drew no image")
  }
  // the object is at 100,200 with a 300x400 box at 1/100 mm
  guard x_close(x, 2.8346) && x_close(y, 5.6693) && x_close(w, 8.5039) && x_close(h, 11.3386) else {
    abort("the image is placed at \{x},\{y} size \{w}x\{h}")
  }
  let image = match dw_band_image(encoded, parts) {
    Some(value) => value
    None => abort("the image part is missing")
  }
  let joined = @buffer.Buffer()
  joined.write_bytes(row0)
  joined.write_bytes(row1)
  let expected = match @metafile.dib_to_png_top_down(dw_band_bmi(), Some(joined.to_bytes())) {
    Some(value) => value
    None => abort("the joined bands did not encode")
  }
  guard image == expected else {
    abort("the drawn image is not the top-down joined bands")
  }
  // the generic reading would flip these asymmetric rows
  let flipped = match @metafile.dib_to_png(dw_band_bmi(), Some(joined.to_bytes())) {
    Some(value) => value
    None => abort("the generic joined bands did not encode")
  }
  guard image != flipped else {
    abort("the kind 7 image still uses the generic bottom-up reading")
  }
  ignore(hash)
}

///|
test "a kind 7 page content body keeps the generic bottom-up reading" {
  // the same asymmetric rows: red on top, blue below, as the body stores them
  let row0 = b"\x00\x00\xff\x00\x00\xff\x00\x00"[:].to_owned()
  let row1 = b"\xff\x00\x00\xff\x00\x00\x00\x00"[:].to_owned()
  let body = dw_band_dib([(row0, 8, 1), (row1, 8, 1)])
  let joined = @buffer.Buffer()
  joined.write_bytes(row0)
  joined.write_bytes(row1)
  let generic = match @metafile.dib_to_png(dw_band_bmi(), Some(joined.to_bytes())) {
    Some(value) => value
    None => abort("the generic joined bands did not encode")
  }
  let top_down = match @metafile.dib_to_png_top_down(dw_band_bmi(), Some(joined.to_bytes())) {
    Some(value) => value
    None => abort("the top-down joined bands did not encode")
  }
  guard generic != top_down else {
    abort("the two readings are the same")
  }
  for kind in [K_CONTENT, K_PAGEFORM] {
    let doc = x_doc([x_record_with_drawing(kind, 7, body, false)], [])
    let (encoded, warnings, parts) = dw_band_draw(doc, x_object_kind(kind, 0L))
    guard warnings.is_empty() else {
      abort("unexpected warnings: \{warnings.join(",")}")
    }
    let image = match dw_band_image(encoded, parts) {
      Some(value) => value
      None => abort("the page body drew no image")
    }
    guard image == generic else {
      abort("a kind 7 page body did not keep the generic bottom-up reading")
    }
    guard image != top_down else {
      abort("a kind 7 page body used the annotation top-down reading")
    }
  }
}
