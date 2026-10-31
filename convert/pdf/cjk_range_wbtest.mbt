///|
fn pdf_cjk_test_code(form : Int32, key : Int64) -> Int64 {
  if form == 1 && key > 0xffffL && key <= 0x10ffffL {
    let value = key - 0x10000L
    return ((0xd800L + (value >> 10)) << 16) | (0xdc00L + (value & 0x3ffL))
  }
  if form != 2 || key > 0x10ffffL {
    return key
  }
  let code = if key >= 0xd800L && key <= 0xdfffL { 0xfffdL } else { key }
  if code < 0x80L {
    return code
  }
  if code < 0x800L {
    return ((0xc0L | (code >> 6)) << 8) | (0x80L | (code & 0x3fL))
  }
  if code < 0x10000L {
    return ((0xe0L | (code >> 12)) << 16) |
      ((0x80L | ((code >> 6) & 0x3fL)) << 8) |
      (0x80L | (code & 0x3fL))
  }
  ((0xf0L | (code >> 18)) << 24) |
  ((0x80L | ((code >> 12) & 0x3fL)) << 16) |
  ((0x80L | ((code >> 6) & 0x3fL)) << 8) |
  (0x80L | (code & 0x3fL))
}

///|
fn pdf_cjk_range_digest(name : String) -> UInt64 {
  let map = pdf_cjk_maps.get(name).unwrap()
  let mut digest = 14695981039346656037UL
  for range in map.ranges {
    let previous = if range.low > 0L { range.low - 1L } else { range.low }
    let next = if range.high < 0xffffffffL {
      range.high + 1L
    } else {
      range.high
    }
    for
      key in [
        previous,
        range.low,
        range.low + (range.high - range.low) / 2L,
        range.high,
        next,
      ] {
      let code = pdf_cjk_test_code(map.form, key)
      digest = (digest ^ code.reinterpret_as_uint64()) * 1099511628211UL
      let value = match pdf_cjk_cid(name, code, 0) {
        Some(cid) => cid.reinterpret_as_uint64() + 1UL
        None => 0UL
      }
      digest = (digest ^ value) * 1099511628211UL
    }
  }
  digest
}
