///|
fn pdf_cmap_number(value : ContentValue) -> Double? {
  match value {
    Integer(n) => Some(n.to_double())
    Real(n) => Some(n)
    _ => None
  }
}

///|
fn pdf_cmap_bytes(value : ContentValue) -> Bytes {
  content_literal_bytes(value).unwrap_or(b"")
}

///|
fn pdf_cmap_read_until(
  lexer : ContentLexer,
  end : Bytes,
) -> Array[ContentValue] {
  let values : Array[ContentValue] = []
  while true {
    match lexer.next(0) {
      End => return values
      Operand(value) => values.push(value)
      Operator(op) => if op == end { return values }
    }
  }
  values
}

///|
// The Adobe glyph list is supplemented by uniXXXX and uXXXXXX names.
fn pdf_cmap_glyph_name(bytes : Bytes) -> String {
  let mut length = bytes.length()
  for i in 0..<bytes.length() {
    if bytes[i] == b'.' {
      if i > 0 {
        length = i
      }
      break
    }
  }
  let name = @utf8.decode_lossy(bytes[:length])
  match pdf_glyph_names.get(name) {
    Some(value) => return pdf_runes_string([value])
    None => ()
  }
  let (start, end) = if length >= 7 &&
    bytes[0] == b'u' &&
    bytes[1] == b'n' &&
    bytes[2] == b'i' {
    (3, 7)
  } else if length >= 5 && length <= 7 && bytes[0] == b'u' {
    (1, length)
  } else {
    return ""
  }
  let mut code = 0
  for i in start..<end {
    let digit = content_hex_digit(bytes[i])
    if digit < 0 {
      return ""
    }
    code = code * 16 + digit
  }
  pdf_runes_string([code])
}

///|
fn pdf_parse_cmap(data : Bytes, parent : PdfCMap?) -> PdfCMap {
  let result = PdfCMap::new()
  let lexer : ContentLexer = { data, pos: 0, }
  let stack : Array[ContentValue] = []
  while true {
    match lexer.next(0) {
      End => break
      Operand(value) => {
        stack.push(value)
        if stack.length() > 64 {
          ignore(stack.remove(0))
        }
      }
      Operator(op) => {
        if op == b"begincodespacerange" {
          let items = pdf_cmap_read_until(lexer, b"endcodespacerange")
          let mut i = 0
          while i + 1 < items.length() {
            let low = pdf_cmap_bytes(items[i])
            let high = pdf_cmap_bytes(items[i + 1])
            if !low.is_empty() {
              result.ranges.push({
                size: low.length(),
                low: pdf_code(low),
                high: pdf_code(high),
              })
            }
            i += 2
          }
        } else if op == b"begincidrange" {
          let items = pdf_cmap_read_until(lexer, b"endcidrange")
          let mut i = 0
          while i + 2 < items.length() {
            let low = pdf_cmap_bytes(items[i])
            let high = pdf_cmap_bytes(items[i + 1])
            let cid = pdf_cmap_number(items[i + 2]).unwrap_or(0.0).to_int64() &
              0xffffffffL
            result.cid_ranges.push({
              size: low.length(),
              low: pdf_code(low),
              high: pdf_code(high),
              cid,
            })
            result.note_length(low.length())
            i += 3
          }
        } else if op == b"begincidchar" {
          let items = pdf_cmap_read_until(lexer, b"endcidchar")
          let mut i = 0
          while i + 1 < items.length() {
            let code = pdf_cmap_bytes(items[i])
            let cid = pdf_cmap_number(items[i + 1]).unwrap_or(0.0).to_int64() &
              0xffffffffL
            result.single[pdf_code(code)] = cid
            result.note_length(code.length())
            i += 2
          }
        } else if op == b"beginbfchar" {
          let items = pdf_cmap_read_until(lexer, b"endbfchar")
          let mut i = 0
          while i + 1 < items.length() {
            let code = pdf_cmap_bytes(items[i])
            let destination = match items[i + 1] {
              Name(value) => pdf_cmap_glyph_name(value)
              value => pdf_runes_string(pdf_utf16_runes(pdf_cmap_bytes(value)))
            }
            result.unicode[pdf_code(code)] = destination
            result.note_length(code.length())
            i += 2
          }
        } else if op == b"beginbfrange" {
          let items = pdf_cmap_read_until(lexer, b"endbfrange")
          let mut i = 0
          while i + 2 < items.length() {
            let low_bytes = pdf_cmap_bytes(items[i])
            let low = pdf_code(low_bytes)
            let high = pdf_code(pdf_cmap_bytes(items[i + 1]))
            result.note_length(low_bytes.length())
            match items[i + 2] {
              ArrayValue(values) =>
                for index, value in values {
                  result.unicode[(low + index.to_int64()) & 0xffffffffL] = pdf_runes_string(
                    pdf_utf16_runes(pdf_cmap_bytes(value)),
                  )
                }
              value =>
                result.unicode_ranges.push({
                  low,
                  high,
                  destination: pdf_utf16_runes(pdf_cmap_bytes(value)),
                })
            }
            i += 3
          }
        } else if op == b"usecmap" {
          if !stack.is_empty() {
            match stack[stack.length() - 1] {
              Name(name) => result.use_name = name
              _ => ()
            }
          }
        } else if op == b"def" && stack.length() >= 2 {
          match stack[stack.length() - 2] {
            Name(b"WMode") =>
              match pdf_cmap_number(stack[stack.length() - 1]) {
                Some(value) => {
                  result.vertical = value == 1.0
                  result.wmode_set = true
                }
                None => ()
              }
            _ => ()
          }
        }
        stack.clear()
      }
    }
  }
  result.finish(parent)
  result
}

