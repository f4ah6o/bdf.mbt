///|
// The paper of a plain-text form template: the front matter of the file.
pub const MAX_COLUMNS : Int = 4096
pub const MAX_LINES : Int = 4096

///|
pub suberror TextFormError {
  TextFormError(String)
}

///|
pub(all) struct Grid {
  mut cpi : Double
  mut lpi : Double
  mut columns : Int
  mut lines : Int
  mut left : Int
  mut top : Int
  mut skip : Int
  mut title : Int
  mut font : String
  mut ambiguous_wide : Bool
}

///|
pub fn default_grid() -> Grid {
  {
    cpi: 10.0,
    lpi: 6.0,
    columns: 80,
    lines: 66,
    left: 0,
    top: 0,
    skip: 0,
    title: 0,
    font: "",
    ambiguous_wide: false,
  }
}

///|
pub fn Grid::rows(self : Grid) -> Int {
  if self.lines == 0 {
    0
  } else {
    self.lines - self.top - self.skip
  }
}

///|
pub fn Grid::width(self : Grid) -> Int {
  self.columns - self.left
}

///|
fn rtrim_space_tab(value : String) -> String {
  let chars = value.to_array()
  let mut end = chars.length()
  while end > 0 &&
    (chars[end - 1] == ' ' ||
      chars[end - 1] == '\t' ||
      chars[end - 1] == '\n' ||
      chars[end - 1] == '\r') {
    end -= 1
  }
  if end == chars.length() {
    value
  } else {
    String::from_array(chars[:end])
  }
}

///|
fn split_after_newline(text : String) -> Array[String] {
  let parts = text.split("\n").to_array()
  let out : Array[String] = []
  for i, part in parts {
    if i < parts.length() - 1 {
      out.push(part.to_owned() + "\n")
    } else {
      out.push(part.to_owned())
    }
  }
  out
}

///|
/// Cut the front matter off a template: the lines between a first line
/// "---" and the next "---" or "...". Return the front matter, the body,
/// the number of the body's first line, and whether it had one.
pub fn split_front_matter(
  text : String,
) -> (Array[String], String, Int, Bool) {
  if !text.has_prefix("---\n") && text != "---" {
    return ([], text, 1, false)
  }
  let lines = split_after_newline(text)
  let mut i = 1
  while i < lines.length() {
    let line = rtrim_space_tab(lines[i])
    if line == "---" || line == "..." {
      let front : Array[String] = []
      for j in 1..<i {
        let value = lines[j]
        front.push(
          if value.has_suffix("\n") {
            value[:value.length() - 1].to_owned()
          } else {
            value
          },
        )
      }
      let body_lines : Array[String] = []
      for j in (i + 1)..<lines.length() {
        body_lines.push(lines[j])
      }
      return (front, body_lines.join(""), i + 2, true)
    }
    i += 1
  }
  ([], text, 1, false)
}

