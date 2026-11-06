///|
/// The data that the tags at a place of a template see: the item of the
/// section they are in, inside the items of the sections around it.
pub struct Scope {
  parent : Scope?
  value : Json
  vars : Map[String, Json]
  blank : Bool
}

///|
pub fn Scope::new(root : Json) -> Scope {
  { parent: None, value: root, vars: Map([]), blank: false }
}

///|
pub fn Scope::item(
  self : Scope,
  value : Json,
  vars : Map[String, Json],
) -> Scope {
  { parent: Some(self), value, vars, blank: false }
}

///|
/// The scope of a place that no item fills: only variables are found.
pub fn Scope::blank_scope(
  self : Scope,
  vars : Map[String, Json],
) -> Scope {
  { parent: Some(self), value: Json::null(), vars, blank: true }
}

///|
pub fn Scope::value(self : Scope) -> Json {
  self.value
}

///|
pub fn Scope::is_blank(self : Scope) -> Bool {
  let mut current : Scope? = Some(self)
  while current is Some(scope) {
    if scope.blank {
      return true
    }
    current = scope.parent
  }
  false
}

///|
/// Find the value of a name: the first part from the item outwards, the
/// others in the value found.
pub fn Scope::lookup(self : Scope, path : Array[String]) -> Json? {
  guard !path.is_empty() else { return None }
  if path.length() == 1 && path[0] == "." {
    return if self.blank { None } else { Some(self.value) }
  }
  let mut current : Scope? = Some(self)
  let mut found : Json? = None
  let mut vars_only = false
  while current is Some(scope) && found is None {
    if scope.vars.contains(path[0]) {
      found = Some(scope.vars[path[0]])
    } else if !vars_only {
      match scope.value {
        Json::Object(map) =>
          if map.contains(path[0]) {
            found = Some(map[path[0]])
          }
        _ => ()
      }
    }
    vars_only = vars_only || scope.blank
    current = scope.parent
  }
  match found {
    None => None
    Some(value) => {
      let mut result = value
      for part in path[1:] {
        match result {
          Json::Object(map) =>
            match map.get(part) {
              Some(next) => result = next
              None => return None
            }
          _ => return None
        }
      }
      Some(result)
    }
  }
}

///|
/// Whether a value shows a section: not null, false, zero, an empty string
/// or an empty list.
pub fn truthy(value : Json) -> Bool {
  match value {
    Json::Null => false
    Json::True => true
    Json::False => false
    Json::Number(v, ..) => v != 0.0
    Json::String(v) => v != ""
    Json::Array(v) => !v.is_empty()
    Json::Object(_) => true
  }
}

///|
/// What a section of a value repeats: the items of a list, the value itself
/// when it is another true value, and nothing when it is false.
pub fn items(value : Json) -> Array[Json] {
  match value {
    Json::Array(values) => values
    _ => if truthy(value) { [value] } else { [] }
  }
}

///|
/// The values of JSON are already the values that templates are filled with.
pub fn normalize(value : Json) -> Json {
  value
}

///|
fn date_digits(value : String, start : Int, count : Int) -> Int? {
  let chars = value.to_array()
  if start + count > chars.length() {
    return None
  }
  let mut number = 0
  for i in 0..<count {
    let c = chars[start + i]
    let code = c.to_int()
    if code < 48 || code > 57 {
      return None
    }
    number = number * 10 + (code - 48)
  }
  Some(number)
}

///|
fn date_two(value : String, start : Int) -> Int? {
  date_digits(value, start, 2)
}

///|
fn date_pad(number : Int) -> String {
  if number < 10 {
    "0" + number.to_string()
  } else {
    number.to_string()
  }
}

