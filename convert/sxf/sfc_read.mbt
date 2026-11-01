///|
priv struct SfcArg {
  text : String
  is_str : Bool
}

///|
priv struct SfcFeature {
  name : String
  args : Array[SfcArg]
}

///|
fn SfcFeature::str(self : SfcFeature, index : Int) -> String {
  if index >= 0 && index < self.args.length() {
    self.args[index].text
  } else {
    ""
  }
}

///|
fn SfcFeature::num(self : SfcFeature, index : Int) -> Double {
  if index < 0 || index >= self.args.length() {
    return 0.0
  }
  let text = sfc_trim(self.args[index].text)
  if text == "" {
    return 0.0
  }
  @string.parse_double(text) catch {
    _ => 0.0
  }
}

///|
fn SfcFeature::int(self : SfcFeature, index : Int) -> Int {
  self.num(index).round().to_int()
}

///|
fn sfc_trim(value : StringView) -> String {
  let mut start = 0
  let mut end = value.length()
  while start < end {
    let c = value[start]
    if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      start += 1
    } else {
      break
    }
  }
  while end > start {
    let c = value[end - 1]
    if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      end -= 1
    } else {
      break
    }
  }
  value[start:end].to_owned()
}

///|
fn sfc_list(value : String) -> Array[Double] {
  let text = sfc_trim(value)
  let mut body = text
  if body.has_prefix("(") {
    body = body[1:].to_owned()
  }
  if body.has_suffix(")") {
    body = body[:body.length() - 1].to_owned()
  }
  let output : Array[Double] = []
  for part in body.split(",") {
    let item = sfc_trim(part)
    if item != "" {
      output.push(@string.parse_double(item) catch {
        _ => 0.0
      })
    }
  }
  output
}

///|
fn sfc_feature(body : String) -> SfcFeature? {
  let eq = body.find("=")
  let open = body.find("(")
  let (eq_at, open_at) = match (eq, open) {
    (Some(a), Some(b)) => (a, b)
    _ => return None
  }
  if eq_at < 0 || open_at < eq_at {
    return None
  }
  let name = sfc_trim(body[eq_at + 1:open_at]).to_lower()
  let args : Array[SfcArg] = []
  let rest = body[open_at + 1:]
  let mut index = 0
  while index < rest.length() {
    let c = rest[index].unsafe_to_char()
    if c == ' ' || c == '\t' || c == '\r' || c == '\n' || c == ',' {
      index += 1
    } else if c == ')' {
      break
    } else if c == '\\' && index + 1 < rest.length() && rest[index + 1].unsafe_to_char() == '\'' {
      index += 2
      let start = index
      let output = StringBuilder()
      while index < rest.length() {
        if rest[index].unsafe_to_char() == '\\' && index + 1 < rest.length() &&
          rest[index + 1].unsafe_to_char() == '\'' {
          index += 2
          break
        }
        if rest[index].unsafe_to_char() == '\\' && index + 1 < rest.length() &&
          rest[index + 1].unsafe_to_char() == '\\' {
          output.write_char('\\')
          index += 2
          continue
        }
        output.write_char(rest[index].unsafe_to_char())
        index += 1
      }
      let _ = start
      args.push({ text: output.to_string(), is_str: true })
    } else if c == '\'' {
      let close = rest[index + 1:].find("'")
      match close {
        Some(offset) => {
          args.push({ text: rest[index + 1:index + 1 + offset].to_owned(), is_str: false })
          index += offset + 2
        }
        None => {
          args.push({ text: rest[index + 1:].to_owned(), is_str: false })
          index = rest.length()
        }
      }
    } else {
      let start = index
      let mut depth = 0
      while index < rest.length() {
        let d = rest[index].unsafe_to_char()
        if d == '(' {
          depth += 1
        } else if d == ')' {
          if depth == 0 {
            break
          }
          depth -= 1
        } else if d == ',' && depth == 0 {
          break
        }
        index += 1
      }
      args.push({ text: sfc_trim(rest[start:index]), is_str: false })
    }
  }
  Some({ name, args })
}

///|
fn read_sfc(text : String) -> Array[SfcFeature] raise {
  let output : Array[SfcFeature] = []
  let mut rest = text
  while true {
    let start = rest.find("/*SXF")
    match start {
      None => break
      Some(at) => {
        rest = rest[at + 5:].to_owned()
        while rest.length() > 0 {
          let c = rest[0].unsafe_to_char()
          if (c >= '0' && c <= '9') || c == '.' {
            rest = rest[1:].to_owned()
          } else {
            break
          }
        }
        let close = rest.find("*/")
        match close {
          None => raise Failure("sxf: a feature comment is not closed")
          Some(end) => {
            let mut body = rest[:end].to_owned()
            rest = rest[end + 2:].to_owned()
            let mut last = None
            let mut from = 0
            while from < body.length() {
              match body[from:].find("SXF") {
                Some(value) => {
                  last = Some(from + value)
                  from += value + 3
                }
                None => break
              }
            }
            match last {
              Some(value) => body = body[:value].to_owned()
              None => ()
            }
            match sfc_feature(body) {
              Some(feature) => output.push(feature)
              None => ()
            }
          }
        }
      }
    }
  }
  output
}