///|
/// Drop a comment: from a # that starts the line or follows a space or a
/// tab, outside quotes.
pub fn strip_comment(value : String) -> String {
  let chars = value.to_array()
  let out = StringBuilder()
  let mut quote = '\u{0}'
  for i, c in chars {
    if quote != '\u{0}' {
      if c == quote {
        quote = '\u{0}'
      }
      out.write_char(c)
    } else if c == '"' || c == '\'' {
      quote = c
      out.write_char(c)
    } else if c == '#' &&
      (i == 0 || chars[i - 1] == ' ' || chars[i - 1] == '\t') {
      break
    } else {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
/// Read a scalar: quoted or plain.
pub fn unquote(value : String) -> String {
  let chars = value.to_array()
  if chars.length() >= 2 &&
    ((chars[0] == '"' && chars[chars.length() - 1] == '"') ||
      (chars[0] == '\'' && chars[chars.length() - 1] == '\'')) {
    let inner = String::from_array(chars[1:chars.length() - 1])
    if chars[0] == '\'' {
      return inner.replace(old="''", new="'")
    }
    let out = StringBuilder()
    let inner_chars = inner.to_array()
    let mut i = 0
    while i < inner_chars.length() {
      let c = inner_chars[i]
      if c == '\\' && i + 1 < inner_chars.length() {
        let next = inner_chars[i + 1]
        out.write_char(
          match next {
            'n' => '\n'
            't' => '\t'
            'r' => '\r'
            '"' => '"'
            '\\' => '\\'
            _ => next
          },
        )
        i += 2
      } else {
        out.write_char(c)
        i += 1
      }
    }
    return out.to_string()
  }
  value
}

///|
fn cut_colon(value : String) -> (String, String, Bool) {
  let chars = value.to_array()
  let mut at = -1
  for i, c in chars {
    if c == ':' {
      at = i
      break
    }
  }
  if at < 0 {
    (value, "", false)
  } else {
    (
      String::from_array(chars[:at]),
      String::from_array(chars[at + 1:]),
      true,
    )
  }
}

///|
fn textform_number(key : String, value : String, lo : Double, hi : Double) -> Double raise TextFormError {
  let number = @string.parse_double(value[:]) catch {
    _ => raise TextFormError("text: the front matter: " + key + " is " + value)
  }
  if number.is_nan() || number < lo || number > hi {
    raise TextFormError(
      "text: the front matter: " +
      key +
      " is " +
      value +
      "; it takes a number from " +
      lo.to_string() +
      " to " +
      hi.to_string(),
    )
  }
  number
}

///|
fn textform_whole(key : String, value : String, lo : Int, hi : Int) -> Int raise TextFormError {
  let number = @string.parse_int(value[:]) catch {
    _ => raise TextFormError("text: the front matter: " + key + " is " + value)
  }
  if number < lo || number > hi {
    raise TextFormError(
      "text: the front matter: " +
      key +
      " is " +
      value +
      "; it takes a whole number from " +
      lo.to_string() +
      " to " +
      hi.to_string(),
    )
  }
  number
}

///|
fn textform_is_pitch(cpi : Double) -> Bool {
  cpi == 10.0 ||
  cpi == 12.0 ||
  cpi == 15.0 ||
  cpi == 17.0 ||
  cpi == 17.1 ||
  cpi == 17.14 ||
  cpi == 20.0
}

///|
/// Read the front matter: the keys of the grid, in the part of YAML that
/// they need (keys and plain or quoted scalars, a flow mapping or an
/// indented block for the margin, and comments).
pub fn parse_front_matter(
  lines : Array[String],
  warnings : Array[String],
) -> Grid raise TextFormError {
  let grid = default_grid()
  let set : Map[String, String] = Map([])
  let order : Array[String] = []
  let mut block = ""
  for i, raw in lines {
    let line = rtrim_space_tab(strip_comment(raw))
    if line.trim() == "" {
      continue
    }
    let at = fn(message : String) -> TextFormError {
      TextFormError("text: the front matter, line " + (i + 2).to_string() + ": " + message)
    }
    let indented = line.to_array()[0] == ' ' || line.to_array()[0] == '\t'
    let trimmed = line.trim().to_owned()
    let (key_part, value_part, ok) = cut_colon(trimmed)
    let mut key = key_part.trim().to_owned()
    let value = value_part.trim().to_owned()
    if !ok || key == "" {
      raise at("\"" + trimmed + "\" is not a key and its value (key: value)")
    }
    if indented {
      if block == "" {
        raise at("\"" + key + "\" is indented under no key")
      }
      key = block + "." + key
    } else {
      block = ""
      if value == "" {
        block = key
        continue
      }
    }
    if value.has_prefix("{") {
      if !value.has_suffix("}") {
        raise at("the mapping of " + key + " is not closed with }")
      }
      let inner = value[1:value.length() - 1]
      for entry in inner.split(",") {
        if entry.trim() == "" {
          continue
        }
        let entry_text = entry.trim().to_owned()
        let (k, v, ok) = cut_colon(entry_text)
        if !ok {
          raise at(
            "\"" + entry_text + "\" in the mapping of " + key + " is not a key and its value",
          )
        }
        let name = key + "." + k.trim().to_owned()
        if !set.contains(name) {
          order.push(name)
        }
        set[name] = unquote(v.trim().to_owned())
      }
      continue
    }
    if !set.contains(key) {
      order.push(key)
    }
    set[key] = unquote(value)
  }
  for key in order {
    let value = set[key]
    if key == "cpi" {
      grid.cpi = textform_number(key, value, 1.0, 30.0)
      if !textform_is_pitch(grid.cpi) {
        warnings.push(
          "the front matter: " +
          grid.cpi.to_string() +
          " CPI is not a pitch of ESC/P (10, 12, 15, 17.1 or 20); the text mode of a printer prints at the nearest one",
        )
      }
    } else if key == "lpi" {
      grid.lpi = textform_number(key, value, 1.0, 30.0)
    } else if key == "columns" {
      grid.columns = textform_whole(key, value, 1, MAX_COLUMNS)
    } else if key == "lines" {
      grid.lines = textform_whole(key, value, 0, MAX_LINES)
    } else if key == "margin.left" {
      grid.left = textform_whole(key, value, 0, MAX_COLUMNS)
    } else if key == "margin.top" {
      grid.top = textform_whole(key, value, 0, MAX_LINES)
    } else if key == "skip" {
      grid.skip = textform_whole(key, value, 0, MAX_LINES)
    } else if key == "title" {
      grid.title = textform_whole(key, value, 0, MAX_LINES)
    } else if key == "font" {
      grid.font = value
    } else if key == "ambiguous" {
      let lowered = value.to_lower()
      if lowered == "narrow" || lowered == "1" {
        grid.ambiguous_wide = false
      } else if lowered == "wide" || lowered == "2" {
        grid.ambiguous_wide = true
      } else {
        raise TextFormError(
          "text: the front matter: ambiguous is " +
          value +
          "; it is narrow or wide",
        )
      }
    } else {
      warnings.push("the front matter has " + key + ", which a template of text does not read")
    }
  }
  if grid.left >= grid.columns {
    raise TextFormError(
      "text: the front matter: the left margin of " +
      grid.left.to_string() +
      " columns leaves no column of the " +
      grid.columns.to_string() +
      " of the paper",
    )
  }
  if grid.lines > 0 && grid.top + grid.skip >= grid.lines {
    raise TextFormError(
      "text: the front matter: the top margin and the skip (" +
      grid.top.to_string() +
      " and " +
      grid.skip.to_string() +
      " lines) leave no line of the " +
      grid.lines.to_string() +
      " of the paper",
    )
  }
  if grid.lines > 0 && grid.title >= grid.rows() {
    raise TextFormError(
      "text: the front matter: the " +
      grid.title.to_string() +
      " lines of the title leave no line of the " +
      grid.rows().to_string() +
      " of a page",
    )
  }
  grid
}
