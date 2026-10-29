///|
fn xlsx_space(b : Byte) -> Bool {
  b == b' ' ||
  b == b'\t' ||
  b == b'\n' ||
  b == b'\r' ||
  b == b'\x0b' ||
  b == b'\x0c'
}

///|
/// Parse an A1 reference, returning zero-based column and row indices.
pub fn xlsx_parse_ref(text : String) -> (Int32, Int32, Bool) {
  let data = @utf8.encode(text)
  let mut i = 0
  let mut end = data.length()
  while i < end && xlsx_space(data[i]) {
    i += 1
  }
  while end > i && xlsx_space(data[end - 1]) {
    end -= 1
  }
  let mut col = 0
  while i < end {
    let mut c = data[i].to_int()
    if c == 36 {
      i += 1
      continue
    }
    if c >= 97 && c <= 122 {
      c -= 32
    }
    if c < 65 || c > 90 {
      break
    }
    col = col * 26 + c - 64
    if col > 16384 {
      return (0, 0, false)
    }
    i += 1
  }
  if col == 0 || i == end {
    return (0, 0, false)
  }
  let mut negative = false
  if data[i] == b'+' || data[i] == b'-' {
    negative = data[i] == b'-'
    i += 1
  }
  let mut row = 0
  let mut digits = 0
  while i < end {
    let c = data[i].to_int()
    i += 1
    if c == 36 {
      continue
    }
    if c < 48 || c > 57 {
      return (0, 0, false)
    }
    row = row * 10 + c - 48
    if row > 1048576 {
      return (0, 0, false)
    }
    digits += 1
  }
  if digits == 0 || negative || row < 1 {
    (0, 0, false)
  } else {
    (col - 1, row - 1, true)
  }
}

///|
/// Format a zero-based Excel column index as letters.
pub fn xlsx_col_name(column : Int32) -> String {
  let chars : Array[Char] = []
  let mut c = column.to_int64() + 1L
  while c > 0L {
    chars.push((65 + ((c - 1L) % 26L).to_int()).unsafe_to_char())
    c = (c - 1L) / 26L
  }
  let out = StringBuilder()
  for i = chars.length() - 1; i >= 0; i = i - 1 {
    out.write_char(chars[i])
  }
  out.to_string()
}

///|
fn xlsx_hex(b : Byte) -> Int32 {
  let c = b.to_int()
  if c >= 48 && c <= 57 {
    c - 48
  } else if c >= 65 && c <= 70 {
    c - 55
  } else if c >= 97 && c <= 102 {
    c - 87
  } else {
    -1
  }
}

///|
/// Decode Excel's `_xHHHH_` escapes and normalize line endings.
pub fn xlsx_decode_string(text : String) -> String {
  let input = @utf8.encode(text)
  let out : Array[Byte] = []
  let mut i = 0
  while i < input.length() {
    if i + 6 < input.length() &&
      input[i] == b'_' &&
      input[i + 1] == b'x' &&
      input[i + 6] == b'_' {
      let mut value = 0
      let mut valid = true
      for j in (i + 2)..<(i + 6) {
        let d = xlsx_hex(input[j])
        if d < 0 {
          valid = false
          break
        }
        value = value * 16 + d
      }
      if valid {
        let c = if value >= 0xd800 && value <= 0xdfff {
          '\u{fffd}'
        } else {
          value.unsafe_to_char()
        }
        for b in @utf8.encode(c.to_string()) {
          out.push(b)
        }
        i += 7
        continue
      }
    }
    out.push(input[i])
    i += 1
  }
  let output = StringBuilder()
  let mut previous_cr = false
  for c in @utf8.decode_lossy(Bytes::from_array(out)[:]) {
    if c == '\r' {
      output.write_char('\n')
      previous_cr = true
    } else {
      if c != '\n' || !previous_cr {
        output.write_char(c)
      }
      previous_cr = false
    }
  }
  output.to_string()
}
