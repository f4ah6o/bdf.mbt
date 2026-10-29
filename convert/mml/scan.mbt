///|
fn mml_scan_digit(c : Byte) -> Bool {
  c >= b'0' && c <= b'9'
}

///|
/// Read an unsigned MML number, returning its value, presence and end offset.
pub fn mml_number(s : Bytes, start : Int32) -> (Int32, Bool, Int32) {
  let mut i = start
  let mut n = 0
  while i < s.length() && mml_scan_digit(s[i]) {
    n = Int32::min(n * 10 + s[i].to_int() - 48, 65535)
    i += 1
  }
  (n, i != start, i)
}

///|
/// Read a signed MML integer.
pub fn mml_signed(s : Bytes, start : Int32) -> (Int32, Bool, Int32) {
  let mut i = start
  let mut sign = 1
  if i < s.length() && (s[i] == b'+' || s[i] == b'-') {
    if s[i] == b'-' {
      sign = -1
    }
    i += 1
  }
  let (n, ok, end) = mml_number(s, i)
  if ok {
    (n * sign, true, end)
  } else {
    (0, false, start)
  }
}

///|
/// Read a decimal tempo; the parser limits the significant digits like Go.
pub fn mml_decimal(s : Bytes, start : Int32) -> (Double, Bool, Int32) {
  let mut i = start
  while i < s.length() && mml_scan_digit(s[i]) && i - start < 9 {
    i += 1
  }
  if i == start {
    return (0.0, false, start)
  }
  if i + 1 < s.length() && s[i] == b'.' && mml_scan_digit(s[i + 1]) {
    i += 1
    let mut digits = 0
    while i < s.length() && mml_scan_digit(s[i]) {
      digits += 1
      if digits > 6 {
        break
      }
      i += 1
    }
  }
  let value = @string.parse_double(@utf8.decode_lossy(s[start:i])) catch {
    _ => 0.0
  }
  while i < s.length() && mml_scan_digit(s[i]) {
    i += 1
  }
  (value, true, i)
}

///|
/// Read a written note length with dots.
pub fn mml_length_arg(
  s : Bytes,
  start : Int32,
  pct : Int32,
) -> (Int32, Bool, Int32) {
  let mut i = start
  if i < s.length() && s[i] == b'%' {
    let (n, ok, end) = mml_number(s, i + 1)
    if !ok {
      return (0, false, start)
    }
    let (d, last) = mml_dots(s, end, Int32::max(n * 3840 / pct, 1))
    return (d, true, last)
  }
  let (n, ok, end) = mml_number(s, i)
  if !ok || n == 0 {
    return (0, false, if ok { end } else { start })
  }
  i = end
  let (d, last) = mml_dots(s, i, Int32::max(3840 / n, 1))
  (d, true, last)
}

///|
/// Add the dots following a note length.
pub fn mml_dots(s : Bytes, start : Int32, duration : Int32) -> (Int32, Int32) {
  let mut i = start
  let mut d = duration
  let mut half = duration
  while i < s.length() && s[i] == b'.' {
    i += 1
    half = half / 2
    d += half
  }
  (d, i)
}

///|
/// Skip a command's numeric arguments.
pub fn mml_skip_args(s : Bytes, start : Int32) -> Int32 {
  let mut i = start
  while i < s.length() &&
        (
          mml_scan_digit(s[i]) ||
          s[i] == b'+' ||
          s[i] == b'-' ||
          s[i] == b',' ||
          s[i] == b'.'
        ) {
    i += 1
  }
  i
}

///|
/// Find a matching bracket in nested MML.
pub fn mml_closing(
  s : Bytes,
  start : Int32,
  open : Byte,
  close : Byte,
) -> Int32 {
  let mut depth = 0
  for i in start..<s.length() {
    if s[i] == open {
      depth += 1
    } else if s[i] == close {
      depth -= 1
      if depth == 0 {
        return i
      }
    }
  }
  -1
}

///|
/// Find the end of an MML /: loop.
pub fn mml_closing_slash(s : Bytes, start : Int32) -> Int32 {
  let mut depth = 0
  let mut i = start
  while i + 1 < s.length() {
    if s[i] == b'/' && s[i + 1] == b':' {
      depth += 1
      i += 1
    } else if s[i] == b':' && s[i + 1] == b'/' {
      depth -= 1
      if depth == 0 {
        return i
      }
      i += 1
    }
    i += 1
  }
  -1
}

///|
/// Find the break in a loop body, ignoring nested loops and tuplets.
pub fn mml_break_at(s : Bytes, kind : Byte) -> Int32 {
  let mut depth = 0
  let mut i = 0
  while i < s.length() {
    let c = s[i]
    if c == b'/' && i + 1 < s.length() && s[i + 1] == b':' {
      depth += 1
      i += 1
    } else if c == b':' && i + 1 < s.length() && s[i + 1] == b'/' {
      depth -= 1
      i += 1
    } else if c == b'[' || c == b'{' {
      depth += 1
    } else if c == b']' || c == b'}' {
      depth -= 1
    } else if depth == 0 &&
      (
        (kind == b'[' && (c == b'|' || c == b':')) ||
        (kind == b'/' && c == b'/')
      ) {
      return i
    }
    i += 1
  }
  -1
}
