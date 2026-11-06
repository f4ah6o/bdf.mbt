///|
// Tags of form templates: the text between double braces that a filler
// replaces with data. Tags never run code; they name values and sections.
pub(all) enum TagKind {
  Text
  Value
  Open
  Inverted
  Close
  Image
} derive(Debug, Eq)

///|
pub const MODE_ROWS : String = "rows"
pub const MODE_SLOTS : String = "slots"
pub const MODE_PAGES : String = "pages"
pub const ALIGN_LEFT : String = "left"
pub const ALIGN_RIGHT : String = "right"
pub const ALIGN_CENTER : String = "center"
pub const OVERFLOW_KEEP : String = ""
pub const OVERFLOW_CUT : String = "cut"
pub const OVERFLOW_WRAP : String = "wrap"
pub const MAX_WIDTH : Int = 4096
pub const MAX_TAG_LEN : Int = 1024
pub const FIT_CONTAIN : String = "contain"
pub const FIT_COVER : String = "cover"
pub const FIT_STRETCH : String = "stretch"
pub const INPUT_SIGNATURE : String = "signature"
pub const INPUT_SEAL : String = "seal"

///|
/// A mistake in the tags of a text, at a byte of it.
pub suberror TagError {
  TagError(String, Int32)
}

///|
pub(all) struct TagToken {
  kind : TagKind
  mut text : String
  mut name : String
  mut path : Array[String]
  mut format : String
  mut has_format : Bool
  mut width : Int
  mut align : String
  mut overflow : String
  mut mode : String
  mut fit : String
  mut input : String
  mut code : String
  mut level : String
  mut quiet : Int
  mut has_quiet : Bool
  mut pos : Int
  mut end : Int
} derive(Debug, Eq)

///|
fn tag_token(kind : TagKind) -> TagToken {
  {
    kind,
    text: "",
    name: "",
    path: [],
    format: "",
    has_format: false,
    width: 0,
    align: "",
    overflow: "",
    mode: "",
    fit: "",
    input: "",
    code: "",
    level: "",
    quiet: 0,
    has_quiet: false,
    pos: 0,
    end: 0,
  }
}

///|
fn tag_utf8_len(c : Char) -> Int {
  let code = c.to_int()
  if code < 0x80 {
    1
  } else if code < 0x800 {
    2
  } else if code < 0x10000 {
    3
  } else {
    4
  }
}

///|
fn tag_space(c : Char) -> Bool {
  let code = c.to_int()
  c == ' ' ||
  c == '\t' ||
  c == '\n' ||
  c == '\r' ||
  c == '\u{a0}' ||
  c == '\u{3000}' ||
  (code >= 0x2000 && code <= 0x200a) ||
  code == 0x2028 ||
  code == 0x2029 ||
  code == 0x202f ||
  code == 0x205f
}

///|
fn tag_trim(value : String) -> String {
  let chars = value.to_array()
  let mut start = 0
  let mut end = chars.length()
  while start < end && tag_space(chars[start]) {
    start += 1
  }
  while end > start && tag_space(chars[end - 1]) {
    end -= 1
  }
  if start == 0 && end == chars.length() {
    value
  } else {
    String::from_array(chars[start:end])
  }
}

///|
fn tag_opener(chars : Array[Char], i : Int) -> Int {
  if i + 1 < chars.length() {
    if chars[i] == '{' && chars[i + 1] == '{' {
      return 2
    }
    if chars[i] == '｛' && chars[i + 1] == '｛' {
      return 2
    }
  }
  0
}

///|
fn tag_closer(chars : Array[Char], i : Int) -> Int {
  if i + 1 < chars.length() {
    if chars[i] == '}' && chars[i + 1] == '}' {
      return 2
    }
    if chars[i] == '｝' && chars[i + 1] == '｝' {
      return 2
    }
  }
  0
}

///|
fn tag_close_quote(r : Char) -> Char {
  match r {
    '"' | '\'' | '＂' | '＇' => r
    '“' | '”' | '„' | '‟' => '”'
    '‘' | '’' | '‚' | '‛' => '’'
    '「' => '」'
    _ => '\u{0}'
  }
}

///|
fn tag_closing(chars : Array[Char], start : Int) -> (Int, Int) {
  let mut quote = '\u{0}'
  let mut i = start
  while i < chars.length() {
    let r = chars[i]
    if quote != '\u{0}' {
      if r == quote {
        quote = '\u{0}'
      }
    } else {
      let closer = tag_close_quote(r)
      if closer != '\u{0}' {
        quote = closer
      } else {
        let close_len = tag_closer(chars, i)
        if close_len != 0 {
          return (i, i + close_len)
        }
        if tag_opener(chars, i) != 0 {
          return (-1, -1)
        }
      }
    }
    i += 1
  }
  (-1, -1)
}

///|
fn tag_clip(value : String) -> String {
  let chars = value.to_array()
  if chars.length() <= 24 {
    value
  } else {
    String::from_array(chars[:24]) + "…"
  }
}

