///|
fn csv_trim(text : String) -> String {
  let output = StringBuilder()
  let pending = StringBuilder()
  let mut started = false
  for c in text {
    if c.is_whitespace() {
      if started {
        pending.write_char(c)
      }
    } else {
      if started {
        output.write_string(pending.to_string())
        pending.reset()
      }
      output.write_char(c)
      started = true
    }
  }
  output.to_string()
}

///|
fn csv_digits(text : String) -> Bool {
  if text == "" {
    return false
  }
  for c in text {
    if c < '0' || c > '9' {
      return false
    }
  }
  true
}

///|
/// Classify the textual numeric forms used by upstream when guessing CSV
/// dialects and headers. Integers with leading zeroes remain text.
pub fn looks_numeric(value : String) -> Bool {
  let mut text = csv_trim(value)
  let mut negative = false
  if text.length() > 2 && text.has_prefix("(") && text.has_suffix(")") {
    text = csv_trim(text[1:text.length() - 1].to_owned())
    negative = true
  }
  if text != "" && (text.has_prefix("+") || text.has_prefix("-")) && !negative {
    text = csv_trim(text[1:].to_owned())
  }
  for currency in ["$", "€", "£", "¥", "￥", "₩", "₹", "¢"] {
    if text.has_prefix(currency) {
      text = csv_trim(text[currency.length():].to_owned())
      break
    }
  }
  if text != "" && (text.has_prefix("+") || text.has_prefix("-")) && !negative {
    text = text[1:].to_owned()
  }
  if text.has_suffix("%") {
    text = csv_trim(text[:text.length() - 1].to_owned())
  }
  let mantissa = StringBuilder()
  let exponent = StringBuilder()
  let mut found_exponent = false
  for c in text {
    if !found_exponent && (c == 'e' || c == 'E') && mantissa.to_string() != "" {
      found_exponent = true
    } else if found_exponent {
      exponent.write_char(c)
    } else {
      mantissa.write_char(c)
    }
  }
  if found_exponent {
    let mut e = exponent.to_string()
    if e.has_prefix("+") || e.has_prefix("-") {
      e = e[1:].to_owned()
    }
    if !csv_digits(e) {
      return false
    }
  }
  csv_decimal(mantissa.to_string(), !found_exponent)
}

///|
fn csv_decimal(text : String, grouped : Bool) -> Bool {
  if text == "" {
    return false
  }
  let groups : Array[String] = []
  let separators : Array[Char] = []
  let current = StringBuilder()
  for c in text {
    if c >= '0' && c <= '9' {
      current.write_char(c)
      continue
    }
    if c != '.' &&
      c != ',' &&
      c != '\'' &&
      c != ' ' &&
      c != '\u{a0}' &&
      c != '\u{202f}' {
      return false
    }
    groups.push(current.to_string())
    current.reset()
    separators.push(c)
  }
  groups.push(current.to_string())
  let first = groups[0]
  let code = first.length() > 1 && first.has_prefix("0")
  if separators.length() == 0 {
    return !code
  }
  if separators.length() == 1 && (separators[0] == '.' || separators[0] == ',') {
    return (first != "" || groups[1] != "") && !code
  }
  if !grouped {
    return false
  }
  let mut thousands = separators.length()
  let last = separators[thousands - 1]
  if last != separators[0] {
    if (last != '.' && last != ',') || groups[thousands] == "" {
      return false
    }
    thousands -= 1
  }
  if first == "" || first.length() > 3 || first.has_prefix("0") {
    return false
  }
  for i in 1..<=thousands {
    if separators[i - 1] != separators[0] || groups[i].length() != 3 {
      return false
    }
  }
  true
}
