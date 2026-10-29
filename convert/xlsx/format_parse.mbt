///|
/// A number-format token. Kinds follow the XLSX number format parser.
pub(all) struct XlsxFormatToken {
  kind : Int32
  text : String
}

///|
/// A conditional section and its tokenized display pattern.
pub(all) struct XlsxFormatSection {
  tokens : Array[XlsxFormatToken]
  mut color : UInt32?
  mut condition_operator : String
  mut condition_value : Double
  mut date : Bool
  mut text : Bool
  mut locale : String
  mut dbnum : Int32
}

///|
fn xlsx_format_add(
  section : XlsxFormatSection,
  kind : Int32,
  text : String,
) -> Unit {
  let tokens = section.tokens
  if kind == 0 && tokens.length() > 0 && tokens[tokens.length() - 1].kind == 0 {
    let prev = tokens[tokens.length() - 1]
    tokens[tokens.length() - 1] = { kind: 0, text: prev.text + text, }
  } else if tokens.length() < 512 {
    tokens.push({ kind, text, })
  }
}

///|
fn xlsx_format_prefix(data : Bytes, start : Int32, prefix : String) -> Bool {
  let needle = @utf8.encode(prefix)
  if start + needle.length() > data.length() {
    return false
  }
  for j in 0..<needle.length() {
    if data[start + j] != needle[j] {
      return false
    }
  }
  true
}

///|
fn xlsx_format_last_date(section : XlsxFormatSection) -> Int32 {
  let mut i = section.tokens.length() - 1
  while i >= 0 {
    let token = section.tokens[i]
    if token.kind == 10 || token.kind == 11 {
      return @utf8.encode(token.text)[0].to_int()
    }
    if token.kind != 0 && token.kind != 1 {
      return 0
    }
    i -= 1
  }
  0
}

///|
fn xlsx_format_prev_digit(section : XlsxFormatSection) -> Bool {
  let mut i = section.tokens.length() - 1
  while i >= 0 {
    let token = section.tokens[i]
    if token.kind == 4 {
      return true
    }
    if token.kind != 0 {
      return false
    }
    i -= 1
  }
  false
}

///|
fn xlsx_format_bracket(
  section : XlsxFormatSection,
  content : String,
  palette : Array[UInt32],
) -> Unit {
  let lower = xlsx_trim(content).to_lower()
  let data = @utf8.encode(lower)
  if data.length() == 0 {
    return
  }
  if data[0] == b'$' {
    let original = @utf8.encode(content)
    let mut dash = 1
    while dash < original.length() && original[dash] != b'-' {
      dash += 1
    }
    if dash > 1 {
      xlsx_format_add(section, 0, @utf8.decode_lossy(original[1:dash]))
    }
    section.locale = if dash < original.length() {
      @utf8.decode_lossy(original[dash + 1:]).to_lower()
    } else {
      ""
    }
    return
  }
  let unit = data[0]
  if unit == b'h' || unit == b'm' || unit == b's' {
    let mut same = true
    for b in data {
      if b != unit {
        same = false
      }
    }
    if same {
      xlsx_format_add(section, 11, lower)
      section.date = true
      return
    }
  }
  if data[0] == b'<' || data[0] == b'>' || data[0] == b'=' {
    let end = if data.length() > 1 && (data[1] == b'=' || data[1] == b'>') {
      2
    } else {
      1
    }
    let op = @utf8.decode_lossy(data[:end])
    let value = @string.parse_double(xlsx_trim(@utf8.decode_lossy(data[end:]))) catch {
      _ => return
    }
    section.condition_operator = op
    section.condition_value = value
    return
  }
  if xlsx_format_prefix(data, 0, "color") {
    let n = xlsx_int(xlsx_trim(@utf8.decode_lossy(data[5:])))
    match n {
      Some(v) =>
        if v >= 1L && v <= 56L && v + 7L < palette.length().to_int64() {
          section.color = Some(palette[(v + 7L).to_int()])
        }
      None => ()
    }
    return
  }
  if xlsx_format_prefix(data, 0, "dbnum") {
    section.dbnum = match xlsx_int(@utf8.decode_lossy(data[5:])) {
      Some(v) =>
        if v >= -2147483648L && v <= 2147483647L {
          v.to_int()
        } else {
          0
        }
      None => 0
    }
    return
  }
  section.color = match lower {
    "black" => Some(0x000000U)
    "blue" => Some(0x0000ffU)
    "cyan" => Some(0x00ffffU)
    "green" => Some(0x00ff00U)
    "magenta" => Some(0xff00ffU)
    "red" => Some(0xff0000U)
    "white" => Some(0xffffffU)
    "yellow" => Some(0xffff00U)
    _ => section.color
  }
}