///|
/// Whether text may hold a tag.
pub fn has(text : String) -> Bool {
  text.contains("{{") || text.contains("｛｛")
}

///|
/// Split text into text and tags.
pub fn parse(text : String) -> Array[TagToken] raise TagError {
  parse_impl(text, false)
}

///|
/// Split the text of a plain-text template into text and tags, with the
/// column options that only those templates take.
pub fn parse_text(text : String) -> Array[TagToken] raise TagError {
  parse_impl(text, true)
}

///|
fn parse_impl(text : String, columns : Bool) -> Array[TagToken] raise TagError {
  let chars = text.to_array()
  let offsets = Array::make(chars.length() + 1, 0)
  let mut byte = 0
  for i, c in chars {
    offsets[i] = byte
    byte += tag_utf8_len(c)
  }
  offsets[chars.length()] = byte
  let out : Array[TagToken] = []
  let lit = StringBuilder()
  let mut lit_len = 0
  let mut lit_pos = 0
  let flush = fn(end_index : Int) -> Unit {
    if lit_len > 0 {
      let token = tag_token(TagKind::Text)
      token.text = lit.to_string()
      token.pos = offsets[lit_pos]
      token.end = offsets[end_index]
      out.push(token)
      lit.reset()
      lit_len = 0
    }
  }
  let mut i = 0
  while i < chars.length() {
    let opener = tag_opener(chars, i)
    if opener == 0 {
      if chars[i] == '\\' && tag_opener(chars, i + 1) != 0 {
        if lit_len == 0 {
          lit_pos = i
        }
        let escaped = tag_opener(chars, i + 1)
        for k in 0..<escaped {
          lit.write_char(chars[i + 1 + k])
          lit_len += 1
        }
        i += 1 + escaped
        continue
      }
      if lit_len == 0 {
        lit_pos = i
      }
      lit.write_char(chars[i])
      lit_len += 1
      i += 1
      continue
    }
    flush(i)
    let start = i + opener
    let (end, next) = tag_closing(chars, start)
    if end < 0 {
      raise TagError(
        "the tag " + tag_clip(String::from_array(chars[i:])) + " is not closed with }}",
        offsets[i],
      )
    }
    if offsets[end] - offsets[start] > MAX_TAG_LEN {
      raise TagError(
        "the tag " +
        tag_clip(String::from_array(chars[i:])) +
        " is longer than " +
        MAX_TAG_LEN.to_string() +
        " bytes",
        offsets[i],
      )
    }
    let body = String::from_array(chars[start:end])
    let token = parse_tag(body, offsets[i], columns)
    token.pos = offsets[i]
    token.end = offsets[next]
    out.push(token)
    i = next
  }
  flush(chars.length())
  out
}

///|
fn split_filters(value : String) -> Array[String] {
  let chars = value.to_array()
  let out : Array[String] = []
  let part = StringBuilder()
  let mut quote = '\u{0}'
  for r in chars {
    if quote != '\u{0}' {
      if r == quote {
        quote = '\u{0}'
      }
      part.write_char(r)
      continue
    }
    let closer = tag_close_quote(r)
    if closer != '\u{0}' {
      quote = closer
      part.write_char(r)
      continue
    }
    if r == '|' || r == '｜' {
      out.push(part.to_string())
      part.reset()
      continue
    }
    part.write_char(r)
  }
  out.push(part.to_string())
  out
}

///|
fn cut_filter(value : String) -> (String, String, Bool) {
  let chars = value.to_array()
  let mut at = -1
  for i, c in chars {
    if c == ':' || c == '：' {
      at = i
      break
    }
  }
  if at < 0 {
    return (tag_trim(value).to_lower(), "", false)
  }
  let name = tag_trim(String::from_array(chars[:at])).to_lower()
  let mut arg = tag_trim(String::from_array(chars[at + 1:]))
  let arg_chars = arg.to_array()
  if arg_chars.length() >= 2 {
    let opener = arg_chars[0]
    if tag_close_quote(opener) != '\u{0}' &&
      tag_close_quote(opener) == arg_chars[arg_chars.length() - 1] {
      arg = String::from_array(arg_chars[1:arg_chars.length() - 1])
    }
  }
  (name, arg, true)
}

///|
fn barcode_kind(value : String) -> String {
  let name = value.to_lower()
  match name {
    "jan" | "jan-13" | "jan13" | "ean" | "ean-13" | "ean13" => "ean13"
    "jan-8" | "jan8" | "ean-8" | "ean8" => "ean8"
    "upc-a" | "upca" => "upca"
    "upc-e" | "upce" => "upce"
    "nw-7" | "nw7" => "nw7"
    "gs1-128" | "gs1_128" | "gs1128" => "gs1-128"
    "code39" | "code-39" => "code39"
    "code93" | "code-93" => "code93"
    "code128" | "code-128" => "code128"
    "itf" => "itf"
    "codabar" => "codabar"
    _ => ""
  }
}