///|
fn PdfCMap::finish(self : PdfCMap, supplied : PdfCMap?) -> Unit {
  let parent = match supplied {
    Some(value) => Some(value)
    None =>
      if self.use_name == b"Identity-H" || self.use_name == b"Identity-V" {
        let value = PdfCMap::new()
        value.identity = true
        value.vertical = self.use_name == b"Identity-V"
        value.ranges.push({ size: 2, low: 0L, high: 65535L, })
        Some(value)
      } else {
        let name = @utf8.decode_lossy(self.use_name[:])
        match pdf_cjk_maps.get(name) {
          Some(source) => {
            let value = PdfCMap::new()
            value.predefined = name
            value.vertical = source.vertical
            for space in source.codespaces {
              value.ranges.push(space)
            }
            Some(value)
          }
          None => {
            self.unresolved_parent = !self.use_name.is_empty()
            None
          }
        }
      }
  }
  match parent {
    Some(value) => {
      if !value.predefined.is_empty() &&
        value.single.is_empty() &&
        value.cid_ranges.is_empty() {
        self.predefined = value.predefined
      } else if value.identity &&
        value.single.is_empty() &&
        value.cid_ranges.is_empty() {
        self.identity = true
      } else {
        self.parent = Some(value)
      }
      if self.ranges.is_empty() {
        for range in value.ranges {
          self.ranges.push(range)
        }
      }
      if !self.wmode_set {
        self.vertical = value.vertical
      }
      self.unresolved_parent = self.unresolved_parent || value.unresolved_parent
    }
    None => ()
  }
  self.cid_ranges.sort_by((a, b) => a.low.compare(b.low))
  for i in 1..<self.cid_ranges.length() {
    if self.cid_ranges[i].low <= self.cid_ranges[i - 1].high {
      self.overlapping = true
    }
  }
  if self.ranges.is_empty() {
    if self.seen2 || (!self.seen1 && self.unicode.is_empty()) {
      self.ranges.push({ size: 2, low: 0L, high: 65535L, })
    }
    if self.seen1 {
      self.ranges.push({ size: 1, low: 0L, high: 255L, })
    }
  }
}