///|
/// Read a date as data writes it and return it as RFC 3339 in UTC, or none
/// when it is not a date. The time is the clock on the wall: the zone is
/// dropped.
pub fn parse_date(value : String) -> String? {
  let text = tag_trim(value)
  let chars = text.to_array()
  if chars.length() < 8 || chars.length() > 40 {
    return None
  }
  let first = chars[0].to_int()
  if first < 48 || first > 57 {
    return None
  }
  let year = match date_digits(text, 0, 4) {
    Some(v) => v
    None => return None
  }
  if chars.length() < 7 {
    return None
  }
  let separator = chars[4]
  if separator != '-' && separator != '/' {
    return None
  }
  let mut at = 5
  let month = match date_digits(text, at, 1) {
    Some(v) => v
    None => return None
  }
  at += 1
  let month = if at < chars.length() && chars[at].to_int() >= 48 && chars[at].to_int() <= 57 {
    let two = date_digits(text, at - 1, 2)
    at += 1
    two.unwrap_or(month)
  } else {
    month
  }
  if at >= chars.length() || chars[at] != separator {
    return None
  }
  at += 1
  let day = match date_digits(text, at, 1) {
    Some(v) => v
    None => return None
  }
  at += 1
  let day = if at < chars.length() && chars[at].to_int() >= 48 && chars[at].to_int() <= 57 {
    let two = date_digits(text, at - 1, 2)
    at += 1
    two.unwrap_or(day)
  } else {
    day
  }
  if month < 1 || month > 12 || day < 1 || day > 31 {
    return None
  }
  let mut hour = 0
  let mut minute = 0
  let mut second = 0
  if at < chars.length() {
    if chars[at] != 'T' && chars[at] != 't' && chars[at] != ' ' {
      return None
    }
    at += 1
    hour = date_two(text, at).unwrap_or(-1)
    if hour < 0 {
      return None
    }
    at += 2
    if at >= chars.length() || chars[at] != ':' {
      return None
    }
    at += 1
    minute = date_two(text, at).unwrap_or(-1)
    if minute < 0 {
      return None
    }
    at += 2
    if at < chars.length() && chars[at] == ':' {
      at += 1
      second = date_two(text, at).unwrap_or(-1)
      if second < 0 {
        return None
      }
      at += 2
    }
    if at < chars.length() {
      if chars[at] == '.' {
        at += 1
        while at < chars.length() &&
          chars[at].to_int() >= 48 &&
          chars[at].to_int() <= 57 {
          at += 1
        }
      }
      if at < chars.length() && (chars[at] == 'Z' || chars[at] == 'z') {
        at += 1
      } else if at < chars.length() && (chars[at] == '+' || chars[at] == '-') {
        at += 1
        while at < chars.length() {
          let c = chars[at]
          if c == ':' || (c.to_int() >= 48 && c.to_int() <= 57) {
            at += 1
          } else {
            break
          }
        }
      }
    }
    if at != chars.length() {
      return None
    }
    if hour > 23 || minute > 59 || second > 59 {
      return None
    }
  }
  let date = year.to_string() +
    "-" +
    date_pad(month) +
    "-" +
    date_pad(day)
  if hour == 0 && minute == 0 && second == 0 {
    Some(date + "T00:00:00Z")
  } else if second == 0 {
    Some(date + "T" + date_pad(hour) + ":" + date_pad(minute) + ":00Z")
  } else {
    Some(
      date +
      "T" +
      date_pad(hour) +
      ":" +
      date_pad(minute) +
      ":" +
      date_pad(second) +
      "Z",
    )
  }
}

///|
pub type Formatter = (Json, String) -> String

///|
/// Write a value as the text that replaces a tag: in its number format,
/// dates as yyyy-mm-dd, booleans as TRUE/FALSE, nothing for no value.
pub fn value_text(value : Json, format : String, formatter : Formatter?) -> String {
  match formatter {
    Some(f) =>
      if format != "" {
        match value {
          Json::Number(_, ..) | Json::String(_) | Json::True | Json::False =>
            return f(value, format)
          _ => ()
        }
      }
    None => ()
  }
  match value {
    Json::String(text) => text
    Json::True => "TRUE"
    Json::False => "FALSE"
    Json::Number(number, ..) =>
      match formatter {
        Some(f) => f(value, "")
        None => number.to_string()
      }
    _ => ""
  }
}

///|
/// The variables of item k of n: _index, _count, _first, _last and, for a
/// page item, _page and _pages.
pub fn vars(k : Int, n : Int, page : Bool) -> Map[String, Json] {
  let out : Map[String, Json] = Map([])
  out["_index"] = Json::number((k + 1).to_double())
  out["_count"] = Json::number(n.to_double())
  out["_first"] = Json::boolean(k == 0)
  out["_last"] = Json::boolean(k == n - 1)
  if page {
    out["_page"] = Json::number((k + 1).to_double())
    out["_pages"] = Json::number(n.to_double())
  }
  out
}