///|
fn xlsx_parse_format_section(
  code : String,
  palette : Array[UInt32],
) -> XlsxFormatSection {
  let section : XlsxFormatSection = {
    tokens: [],
    color: None,
    condition_operator: "",
    condition_value: 0.0,
    date: false,
    text: false,
    locale: "",
    dbnum: 0,
  }
  let data = @utf8.encode(code)
  let lower = @utf8.encode(code.to_lower())
  let mut i = 0
  while i < data.length() {
    let c = data[i]
    let mut n = 1
    while i + n < data.length() && (data[i + n].to_int() & 0xc0) == 0x80 {
      n += 1
    }
    if c == b'"' {
      let mut j = i + 1
      while j < data.length() && data[j] != b'"' {
        j += 1
      }
      xlsx_format_add(section, 0, @utf8.decode_lossy(data[i + 1:j]))
      i = if j < data.length() { j + 1 } else { j }
      continue
    } else if c == b'\\' || c == b'_' || c == b'*' {
      if i + 1 < data.length() {
        let mut j = i + 2
        while j < data.length() && (data[j].to_int() & 0xc0) == 0x80 {
          j += 1
        }
        xlsx_format_add(
          section,
          if c == b'\\' {
            0
          } else if c == b'_' {
            1
          } else {
            2
          },
          @utf8.decode_lossy(data[i + 1:j]),
        )
        i = j
      } else {
        i += 1
      }
      continue
    } else if c == b'[' {
      let mut j = i + 1
      while j < data.length() && data[j] != b']' {
        j += 1
      }
      if j < data.length() {
        xlsx_format_bracket(section, @utf8.decode_lossy(data[i + 1:j]), palette)
        i = j + 1
      } else {
        i = j
      }
      continue
    } else if c == b'@' {
      xlsx_format_add(section, 3, "@")
      section.text = true
    } else if c == b'0' || c == b'#' || c == b'?' {
      xlsx_format_add(section, 4, @utf8.decode_lossy(data[i:i + 1]))
    } else if c == b'.' {
      if xlsx_format_last_date(section) == 115 &&
        i + 1 < data.length() &&
        data[i + 1] == b'0' {
        let mut j = i + 1
        while j < data.length() && data[j] == b'0' {
          j += 1
        }
        xlsx_format_add(section, 13, @utf8.decode_lossy(data[i + 1:j]))
        i = j
        continue
      }
      xlsx_format_add(section, 5, ".")
    } else if c == b',' {
      xlsx_format_add(section, 6, ",")
    } else if c == b'%' {
      xlsx_format_add(section, 7, "%")
    } else if (c == b'E' || c == b'e') &&
      i + 1 < data.length() &&
      (data[i + 1] == b'+' || data[i + 1] == b'-') &&
      !section.date {
      xlsx_format_add(section, 8, @utf8.decode_lossy(data[i:i + 2]))
      i += 2
      continue
    } else if c == b'/' && xlsx_format_prev_digit(section) {
      xlsx_format_add(section, 9, "/")
    } else if xlsx_format_prefix(lower, i, "general") {
      xlsx_format_add(section, 12, "General")
      i += 7
      continue
    } else if xlsx_format_prefix(lower, i, "am/pm") {
      xlsx_format_add(section, 10, "AM/PM")
      section.date = true
      i += 5
      continue
    } else if xlsx_format_prefix(lower, i, "a/p") {
      xlsx_format_add(section, 10, "A/P")
      section.date = true
      i += 3
      continue
    } else if i < lower.length() &&
      (
        (
          lower[i] == b'y' ||
          lower[i] == b'm' ||
          lower[i] == b'd' ||
          lower[i] == b'h' ||
          lower[i] == b's' ||
          lower[i] == b'g' ||
          lower[i] == b'e' ||
          lower[i] == b'b'
        ) ||
        (lower[i] == b'a' && xlsx_format_prefix(lower, i, "aaa"))
      ) {
      let mut j = i + 1
      while j < lower.length() && lower[j] == lower[i] {
        j += 1
      }
      xlsx_format_add(section, 10, @utf8.decode_lossy(lower[i:j]))
      section.date = true
      i = j
      continue
    } else {
      xlsx_format_add(section, 0, @utf8.decode_lossy(data[i:i + n]))
    }
    i += n
  }
  section
}

