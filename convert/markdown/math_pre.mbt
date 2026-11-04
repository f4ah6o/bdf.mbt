///|
fn md_math_placeholder(index : Int) -> String {
  "\uE000" + index.to_string() + "\uE001"
}

///|
fn md_inline_math(line : String, formulas : Array[String]) -> String {
  let out = StringBuilder()
  let chars = line.to_array()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == '\u0060' {
      let mut ticks = 1
      while i + ticks < chars.length() && chars[i + ticks] == '\u0060' {
        ticks += 1
      }
      out.write_string(String::from_array(chars[i:i + ticks]))
      i += ticks
      let tick_text = StringBuilder()
      for _ in 0..<ticks {
        tick_text.write_char('\u0060')
      }
      let close = String::from_array(chars[i:]).find(tick_text.to_string())
      match close {
        Some(index) => {
          out.write_string(String::from_array(chars[i:i + index + ticks]))
          i += index + ticks
        }
        None => ()
      }
      continue
    }
    if c == '\\' && i + 1 < chars.length() {
      out.write_char(c)
      out.write_char(chars[i + 1])
      i += 2
      continue
    }
    if c == '$' {
      if i + 1 < chars.length() && chars[i + 1] == '$' {
        let mut close = i + 2
        while close + 1 < chars.length() &&
          !(chars[close] == '$' && chars[close + 1] == '$') {
          close += 1
        }
        if close + 1 < chars.length() {
          let body = String::from_array(chars[i + 2:close])
          let index = formulas.length()
          formulas.push(body)
          out.write_string(md_math_placeholder(index))
          i = close + 2
          continue
        }
      }
      if i + 2 < chars.length() &&
        chars[i + 1] == '\u0060' {
        let mut close = i + 2
        while close < chars.length() && chars[close] != '\u0060' {
          close += 1
        }
        if close + 1 < chars.length() && chars[close + 1] == '$' {
          let body = String::from_array(chars[i + 2:close])
          let index = formulas.length()
          formulas.push(body)
          out.write_string(md_math_placeholder(index))
          i = close + 2
          continue
        }
      }
      let mut close = i + 1
      while close < chars.length() && chars[close] != '$' {
        close += 1
      }
      let valid = close < chars.length() &&
        close > i + 1 &&
        chars[i + 1] != ' ' &&
        chars[close - 1] != ' ' &&
        chars[i + 1] != '\n'
      if valid {
        let body = String::from_array(chars[i + 1:close])
        let index = formulas.length()
        formulas.push(body)
        out.write_string(md_math_placeholder(index))
        i = close + 1
        continue
      }
    }
    out.write_char(c)
    i += 1
  }
  out.to_string()
}

///|
fn md_parse_math_before(text : String, formulas : Array[String]) -> String {
  let out = StringBuilder()
  let lines = text.split("\n").to_array()
  let mut i = 0
  let mut fenced = false
  let mut fence = ""
  while i < lines.length() {
    let line = lines[i].to_owned()
    let trimmed = line.trim()
    if fenced {
      out.write_string(line)
      out.write_char('\n')
      if trimmed.has_prefix(fence) {
        fenced = false
      }
      i += 1
      continue
    }
    if trimmed.has_prefix("\u0060\u0060\u0060") || trimmed.has_prefix("~~~") {
      fenced = true
      fence = trimmed[:3].to_owned()
      out.write_string(line)
      out.write_char('\n')
      i += 1
      continue
    }
    if trimmed == "$$" {
      let body = StringBuilder()
      i += 1
      while i < lines.length() && lines[i].trim().to_owned() != "$$" {
        if body.to_string() != "" {
          body.write_char('\n')
        }
        body.write_string(lines[i].to_owned())
        i += 1
      }
      if i < lines.length() {
        i += 1
      }
      let index = formulas.length()
      formulas.push(body.to_string())
      out.write_string(md_math_placeholder(index))
      out.write_char('\n')
      out.write_char('\n')
      continue
    }
    if trimmed.has_prefix("$$") && trimmed.has_suffix("$$") && trimmed.length() > 4 {
      let body = trimmed[2:trimmed.length() - 2].to_owned()
      let index = formulas.length()
      formulas.push(body)
      out.write_string(md_math_placeholder(index))
      out.write_char('\n')
      out.write_char('\n')
      i += 1
      continue
    }
    out.write_string(md_inline_math(line, formulas))
    out.write_char('\n')
    i += 1
  }
  out.to_string()
}
