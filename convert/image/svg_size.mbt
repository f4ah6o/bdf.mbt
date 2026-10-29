///|
fn svg_space(byte : Byte) -> Bool {
  byte == b' ' ||
  byte == b'\t' ||
  byte == b'\r' ||
  byte == b'\n' ||
  byte == b'\x0c'
}

///|
fn svg_digit(byte : Byte) -> Bool {
  byte >= b'0' && byte <= b'9'
}

///|
fn svg_length(value : String) -> Double {
  let data = @utf8.encode(value)
  let mut at = 0
  while at < data.length() && svg_space(data[at]) {
    at += 1
  }
  let start = at
  if at < data.length() && (data[at] == b'+' || data[at] == b'-') {
    at += 1
  }
  let mut digits = 0
  while at < data.length() && svg_digit(data[at]) {
    at += 1
    digits += 1
  }
  if at < data.length() && data[at] == b'.' {
    at += 1
    while at < data.length() && svg_digit(data[at]) {
      at += 1
      digits += 1
    }
  }
  if digits == 0 {
    return 0.0
  }
  if at < data.length() && (data[at] == b'e' || data[at] == b'E') {
    let marker = at
    at += 1
    if at < data.length() && (data[at] == b'+' || data[at] == b'-') {
      at += 1
    }
    let exponent = at
    while at < data.length() && svg_digit(data[at]) {
      at += 1
    }
    if at == exponent {
      at = marker
    }
  }
  let number = @utf8.decode(data[start:at]) catch { _ => return 0.0 }
  let magnitude = @string.parse_double(number) catch { _ => return 0.0 }
  if magnitude <= 0.0 || magnitude.is_inf() || magnitude.is_nan() {
    return 0.0
  }
  while at < data.length() && svg_space(data[at]) {
    at += 1
  }
  let unit_start = at
  while at < data.length() &&
        (
          (data[at] >= b'a' && data[at] <= b'z') ||
          (data[at] >= b'A' && data[at] <= b'Z') ||
          data[at] == b'%'
        ) {
    at += 1
  }
  let unit = @utf8.decode(data[unit_start:at]) catch { _ => return 0.0 }
  while at < data.length() && svg_space(data[at]) {
    at += 1
  }
  if at != data.length() {
    return 0.0
  }
  match unit.to_lower() {
    "" | "px" => magnitude
    "pt" => magnitude * (96.0 / 72.0)
    "pc" | "em" => magnitude * 16.0
    "in" => magnitude * 96.0
    "cm" => magnitude * (96.0 / 2.54)
    "mm" => magnitude * (96.0 / 25.4)
    "q" => magnitude * (96.0 / 101.6)
    "ex" => magnitude * 8.0
    _ => 0.0
  }
}

///|
fn svg_dimensions(
  width : String,
  height : String,
  viewbox : String,
) -> (Double, Double) {
  let mut w = svg_length(width)
  let mut h = svg_length(height)
  let fields : Array[String] = []
  let word = StringBuilder()
  for ch in viewbox {
    if ch == ',' || ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      let text = word.to_string()
      if text != "" {
        fields.push(text)
        word.reset()
      }
    } else {
      word.write_char(ch)
    }
  }
  let last = word.to_string()
  if last != "" {
    fields.push(last)
  }
  let mut vw = 0.0
  let mut vh = 0.0
  if fields.length() == 4 {
    vw = @string.parse_double(fields[2]) catch { _ => 0.0 }
    vh = @string.parse_double(fields[3]) catch { _ => 0.0 }
    if vw <= 0.0 || vh <= 0.0 || vw.is_nan() || vh.is_nan() {
      vw = 0.0
      vh = 0.0
    }
  }
  if vw > 0.0 {
    if w > 0.0 && h == 0.0 {
      h = w * vh / vw
    } else if h > 0.0 && w == 0.0 {
      w = h * vw / vh
    }
  }
  if w == 0.0 && h == 0.0 && vw > 0.0 {
    return (vw, vh)
  }
  if w == 0.0 {
    w = 300.0
  }
  if h == 0.0 {
    h = 150.0
  }
  (w, h)
}
