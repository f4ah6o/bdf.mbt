///|
fn small_font() -> Bytes {
  let data = Bytes::make(34, 0).to_array()
  data[1] = 1
  data[5] = 1
  data[12] = b'm'
  data[13] = b'a'
  data[14] = b'x'
  data[15] = b'p'
  data[23] = 28
  data[27] = 6
  data[29] = 1
  data[33] = 2
  Bytes::from_array(data)
}

///|
test "load and select a font face" {
  let file = load(small_font())
  assert_eq(file.faces().length(), 1)
  assert_eq(file.faces()[0].font.metrics.glyph_count, 2)
  let (faces, warnings) = file.select("1,1")
  assert_eq(faces.length(), 2)
  assert_eq(warnings.length(), 0)
  let error = try {
    ignore(file.select("2"))
    ""
  } catch {
    InvalidFontInput(message) => message
    _ => "unexpected error"
  }
  assert_eq(error, "font: parameter font: the file has no font 2")
}

///|
test "WOFF2 validates its directory and Brotli stream" {
  let short = b"wOF2"
  let short_error = try {
    ignore(load(short))
    ""
  } catch {
    InvalidFontInput(message) => message
    _ => "unexpected error"
  }
  assert_eq(short_error, "font: woff2: not a WOFF2 font")
  let data = Bytes::make(50, 0).to_array()
  data[0] = b'w'
  data[1] = b'O'
  data[2] = b'F'
  data[3] = b'2'
  data[5] = 1
  data[13] = 1
  data[48] = 4
  data[49] = 3
  let error = try {
    ignore(load(Bytes::from_array(data)))
    ""
  } catch {
    InvalidFontInput(message) => message
    _ => "unexpected error"
  }
  assert_eq(error, "font: brotli: truncated input")
}