///|
fn quiet_arg(value : String) -> Int {
  let n = @string.parse_int(value) catch { _ => -1 }
  if n < 0 || n > 64 {
    -1
  } else {
    n
  }
}

///|
fn parse_tag(body : String, pos : Int, columns : Bool) -> TagToken raise TagError {
  let mut text = tag_trim(body)
  let mut kind = TagKind::Value
  if text != "" {
    let first = text.to_array()[0]
    let marked = match first {
      '#' | '＃' => Some(TagKind::Open)
      '^' | '＾' => Some(TagKind::Inverted)
      '/' | '／' => Some(TagKind::Close)
      '%' | '％' => Some(TagKind::Image)
      _ => None
    }
    match marked {
      Some(value) => {
        kind = value
        let chars = text.to_array()
        text = tag_trim(String::from_array(chars[1:]))
      }
      None => ()
    }
  }
  let token = tag_token(kind)
  let parts = split_filters(text)
  token.name = tag_trim(parts[0])
  match token.name {
    "" =>
      if kind != TagKind::Close {
        raise TagError("a tag without a name", pos)
      }
    "." => token.path = ["."]
    _ => {
      let path : Array[String] = []
      for part in token.name.split(".") {
        let piece = tag_trim(part.to_owned())
        if piece == "" {
          raise TagError(
            "the name " + token.name + " of a tag has an empty part",
            pos,
          )
        }
        if piece.contains("{") ||
          piece.contains("}") ||
          piece.contains("#") ||
          piece.contains("^") ||
          piece.contains("/") ||
          piece.contains("%") ||
          piece.contains("\"") ||
          piece.contains("'") {
          raise TagError(
            "the name " +
            token.name +
            " of a tag has a character that names do not have",
            pos,
          )
        }
        path.push(piece)
      }
      token.path = path
      token.name = path.join(".")
    }
  }
  for filter in parts[1:] {
    let (name, arg, has_arg) = cut_filter(filter)
    if name == "" {
      continue
    }
    if name == "fmt" && kind == TagKind::Value && has_arg {
      token.format = arg
      token.has_format = true
    } else if name == "fit" &&
      kind == TagKind::Image &&
      (arg == FIT_CONTAIN || arg == FIT_COVER || arg == FIT_STRETCH) {
      token.fit = arg
    } else if (name == INPUT_SIGNATURE || name == INPUT_SEAL) &&
      kind == TagKind::Image &&
      !has_arg &&
      token.input == "" {
      token.input = name
    } else if name == "qr" &&
      kind == TagKind::Image &&
      (!has_arg || (arg.length() == 1 && "LMQH".contains(arg.to_upper()))) {
      token.code = "qr"
      token.level = arg.to_upper()
    } else if name == "barcode" &&
      kind == TagKind::Image &&
      has_arg &&
      barcode_kind(arg) != "" {
      token.code = barcode_kind(arg)
    } else if name == "quiet" &&
      kind == TagKind::Image &&
      has_arg &&
      quiet_arg(arg) >= 0 {
      token.quiet = quiet_arg(arg)
      token.has_quiet = true
    } else if columns &&
      kind == TagKind::Value &&
      has_arg &&
      (name == "width" || name == ALIGN_RIGHT || name == ALIGN_CENTER) &&
      token.width == 0 {
      let width = @string.parse_int(arg) catch { _ => 0 }
      if width < 1 || width > MAX_WIDTH {
        raise TagError(
          "the tag " +
          token.name +
          " takes columns from 1 to " +
          MAX_WIDTH.to_string() +
          ": " +
          tag_trim(filter),
          pos,
        )
      }
      token.width = width
      token.align = if name == "width" { ALIGN_LEFT } else { name }
    } else if columns &&
      kind == TagKind::Value &&
      !has_arg &&
      (name == OVERFLOW_CUT || name == OVERFLOW_WRAP) &&
      token.overflow == "" {
      token.overflow = name
    } else if (kind == TagKind::Open || kind == TagKind::Inverted) &&
      !has_arg &&
      (name == MODE_ROWS ||
        name == MODE_SLOTS ||
        name == MODE_PAGES ||
        name == "block") {
      token.mode = if name == "block" { MODE_ROWS } else { name }
    } else {
      raise TagError(
        "the tag " +
        token.name +
        " has an option it does not take: " +
        tag_trim(filter),
        pos,
      )
    }
  }
  if token.input != "" && token.code != "" {
    raise TagError(
      "the tag {%" +
      token.name +
      "} is a code; it does not take " +
      token.input,
      pos,
    )
  }
  if token.overflow != "" && token.width == 0 {
    raise TagError(
      "the tag " +
      token.name +
      " takes " +
      token.overflow +
      " with its columns only (width:n, right:n or center:n)",
      pos,
    )
  }
  token
}
