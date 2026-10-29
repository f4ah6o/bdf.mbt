///|
// Empty, text, number, date, boolean, email and URL have the same order as
// upstream's value classes; that order breaks ties in the dominant class.
fn csv_kind(value : String) -> Int32 {
  let text = csv_trim(value)
  if text == "" {
    return 0
  }
  if looks_numeric(text) {
    return 2
  }
  if looks_date_time(text) {
    return 3
  }
  let lower = text.to_lower()
  if lower == "true" || lower == "false" {
    return 4
  }
  if text.has_prefix("http://") || text.has_prefix("https://") {
    return 6
  }
  let at = csv_find(text, "@")
  if at > 0 &&
    csv_find(text, " \t,;") < 0 &&
    text[at + 1:].to_owned().contains(".") {
    return 5
  }
  1
}

///|
fn csv_year(value : String) -> Bool {
  if value.length() != 4 || !csv_digits(value) {
    return false
  }
  let year = csv_int(value)
  year >= 1900 && year <= 2100
}

///|
/// Guess whether the first record is a header, using up to 1,000 records.
pub fn has_header(rows : Array[Array[String]]) -> Bool {
  if rows.length() < 2 || rows[0].length() == 0 {
    return false
  }
  let first = rows[0]
  let mut score = 0.0
  let mut all_text = true
  let seen : Map[String, Bool] = Map([])
  for index, value in first {
    let text = csv_trim(value)
    let kind = csv_kind(text)
    if kind == 0 {
      if index > 0 {
        score -= 1.0
        all_text = false
      }
      continue
    }
    if (kind == 2 || kind == 3) && !csv_year(text) {
      score -= 1.0
      all_text = false
    }
    if seen.get(text).unwrap_or(false) {
      score -= 2.0
      all_text = false
    }
    seen[text] = true
  }
  if all_text {
    score += 0.5
  }
  let end = if rows.length() < 1000 { rows.length() } else { 1000 }
  for column, header in first {
    let text = csv_trim(header)
    let mut header_kind = csv_kind(text)
    if header_kind == 0 {
      continue
    }
    let counts = [0, 0, 0, 0, 0, 0, 0]
    let values : Map[String, Bool] = Map([])
    let lengths : Map[Int32, Bool] = Map([])
    let mut n = 0
    let mut years = 0
    for index in 1..<end {
      let row = rows[index]
      if column >= row.length() {
        continue
      }
      let value = csv_trim(row[column])
      let kind = csv_kind(value)
      if kind == 0 {
        continue
      }
      counts[kind] += 1
      n += 1
      values[value] = true
      lengths[value.char_length()] = true
      if csv_year(value) {
        years += 1
      }
    }
    if n == 0 {
      continue
    }
    let mut dominant = 1
    let mut most = 0
    for kind in 1..<=6 {
      if counts[kind] > most {
        dominant = kind
        most = counts[kind]
      }
    }
    if csv_year(text) && years < n {
      header_kind = 1
    }
    if most.to_double() < 0.8 * n.to_double() {
      if values.get(text).unwrap_or(false) {
        score -= 1.0
      }
    } else if header_kind != dominant && dominant != 1 {
      score += 2.0
    } else if header_kind == dominant && dominant != 1 {
      score -= 2.0
    } else if header_kind != dominant {
      score -= 1.0
    } else if values.get(text).unwrap_or(false) {
      score -= 1.0
    } else if lengths.length() == 1 &&
      n >= 3 &&
      !lengths.get(text.char_length()).unwrap_or(false) {
      score += 1.0
    }
  }
  score > 0.0
}
