///|
/// A field of the AcroForm of a PDF.
pub(all) struct Field {
  name : String
  value : String
  typ : String
  rect : (Double, Double, Double, Double)?
  page_object : Int?
  flags : Int?
  options : Array[String]
  read_only : Bool
  required : Bool
  alternate_name : String
  max_len : Int?
}

///|
fn hex_digit(c : Char) -> Int? {
  if c >= '0' && c <= '9' {
    Some(c.to_int() - '0'.to_int())
  } else if c >= 'a' && c <= 'f' {
    Some(c.to_int() - 'a'.to_int() + 10)
  } else if c >= 'A' && c <= 'F' {
    Some(c.to_int() - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
fn hex_string(text : String, start : Int) -> (String, Int)? {
  if start >= text.length() || text[start].to_char().unwrap() != '<' {
    return None
  }
  let bytes : Array[Byte] = []
  let mut i = start + 1
  let mut high = -1
  while i < text.length() {
    let c = text[i].to_char().unwrap()
    i += 1
    if c == '>' {
      if high >= 0 {
        bytes.push(high.to_byte())
      }
      let data = Bytes::from_array(bytes)
      if data.length() >= 2 && data[0].to_int() == 0xfe &&
        data[1].to_int() == 0xff {
        let out = StringBuilder()
        let mut j = 2
        while j + 1 < data.length() {
          let code = (data[j].to_int() << 8) | data[j + 1].to_int()
          if code >= 0xd800 && code <= 0xdbff && j + 3 < data.length() {
            let low = (data[j + 2].to_int() << 8) | data[j + 3].to_int()
            if low >= 0xdc00 && low <= 0xdfff {
              let scalar = 0x10000 + ((code - 0xd800) << 10) + (low - 0xdc00)
              out.write_char(scalar.unsafe_to_char())
              j += 4
              continue
            }
          }
          out.write_char(code.unsafe_to_char())
          j += 2
        }
        return Some((out.to_string(), i))
      }
      return Some((@utf8.decode_lossy(data[:]), i))
    }
    if is_space(c) {
      continue
    }
    let digit = match hex_digit(c) {
      Some(digit) => digit
      None => return None
    }
    if high < 0 {
      high = digit
    } else {
      bytes.push(((high << 4) | digit).to_byte())
      high = -1
    }
  }
  None
}

///|
fn is_space(c : Char) -> Bool {
  c == ' ' || c == '\n' || c == '\r' || c == '\t'
}

///|
fn literal_string(text : String, start : Int) -> (String, Int)? {
  if start >= text.length() || text[start].to_char().unwrap() != '(' {
    return None
  }
  let out = StringBuilder()
  let mut depth = 1
  let mut i = start + 1
  while i < text.length() {
    let c = text[i].to_char().unwrap()
    if c == '\\' {
      i += 1
      if i >= text.length() {
        return None
      }
      let escaped = text[i].to_char().unwrap()
      if escaped == 'n' {
        out.write_char('\n')
      } else if escaped == 'r' {
        out.write_char('\r')
      } else if escaped == 't' {
        out.write_char('\t')
      } else if escaped == 'b' {
        out.write_char('\b')
      } else if escaped == 'f' {
        out.write_char('\f')
      } else {
        out.write_char(escaped)
      }
      i += 1
    } else if c == '(' {
      depth += 1
      out.write_char(c)
      i += 1
    } else if c == ')' {
      depth -= 1
      i += 1
      if depth == 0 {
        return Some((out.to_string(), i))
      }
      out.write_char(c)
    } else {
      out.write_char(c)
      i += 1
    }
  }
  None
}

///|
fn skip_spaces(text : String, start : Int) -> Int {
  let mut i = start
  while i < text.length() && is_space(text[i].to_char().unwrap()) {
    i += 1
  }
  i
}

///|
fn find_value(text : String, start : Int, limit : Int) -> String {
  let end = if limit < start + 512 { limit } else { start + 512 }
  let section = text[start:end]
  let at = match section.find("/V") {
    Some(index) => start + index
    None => return ""
  }
  let value_at = skip_spaces(text, at + 2)
  if value_at < text.length() && text[value_at].to_char().unwrap() == '(' {
    match literal_string(text, value_at) {
      Some((value, _)) => value
      None => ""
    }
  } else if value_at < text.length() &&
    text[value_at].to_char().unwrap() == '<' {
    match hex_string(text, value_at) {
      Some((value, _)) => value
      None => ""
    }
  } else if value_at < text.length() &&
    text[value_at].to_char().unwrap() == '/' {
    let mut i = value_at
    while i < text.length() && !is_space(text[i].to_char().unwrap()) {
      i += 1
    }
    text[value_at:i].to_owned()
  } else {
    ""
  }
}

///|
fn find_type(text : String, start : Int, limit : Int) -> String {
  let end = if limit < start + 512 { limit } else { start + 512 }
  let section = text[start:end]
  let at = match section.find("/FT") {
    Some(index) => start + index
    None => return ""
  }
  let mut i = skip_spaces(text, at + 3)
  let begin = i
  while i < text.length() && !is_space(text[i].to_char().unwrap()) {
    i += 1
  }
  text[begin:i].trim().to_owned()
}

///|
fn find_rect(
  text : String,
  start : Int,
  limit : Int,
) -> (Double, Double, Double, Double)? {
  let end = if limit < start + 512 { limit } else { start + 512 }
  let section = text[start:end]
  let at = match section.find("/Rect") {
    Some(index) => start + index
    None => return None
  }
  let rest = text[at:]
  let open_at = match rest.find("[") {
    Some(index) => at + index
    None => return None
  }
  let inner = text[open_at + 1:]
  let close_at = match inner.find("]") {
    Some(index) => open_at + 1 + index
    None => return None
  }
  let values : Array[Double] = []
  for token in text[open_at + 1:close_at].split(" ") {
    if token == "" {
      continue
    }
    let value = @string.parse_double(token.to_owned()) catch {
      _ => return None
    }
    values.push(value)
  }
  if values.length() < 4 {
    None
  } else {
    Some((values[0], values[1], values[2], values[3]))
  }
}

///|
fn find_page_object(text : String, start : Int, limit : Int) -> Int? {
  let section = text[start:limit]
  let at = match section.find("/P ") {
    Some(index) => start + index
    None => return None
  }
  let mut i = at + 3
  while i < limit && text[i].to_char().unwrap() == ' ' {
    i += 1
  }
  let begin = i
  while i < limit && text[i].to_char().unwrap() >= '0' &&
    text[i].to_char().unwrap() <= '9' {
    i += 1
  }
  if i == begin {
    return None
  }
  try {
    Some(@string.parse_int(text[begin:i].to_owned()))
  } catch {
    _ => None
  }
}

///|
fn find_flags(text : String, start : Int, limit : Int) -> Int? {
  let section = text[start:limit]
  let at = match section.find("/Ff") {
    Some(index) => start + index
    None => return None
  }
  let mut i = at + 3
  while i < limit && text[i].to_char().unwrap() == ' ' {
    i += 1
  }
  let begin = i
  while i < limit && text[i].to_char().unwrap() >= '0' &&
    text[i].to_char().unwrap() <= '9' {
    i += 1
  }
  if i == begin {
    return None
  }
  try {
    Some(@string.parse_int(text[begin:i].to_owned()))
  } catch {
    _ => None
  }
}

///|
fn find_options(text : String, start : Int, limit : Int) -> Array[String] {
  let options : Array[String] = []
  let section = text[start:limit]
  let at = match section.find("/Opt") {
    Some(index) => start + index
    None => return options
  }
  let mut i = at + 4
  while i < limit && text[i].to_char().unwrap() != '[' {
    i += 1
  }
  if i >= limit {
    return options
  }
  i += 1
  while i < limit {
    let c = text[i].to_char().unwrap()
    if c == ']' {
      break
    }
    if c == '(' {
      match literal_string(text, i) {
        Some((value, end)) => {
          options.push(value)
          i = end
        }
        None => break
      }
    } else {
      i += 1
    }
  }
  options
}

///|
fn field_name_string(text : String, start : Int) -> (String, Int)? {
  if start < text.length() && text[start].to_char().unwrap() == '<' {
    hex_string(text, start)
  } else {
    literal_string(text, start)
  }
}

///|
fn find_alternate_name(text : String, start : Int, limit : Int) -> String {
  let section = text[start:limit]
  let at = match section.find("/TU") {
    Some(index) => start + index
    None => return ""
  }
  let value_at = skip_spaces(text, at + 3)
  match field_name_string(text, value_at) {
    Some((value, _)) => value
    None => ""
  }
}

///|
fn find_max_len(text : String, start : Int, limit : Int) -> Int? {
  let section = text[start:limit]
  let at = match section.find("/MaxLen") {
    Some(index) => start + index
    None => return None
  }
  let mut i = skip_spaces(text, at + 7)
  let begin = i
  while i < limit && text[i].to_char().unwrap() >= '0' &&
    text[i].to_char().unwrap() <= '9' {
    i += 1
  }
  if i == begin {
    return None
  }
  try {
    Some(@string.parse_int(text[begin:i].to_owned()))
  } catch {
    _ => None
  }
}

///|
/// Read the names, values and types of the AcroForm fields of a PDF.
pub fn read_fields(data : Bytes) -> Array[Field] {
  let text = @utf8.decode_lossy(data[:])
  let fields : Array[Field] = []
  let mut pos = 0
  while pos < text.length() {
    let rest = text[pos:]
    let at = match rest.find("/T") {
      Some(index) => pos + index
      None => break
    }
    let name_at = skip_spaces(text, at + 2)
    if name_at >= text.length() ||
      (text[name_at].to_char().unwrap() != '(' &&
        text[name_at].to_char().unwrap() != '<') {
      pos = at + 2
      continue
    }
    let (name, after) = match field_name_string(text, name_at) {
      Some(found) => found
      None => {
        pos = at + 2
        continue
      }
    }
    let rest = text[after:]
    let next_t = match rest.find("/T (") {
      Some(index) => after + index
      None =>
        match rest.find("/T(") {
          Some(index) => after + index
          None => text.length()
        }
    }
    let value = find_value(text, after, next_t)
    let typ = find_type(text, after, next_t)
    let rect = find_rect(text, after, next_t)
    let page_object = find_page_object(text, after, next_t)
    let flags = find_flags(text, after, next_t)
    let options = find_options(text, after, next_t)
    let alternate_name = find_alternate_name(text, after, next_t)
    let max_len = find_max_len(text, after, next_t)
    if name != "" {
      let mut found = -1
      for i in 0..<fields.length() {
        if fields[i].name == name {
          found = i
        }
      }
      let read_only = match flags {
        Some(value) => (value & 1) != 0
        None => false
      }
      let required = match flags {
        Some(value) => (value & 2) != 0
        None => false
      }
      let field = {
        name,
        value,
        typ,
        rect,
        page_object,
        flags,
        options,
        read_only,
        required,
        alternate_name,
        max_len,
      }
      if found >= 0 {
        fields[found] = field
      } else {
        fields.push(field)
      }
    }
    pos = after
  }
  fields
}
