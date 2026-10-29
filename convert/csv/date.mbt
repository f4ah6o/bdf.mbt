///|
fn csv_find(text : String, targets : String, last~ : Bool = false) -> Int32 {
  let mut offset = 0
  let mut found = -1
  for c in text {
    for target in targets {
      if c == target {
        found = offset
        break
      }
    }
    if found >= 0 && !last {
      return found
    }
    offset += if c.to_int() > 0xffff { 2 } else { 1 }
  }
  found
}

///|
fn csv_int(text : String) -> Int64 {
  @string.parse_int64(text) catch {
    _ => 9223372036854775807L
  }
}

///|
/// Recognize the date and time forms used by upstream CSV classification.
pub fn looks_date_time(value : String) -> Bool {
  let text = csv_trim(value)
  if csv_time(text) || csv_date(text) {
    return true
  }
  let i = csv_find(text, "T ")
  i > 0 &&
  csv_date(text[:i].to_owned()) &&
  csv_time(csv_trim(text[i + 1:].to_owned()))
}

///|
fn csv_time(value : String) -> Bool {
  let mut text = value
  let upper = text.to_upper()
  for suffix in [" AM", " PM", "AM", "PM"] {
    if upper.has_suffix(suffix) {
      text = text[:text.length() - suffix.length()].to_owned()
      break
    }
  }
  if text.has_suffix("Z") {
    text = text[:text.length() - 1].to_owned()
  } else {
    let i = csv_find(text, "+-", last=true)
    if i > 0 {
      let zone = text[i + 1:].to_owned()
      if !csv_clock(zone, 2) && !(zone.length() == 4 && csv_digits(zone)) {
        return false
      }
      text = text[:i].to_owned()
    }
  }
  csv_clock(text, 3)
}

///|
fn csv_clock(value : String, parts : Int32) -> Bool {
  let mut text = value
  if !text.contains(":") {
    return false
  }
  let i = csv_find(text, ".")
  if i > 0 {
    if !csv_digits(text[i + 1:].to_owned()) {
      return false
    }
    text = text[:i].to_owned()
  }
  let fields = [ for field in text.split(":") => field.to_owned() ]
  if fields.length() < 2 || fields.length() > parts {
    return false
  }
  for i, field in fields {
    if !csv_digits(field) ||
      field.length() > 2 ||
      (i > 0 && field.length() != 2) {
      return false
    }
    let n = csv_int(field)
    if (i == 0 && n > 24) || (i > 0 && n > 59) {
      return false
    }
  }
  true
}

///|
fn csv_date(text : String) -> Bool {
  if csv_japanese_date(text) || csv_named_date(text) {
    return true
  }
  let i = csv_find(text, "-/.")
  if i <= 0 {
    return false
  }
  let sep = text[i:i + 1].to_owned()
  let fields = [ for field in text.split(sep) => field.to_owned() ]
  for field in fields {
    if !csv_digits(field) || field.length() > 4 {
      return false
    }
  }
  if fields.length() == 3 {
    let a = csv_int(fields[0])
    let b = csv_int(fields[1])
    let c = csv_int(fields[2])
    if fields[0].length() == 4 {
      return csv_valid_day(a, b, c)
    }
    if fields[2].length() == 4 || (fields[2].length() == 2 && sep == "/") {
      return fields[0].length() <= 2 &&
        fields[1].length() <= 2 &&
        (csv_valid_day(c, a, b) || csv_valid_day(c, b, a))
    }
  } else if fields.length() == 2 {
    if sep == "/" && fields[0].length() <= 2 && fields[1].length() <= 2 {
      return csv_valid_day(2000, csv_int(fields[0]), csv_int(fields[1]))
    }
    if fields[0].length() == 4 && sep != "." && fields[1].length() <= 2 {
      let month = csv_int(fields[1])
      return month >= 1 && month <= 12
    }
  }
  false
}

///|
fn csv_valid_day(year : Int64, month : Int64, day : Int64) -> Bool {
  if month < 1 || month > 12 || day < 1 {
    return false
  }
  let days = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  let limit = if month == 2 &&
    !(year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) {
    28
  } else {
    days[month.to_int() - 1]
  }
  day <= limit.to_int64()
}

///|
fn csv_named_date(value : String) -> Bool {
  let mut letters = false
  let mut digits = false
  for c in value {
    if (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') {
      letters = true
    }
    if c >= '0' && c <= '9' {
      digits = true
    }
  }
  if !letters || !digits {
    return false
  }
  let fields : Array[String] = []
  let current = StringBuilder()
  for c in value.to_lower() {
    if c == ' ' || c == '-' || c == ',' || c == '/' {
      let field = current.to_string()
      if field != "" {
        fields.push(field)
        current.reset()
      }
    } else {
      current.write_char(c)
    }
  }
  let field = current.to_string()
  if field != "" {
    fields.push(field)
  }
  if fields.length() < 2 || fields.length() > 3 {
    return false
  }
  let months = [
    "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov",
    "dec",
  ]
  let mut month = false
  let mut numbers = 0
  for part in fields {
    if csv_digits(part) && part.length() <= 4 {
      numbers += 1
      continue
    }
    for name in months {
      if part.length() >= 3 && part.has_prefix(name) && !month {
        month = true
      }
    }
    if !month {
      return false
    }
  }
  month && numbers == fields.length() - 1
}

///|
fn csv_japanese_date(text : String) -> Bool {
  for
    era in [
      "明治", "大正", "昭和", "平成", "令和", "M", "T", "S", "H", "R",
    ] {
    if !text.has_prefix(era) {
      continue
    }
    let mut rest = text[era.length():].to_owned()
    if rest.has_prefix("元年") {
      rest = "1年" + rest[2:].to_owned()
    }
    if rest == "" || csv_find(rest, "0123456789") != 0 {
      continue
    }
    if rest.contains(".") {
      let fields = [ for field in rest.split(".") => field.to_owned() ]
      return fields.length() == 3 &&
        csv_digits(fields[0]) &&
        csv_digits(fields[1]) &&
        csv_digits(fields[2])
    }
    return csv_kanji_date(rest, true)
  }
  csv_kanji_date(text, false)
}

///|
fn csv_kanji_date(text : String, era : Bool) -> Bool {
  let mut rest = text
  let mut year = ""
  let mut day = ""
  let year_at = csv_find(rest, "年")
  if year_at > 0 {
    year = rest[:year_at].to_owned()
    rest = rest[year_at + 1:].to_owned()
  }
  let month_at = csv_find(rest, "月")
  if month_at <= 0 {
    return false
  }
  let month = rest[:month_at].to_owned()
  rest = rest[month_at + 1:].to_owned()
  let day_at = csv_find(rest, "日")
  if day_at > 0 {
    day = rest[:day_at].to_owned()
    rest = rest[day_at + 1:].to_owned()
  }
  if rest != "" ||
    !csv_digits(month) ||
    (year != "" && !csv_digits(year)) ||
    (day != "" && !csv_digits(day)) ||
    (year == "" && day == "") {
    return false
  }
  let m = csv_int(month)
  if day == "" {
    return m >= 1 && m <= 12
  }
  let y = if year == "" || era { 2000L } else { csv_int(year) }
  csv_valid_day(y, m, csv_int(day))
}