///|
/// Parse at most four sections of an Excel number format.
pub fn xlsx_parse_number_format(
  code : String,
  palette : Array[UInt32],
) -> Array[XlsxFormatSection] {
  let sections = xlsx_split_format_sections(code)
  let out = []
  for i in 0..<Int32::min(4, sections.length()) {
    out.push(xlsx_parse_format_section(sections[i], palette))
  }
  out
}

///|
/// The default indexed spreadsheet color palette.
pub fn xlsx_default_palette() -> Array[UInt32] {
  [
    0x000000U, 0xffffffU, 0xff0000U, 0x00ff00U, 0x0000ffU, 0xffff00U, 0xff00ffU,
    0x00ffffU, 0x000000U, 0xffffffU, 0xff0000U, 0x00ff00U, 0x0000ffU, 0xffff00U,
    0xff00ffU, 0x00ffffU, 0x800000U, 0x008000U, 0x000080U, 0x808000U, 0x800080U,
    0x008080U, 0xc0c0c0U, 0x808080U, 0x9999ffU, 0x993366U, 0xffffccU, 0xccffffU,
    0x660066U, 0xff8080U, 0x0066ccU, 0xccccffU, 0x000080U, 0xff00ffU, 0xffff00U,
    0x00ffffU, 0x800080U, 0x800000U, 0x008080U, 0x0000ffU, 0x00ccffU, 0xccffffU,
    0xccffccU, 0xffff99U, 0x99ccffU, 0xff99ccU, 0xcc99ffU, 0xffcc99U, 0x3366ffU,
    0x33ccccU, 0x99cc00U, 0xffcc00U, 0xff9900U, 0xff6600U, 0x666699U, 0x969696U,
    0x003366U, 0x339966U, 0x003300U, 0x333300U, 0x993300U, 0x993366U, 0x333399U,
    0x333333U, 0x000000U, 0xffffffU,
  ]
}

///|
/// Select the section and whether the numeric value is rendered unsigned.
pub fn xlsx_select_format_section(
  sections : Array[XlsxFormatSection],
  value : Double,
) -> (Int32, Bool) {
  let mut count = sections.length()
  if count == 0 {
    return (0, false)
  }
  let last = sections[count - 1]
  if count > 1 && last.text && !xlsx_section_has_digits(last) {
    count -= 1
  }
  if sections[0].condition_operator != "" ||
    (count > 1 && sections[1].condition_operator != "") {
    for i in 0..<count {
      let s = sections[i]
      if i == 2 ||
        s.condition_operator == "" ||
        xlsx_condition_matches(s, value) {
        return (
          i,
          i > 0 ||
          (
            count > 1 &&
            value < 0.0 &&
            s.condition_operator != "" &&
            s.condition_value <= 0.0
          ),
        )
      }
    }
    return (count - 1, true)
  }
  if value > 0.0 || count == 1 {
    (0, false)
  } else if value < 0.0 {
    (1, true)
  } else if count >= 3 {
    (2, false)
  } else {
    (0, false)
  }
}

///|
fn xlsx_section_has_digits(section : XlsxFormatSection) -> Bool {
  for token in section.tokens {
    if token.kind == 4 ||
      token.kind == 12 ||
      token.kind == 10 ||
      token.kind == 11 {
      return true
    }
  }
  false
}

///|
fn xlsx_condition_matches(section : XlsxFormatSection, value : Double) -> Bool {
  match section.condition_operator {
    "<" => value < section.condition_value
    ">" => value > section.condition_value
    "=" => value == section.condition_value
    "<=" => value <= section.condition_value
    ">=" => value >= section.condition_value
    "<>" => value != section.condition_value
    _ => false
  }
}
