///|
fn expr_lookup(values : Json, name : String) -> Json? {
  let mut current = values
  for part in name.split(".") {
    current = match current {
      Json::Object(object) =>
        match object.get(part.to_owned()) {
          Some(value) => value
          None => return None
        }
      _ => return None
    }
  }
  Some(current)
}

///|
struct ExprParser {
  chars : Array[Char]
  mut pos : Int
  values : Json
}

///|
fn ExprParser::skip(self : ExprParser) -> Unit {
  while self.pos < self.chars.length() {
    let c = self.chars[self.pos]
    if c == ' ' || c == '\t' {
      self.pos += 1
    } else {
      break
    }
  }
}

///|
fn ExprParser::number(self : ExprParser) -> Double? {
  self.skip()
  let start = self.pos
  let mut dot = false
  while self.pos < self.chars.length() {
    let c = self.chars[self.pos]
    if c >= '0' && c <= '9' {
      self.pos += 1
    } else if c == '.' && !dot {
      dot = true
      self.pos += 1
    } else {
      break
    }
  }
  if self.pos == start {
    return None
  }
  let text = StringBuilder()
  for i in start..<self.pos {
    text.write_char(self.chars[i])
  }
  try {
    Some(@string.parse_double(text.to_string()))
  } catch {
    _ => None
  }
}

///|
fn ExprParser::identifier(self : ExprParser) -> String? {
  self.skip()
  let start = self.pos
  while self.pos < self.chars.length() {
    let c = self.chars[self.pos]
    if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') || c == '_' || c == '.' {
      self.pos += 1
    } else {
      break
    }
  }
  if self.pos == start {
    return None
  }
  let text = StringBuilder()
  for i in start..<self.pos {
    text.write_char(self.chars[i])
  }
  Some(text.to_string())
}

///|
fn expr_value(value : Json) -> Double? {
  match value {
    Json::Number(number, ..) => Some(number)
    Json::String(text) =>
      try {
        Some(@string.parse_double(text.replace(old=",", new="")))
      } catch {
        _ => None
      }
    _ => None
  }
}

///|
fn ExprParser::factor(self : ExprParser) -> Double? {
  self.skip()
  if self.pos >= self.chars.length() {
    return None
  }
  let c = self.chars[self.pos]
  if c == '-' {
    self.pos += 1
    match self.factor() {
      Some(value) => Some(-value)
      None => None
    }
  } else if c == '(' {
    self.pos += 1
    let value = self.expr()
    self.skip()
    if self.pos < self.chars.length() && self.chars[self.pos] == ')' {
      self.pos += 1
      value
    } else {
      None
    }
  } else if c >= '0' && c <= '9' {
    self.number()
  } else {
    let name = match self.identifier() {
      Some(name) => name
      None => return None
    }
    match expr_lookup(self.values, name) {
      Some(value) => expr_value(value)
      None => None
    }
  }
}

///|
fn ExprParser::term(self : ExprParser) -> Double? {
  let mut value = match self.factor() {
    Some(value) => value
    None => return None
  }
  while true {
    self.skip()
    if self.pos >= self.chars.length() {
      break
    }
    let op = self.chars[self.pos]
    if op == '*' || op == '/' || op == '%' {
      self.pos += 1
      let right = match self.factor() {
        Some(value) => value
        None => return None
      }
      if (op == '/' || op == '%') && right == 0.0 {
        return None
      }
      value = if op == '*' {
        value * right
      } else if op == '/' {
        value / right
      } else {
        value % right
      }
    } else {
      break
    }
  }
  Some(value)
}

///|
fn ExprParser::expr(self : ExprParser) -> Double? {
  let mut value = match self.term() {
    Some(value) => value
    None => return None
  }
  while true {
    self.skip()
    if self.pos >= self.chars.length() {
      break
    }
    let op = self.chars[self.pos]
    if op == '+' || op == '-' {
      self.pos += 1
      let right = match self.term() {
        Some(value) => value
        None => return None
      }
      value = if op == '+' { value + right } else { value - right }
    } else {
      break
    }
  }
  Some(value)
}

///|
fn eval_expression(text : String, values : Json) -> Double? {
  let parser : ExprParser = { chars: text.to_array(), pos: 0, values }
  let value = parser.expr()
  parser.skip()
  if parser.pos != parser.chars.length() {
    None
  } else {
    value
  }
}

///|
fn format_expr_number(value : Double) -> String {
  if value == @math.floor(value) && value >= -9007199254740992.0 &&
    value <= 9007199254740992.0 {
    value.to_int64().to_string()
  } else {
    value.to_string()
  }
}

