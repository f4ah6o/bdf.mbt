///|
// Convert a packed character code to the key used by a predefined CMap.
fn PdfCjkMap::key(self : PdfCjkMap, code : Int64) -> Int64? {
  if self.form == 1 {
    if code > 0xffffL {
      let high = (code >> 16).to_int()
      let low = (code & 0xffffL).to_int()
      if high < 0xd800 || high > 0xdbff || low < 0xdc00 || low > 0xdfff {
        return None
      }
      return Some((0x10000 + ((high - 0xd800) << 10) + low - 0xdc00).to_int64())
    }
    if code >= 0xd800L && code <= 0xdfffL {
      return None
    }
    return Some(code)
  }
  if self.form != 2 {
    return Some(code)
  }
  let size = if code <= 0xffL {
    1
  } else if code <= 0xffffL {
    2
  } else if code <= 0xffffffL {
    3
  } else {
    4
  }
  let first = ((code >> ((size - 1) * 8)) & 0xffL).to_int()
  let mut value = if size == 1 {
    first
  } else if size == 2 {
    first & 0x1f
  } else if size == 3 {
    first & 0x0f
  } else {
    first & 0x07
  }
  if (size == 1 && first >= 0x80) ||
    (size == 2 && (first < 0xc2 || first > 0xdf)) ||
    (size == 3 && (first < 0xe0 || first > 0xef)) ||
    (size == 4 && (first < 0xf0 || first > 0xf4)) {
    return None
  }
  for i in 1..<size {
    let byte = ((code >> ((size - 1 - i) * 8)) & 0xffL).to_int()
    if byte < 0x80 || byte > 0xbf {
      return None
    }
    value = (value << 6) | (byte & 0x3f)
  }
  if (size == 2 && value < 0x80) ||
    (size == 3 && value < 0x800) ||
    (size == 4 && value < 0x10000) ||
    value > 0x10ffff ||
    (value >= 0xd800 && value <= 0xdfff) ||
    value == 0xfffd {
    return None
  }
  Some(value.to_int64())
}

///|
fn pdf_cjk_cid(name : String, code : Int64, depth : Int32) -> Int64? {
  if depth > 8 {
    return None
  }
  let map = match pdf_cjk_maps.get(name) {
    Some(value) => value
    None => return None
  }
  let key = match map.key(code) {
    Some(value) => value
    None => return None
  }
  let mut low = 0
  let mut high = map.ranges.length()
  while low < high {
    let middle = low + (high - low) / 2
    if map.ranges[middle].high < key {
      low = middle + 1
    } else {
      high = middle
    }
  }
  if low < map.ranges.length() && map.ranges[low].low <= key {
    let range = map.ranges[low]
    return Some((range.cid + key - range.low) & 0xffffffffL)
  }
  if !map.base.is_empty() {
    match pdf_cjk_cid(map.base, key, depth + 1) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  if !map.parent.is_empty() {
    return pdf_cjk_cid(map.parent, code, depth + 1)
  }
  None
}

///|
fn PdfCjkMap::code_point(self : PdfCjkMap, code : Int64) -> Int64? {
  if !self.name.has_prefix("Uni") {
    return None
  }
  if self.form == 0 {
    if !self.name.contains("-UTF32-") {
      if code > 0xffffL {
        let high = (code >> 16).to_int()
        let low = (code & 0xffffL).to_int()
        if high < 0xd800 || high > 0xdbff || low < 0xdc00 || low > 0xdfff {
          return None
        }
        return Some(
          (0x10000 + ((high - 0xd800) << 10) + low - 0xdc00).to_int64(),
        )
      }
      if code >= 0xd800L && code <= 0xdfffL {
        return None
      }
      return Some(code)
    }
    return if code <= 0x10ffffL { Some(code) } else { None }
  }
  self.key(code)
}
