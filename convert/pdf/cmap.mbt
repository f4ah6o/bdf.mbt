///|
// PDF character maps translate character codes to CIDs and Unicode text.
// Code and range values are held in Int64 to preserve unsigned 32-bit values.
priv struct PdfCodeSpace {
  size : Int32
  low : Int64
  high : Int64
}

///|
priv struct PdfCidRange {
  size : Int32
  low : Int64
  high : Int64
  cid : Int64
}

///|
priv struct PdfUnicodeRange {
  low : Int64
  high : Int64
  destination : Array[Int32]
}

///|
priv struct PdfGlyphCode {
  code : Int64
  size : Int32
  cid : Int64
} derive(Debug, Eq)

///|
priv struct PdfCMap {
  ranges : Array[PdfCodeSpace]
  single : Map[Int64, Int64]
  cid_ranges : Array[PdfCidRange]
  cid_cache : Map[Int64, Int64?]
  unicode : Map[Int64, String]
  unicode_ranges : Array[PdfUnicodeRange]
  mut identity : Bool
  mut overlapping : Bool
  mut vertical : Bool
  mut wmode_set : Bool
  mut seen1 : Bool
  mut seen2 : Bool
  mut use_name : Bytes
  mut unresolved_parent : Bool
  mut predefined : String
  mut parent : PdfCMap?
}

///|
fn PdfCMap::new() -> PdfCMap {
  {
    ranges: [],
    single: Map([]),
    cid_ranges: [],
    cid_cache: Map([]),
    unicode: Map([]),
    unicode_ranges: [],
    identity: false,
    overlapping: false,
    vertical: false,
    wmode_set: false,
    seen1: false,
    seen2: false,
    use_name: b"",
    unresolved_parent: false,
    predefined: "",
    parent: None,
  }
}

///|
fn pdf_code(bytes : Bytes) -> Int64 {
  let mut result = 0L
  for byte in bytes {
    result = ((result << 8) | byte.to_int64()) & 0xffffffffL
  }
  result
}

///|
fn PdfCMap::lookup(self : PdfCMap, code : Int64, depth : Int32) -> Int64? {
  match self.single.get(code) {
    Some(value) => return Some(value)
    None => ()
  }
  if self.overlapping {
    let hit = match self.cid_cache.get(code) {
      Some(value) => value
      None => {
        let mut value = None
        for range in self.cid_ranges {
          if code >= range.low && code <= range.high {
            value = Some((range.cid + code - range.low) & 0xffffffffL)
            break
          }
        }
        self.cid_cache[code] = value
        value
      }
    }
    if hit is Some(value) {
      return Some(value)
    }
  } else {
    let mut low = 0
    let mut high = self.cid_ranges.length()
    while low < high {
      let middle = low + (high - low) / 2
      if self.cid_ranges[middle].high < code {
        low = middle + 1
      } else {
        high = middle
      }
    }
    if low < self.cid_ranges.length() && self.cid_ranges[low].low <= code {
      let range = self.cid_ranges[low]
      return Some((range.cid + code - range.low) & 0xffffffffL)
    }
  }
  if depth < 8 {
    match self.parent {
      Some(parent) =>
        match parent.lookup(code, depth + 1) {
          Some(value) => return Some(value)
          None => ()
        }
      None => ()
    }
  }
  if !self.predefined.is_empty() {
    match pdf_cjk_cid(self.predefined, code, 0) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  if self.identity {
    Some(code)
  } else {
    None
  }
}

///|
fn PdfCMap::decode(self : PdfCMap, bytes : Bytes) -> Array[PdfGlyphCode] {
  let result : Array[PdfGlyphCode] = []
  let mut pos = 0
  while pos < bytes.length() {
    let mut code = 0L
    let mut size = 1
    let mut matched = false
    while size <= 4 && pos + size <= bytes.length() {
      code = (code << 8) | bytes[pos + size - 1].to_int64()
      for range in self.ranges {
        if range.size == size && code >= range.low && code <= range.high {
          result.push({ code, size, cid: self.lookup(code, 0).unwrap_or(0L), })
          pos += size
          matched = true
          break
        }
      }
      if matched {
        break
      }
      size += 1
    }
    if !matched {
      size = if self.ranges.is_empty() { 1 } else { self.ranges[0].size }
      for range in self.ranges {
        size = Int32::min(size, range.size)
      }
      size = Int32::min(size, bytes.length() - pos)
      code = 0L
      for i in 0..<size {
        code = ((code << 8) | bytes[pos + i].to_int64()) & 0xffffffffL
      }
      result.push({ code, size, cid: self.lookup(code, 0).unwrap_or(0L), })
      pos += size
    }
  }
  result
}
