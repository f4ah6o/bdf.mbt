///|
/// Assign stable positive voice or lyric-verse numbers to MusicXML names.
pub struct MusicXmlNumbers {
  names : Map[String, Int32]
  taken : Map[Int32, Bool]
  mut free : Int32
  max : Int32
}

///|
pub fn MusicXmlNumbers::new(max : Int32) -> MusicXmlNumbers {
  { names: Map([]), taken: Map([]), free: 1, max, }
}

///|
pub fn MusicXmlNumbers::get(self : MusicXmlNumbers, input : String) -> Int32 {
  let name = if input == "" { "1" } else { input }
  if self.names.get(name) is Some(number) {
    return number
  }
  let bytes = @utf8.encode(name)
  let mut i = if bytes.length() > 0 && (bytes[0] == b'+' || bytes[0] == b'-') {
    1
  } else {
    0
  }
  let mut valid = i < bytes.length()
  while i < bytes.length() {
    if bytes[i] < b'0' || bytes[i] > b'9' {
      valid = false
    }
    i += 1
  }
  let parsed = @string.parse_int64(name) catch {
    _ => {
      valid = false
      0L
    }
  }
  let mut n = if valid && parsed >= 1L && parsed <= 99L {
    parsed.to_int()
  } else {
    0
  }
  if n == 0 {
    n = self.free
    while self.taken.contains(n) {
      n += 1
    }
    if self.max > 0 && n > self.max {
      return 0
    }
    self.free = n + 1
  }
  self.names[name] = n
  self.taken[n] = true
  n
}

///|
fn musicxml_hex_digit(c : Byte) -> Int32 {
  let n = c.to_int()
  if n >= 48 && n <= 57 {
    n - 48
  } else if n >= 65 && n <= 70 {
    n - 55
  } else if n >= 97 && n <= 102 {
    n - 87
  } else {
    -1
  }
}

///|
/// Parse a finite MusicXML number.
pub fn musicxml_float(text : String) -> (Double, Bool) {
  let text = musicxml_trim(text)
  let bytes = @utf8.encode(text)
  let mut start = 0
  let mut sign = 1.0
  if bytes.length() > 0 && (bytes[0] == b'+' || bytes[0] == b'-') {
    if bytes[0] == b'-' {
      sign = -1.0
    }
    start = 1
  }
  let hex = start + 2 <= bytes.length() &&
    bytes[start] == b'0' &&
    (bytes[start + 1] == b'x' || bytes[start + 1] == b'X')
  let clean = StringBuilder()
  for i in 0..<bytes.length() {
    if bytes[i] == b'_' {
      let before = i > 0 &&
        (if hex && i <= start + 2 {
          i == start + 2
        } else if hex {
          musicxml_hex_digit(bytes[i - 1]) >= 0
        } else {
          bytes[i - 1] >= b'0' && bytes[i - 1] <= b'9'
        })
      let after = i + 1 < bytes.length() &&
        (if hex {
          musicxml_hex_digit(bytes[i + 1]) >= 0
        } else {
          bytes[i + 1] >= b'0' && bytes[i + 1] <= b'9'
        })
      if !before || !after {
        return (0.0, false)
      }
    } else {
      clean.write_char(bytes[i].to_int().unsafe_to_char())
    }
  }
  if !hex {
    let value = @string.parse_double(clean.to_string()) catch {
      _ => return (0.0, false)
    }
    return if value.is_nan() || value.is_inf() {
      (0.0, false)
    } else {
      (value, true)
    }
  }
  let data = @utf8.encode(clean.to_string())
  let mut i = start + 2
  let mut fraction = false
  let mut seen = false
  let mut frac_digits = 0
  let mut mantissa = 0.0
  while i < data.length() {
    let d = musicxml_hex_digit(data[i])
    if d >= 0 {
      mantissa = mantissa * 16.0 + d.to_double()
      if fraction {
        frac_digits += 1
      }
      seen = true
      i += 1
    } else if data[i] == b'.' && !fraction {
      fraction = true
      i += 1
    } else {
      break
    }
  }
  if !seen || i >= data.length() || (data[i] != b'p' && data[i] != b'P') {
    return (0.0, false)
  }
  let exp_text = @utf8.decode_lossy(data[i + 1:])
  let exponent = @string.parse_int(exp_text) catch { _ => return (0.0, false) }
  if mantissa == 0.0 {
    return (sign * 0.0, true)
  }
  let result = sign *
    mantissa *
    2.0.pow((exponent - frac_digits * 4).to_double())
  if result.is_nan() || result.is_inf() {
    (0.0, false)
  } else {
    (result, true)
  }
}

///|
fn musicxml_round(x : Double) -> Double {
  if x < 0.0 {
    (x - 0.5).ceil()
  } else {
    (x + 0.5).floor()
  }
}

///|
/// Parse an integer or round a finite fractional MusicXML value.
pub fn musicxml_integer(text : String) -> (Int64, Bool) {
  let text = musicxml_trim(text)
  if text == "" {
    return (0L, false)
  }
  let bytes = @utf8.encode(text)
  let mut i = if bytes[0] == b'+' || bytes[0] == b'-' { 1 } else { 0 }
  let mut digits = i < bytes.length()
  while i < bytes.length() {
    if bytes[i] < b'0' || bytes[i] > b'9' {
      digits = false
    }
    i += 1
  }
  if digits {
    let parsed : Int64? = Some(@string.parse_int64(text)) catch { _ => None }
    if parsed is Some(n) {
      return (n, true)
    }
  }
  let (f, valid) = musicxml_float(text)
  if !valid || f > 1000000000.0 || f < -1000000000.0 {
    return (0L, false)
  }
  (musicxml_round(f).to_int64(), true)
}

///|
/// Convert quarter-note units to 960-tick units with upstream bounds.
pub fn musicxml_tick_of(quarters : Double) -> Int32 {
  musicxml_round(Double::min(Double::max(quarters, -4096.0), 4096.0) * 960.0).to_int()
}

///|
/// Parse comma, space, semicolon and period separated volta numbers and ranges.
pub fn musicxml_ending_numbers(text : String) -> (Array[Int64], Bool) {
  let tokens : Array[String] = []
  let item = StringBuilder()
  for c in text {
    if c == ',' || c == ' ' || c == ';' || c == '.' {
      if item.to_string() != "" {
        tokens.push(item.to_string())
        item.reset()
      }
    } else {
      item.write_char(c)
    }
  }
  if item.to_string() != "" {
    tokens.push(item.to_string())
  }
  let result : Array[Int64] = []
  for token in tokens {
    if token.contains("-") {
      let parts = token.split("-").to_array()
      let first = parts[0].to_owned()
      let second = token[first.length() + 1:].to_owned()
      let (x, ok1) = musicxml_integer(first)
      let (y, ok2) = musicxml_integer(second)
      if ok1 && ok2 && x >= 1L && y >= x && y - x < 100L {
        let mut v = x
        while v <= y {
          if result.length() == 100 {
            return (result, true)
          }
          result.push(v)
          v += 1L
        }
      }
    } else {
      let (v, ok) = musicxml_integer(token)
      if ok && v >= 1L && v <= 100L {
        if result.length() == 100 {
          return (result, true)
        }
        result.push(v)
      }
    }
  }
  (result, false)
}
