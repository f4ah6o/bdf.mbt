///|
fn xlsx_date_piece_text(pieces : Array[XlsxFormatPiece], text : String) -> Unit {
  let n = pieces.length()
  if n > 0 && pieces[n - 1].kind == 0 {
    pieces[n - 1] = { kind: 0, text: pieces[n - 1].text + text, }
  } else {
    pieces.push({ kind: 0, text, })
  }
}

///|
fn xlsx_civil_from_days(days : Int64) -> (Int32, Int32, Int32) {
  let z = days + 719468L
  let era = if z >= 0L { z / 146097L } else { (z - 146096L) / 146097L }
  let doe = z - era * 146097L
  let yoe = (doe - doe / 1460L + doe / 36524L - doe / 146096L) / 365L
  let mut year = yoe + era * 400L
  let doy = doe - (365L * yoe + yoe / 4L - yoe / 100L)
  let mp = (5L * doy + 2L) / 153L
  let day = doy - (153L * mp + 2L) / 5L + 1L
  let month = mp + (if mp < 10L { 3L } else { -9L })
  if month <= 2L {
    year += 1L
  }
  (year.to_int(), month.to_int(), day.to_int())
}

///|
fn xlsx_pad_number(value : Int32, width : Int32) -> String {
  let s = value.to_string()
  if width >= 2 && value < 10 {
    "0" + s
  } else {
    s
  }
}

///|
fn xlsx_round_signed(value : Double) -> Double {
  if value < 0.0 {
    -(-value).round()
  } else {
    value.round()
  }
}

///|
/// Render a date section, returning None for an invalid Excel serial date.
pub fn xlsx_format_date(
  section : XlsxFormatSection,
  input : Double,
  date1904 : Bool,
) -> Array[XlsxFormatPiece]? {
  let tokens = section.tokens
  let mut sub = 0
  let mut hour12 = false
  for token in tokens {
    if token.kind == 13 {
      sub = Int32::max(sub, token.text.length())
    }
    if token.kind == 10 && (token.text == "AM/PM" || token.text == "A/P") {
      hour12 = true
    }
  }
  let unit = 86400.0 * xlsx_pow10(sub)
  let value = xlsx_round_signed(input * unit) / unit
  if value < 0.0 || value > 2958465.99999999 || value.is_nan() {
    return None
  }
  let mut serial_days = value.floor().to_int64()
  let mut milliseconds = ((value - serial_days.to_double()) * 86400000.0)
    .round()
    .to_int()
  if milliseconds >= 86400000 {
    serial_days += 1L
    milliseconds -= 86400000
  }
  let leap = !date1904 && serial_days == 60L
  let base = if date1904 {
    xlsx_days(1904, 1, 1)
  } else if serial_days < 60L {
    xlsx_days(1899, 12, 31)
  } else {
    xlsx_days(1899, 12, 30)
  }
  let unix_days = if leap { xlsx_days(1900, 2, 28) } else { base + serial_days }
  let (cyear, cmonth, cday) = xlsx_civil_from_days(unix_days)
  let year = if leap { 1900 } else { cyear }
  let month = if leap { 2 } else { cmonth }
  let day = if leap { 29 } else { cday }
  let weekday = if !date1904 && value.floor() < 61.0 {
    (value.floor().to_int() + 6) % 7
  } else {
    (((unix_days + 4L) % 7L + 7L) % 7L).to_int()
  }
  let hour = milliseconds / 3600000
  let minute = milliseconds / 60000 % 60
  let second = milliseconds / 1000 % 60
  let millis = milliseconds % 1000
  let ja = section.locale == "411" ||
    section.locale.has_suffix("0411") ||
    section.locale.has_prefix("ja")
  let months = [
    "January", "February", "March", "April", "May", "June", "July", "August", "September",
    "October", "November", "December",
  ]
  let weekdays = [
    "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
  ]
  let ja_days = ["日", "月", "火", "水", "木", "金", "土"]
  let minute_flags = Array::make(tokens.length(), false)
  for i in 0..<tokens.length() {
    let token = tokens[i]
    if token.kind != 10 ||
      !token.text.has_prefix("m") ||
      token.text.length() > 2 {
      continue
    }
    let mut j = i - 1
    while j >= 0 {
      let t = tokens[j]
      if t.kind == 10 || t.kind == 11 {
        minute_flags[i] = t.text.has_prefix("h") || t.text.has_prefix("[h")
        break
      }
      j -= 1
    }
    if !minute_flags[i] {
      let mut j = i + 1
      while j < tokens.length() {
        let t = tokens[j]
        if t.kind == 10 || t.kind == 11 {
          minute_flags[i] = t.text.has_prefix("s") || t.text.has_prefix("[s")
          break
        }
        j += 1
      }
    }
  }
  let total_sec = value * 86400.0
  let out : Array[XlsxFormatPiece] = []
  for i in 0..<tokens.length() {
    let token = tokens[i]
    let s = token.text
    match token.kind {
      0 | 4 | 5 | 6 | 7 | 9 => xlsx_date_piece_text(out, s)
      1 | 2 => out.push({ kind: token.kind, text: s, })
      13 => {
        let digits = (if millis < 100 { "0" } else { "" }) +
          (if millis < 10 { "0" } else { "" }) +
          millis.to_string()
        xlsx_date_piece_text(
          out,
          "." + digits[:Int32::min(s.length(), 3)].to_owned(),
        )
      }
      11 => {
        let v = if s.has_prefix("h") {
          (total_sec / 3600.0 + 1.0e-9).floor()
        } else if s.has_prefix("m") {
          (total_sec / 60.0 + 1.0e-9).floor()
        } else {
          (total_sec + 1.0e-9).floor()
        }
        xlsx_date_piece_text(
          out,
          (if s.length() >= 2 && v < 10.0 { "0" } else { "" }) +
          v.to_int64().to_string(),
        )
      }
      10 => {
        let text = if s == "AM/PM" {
          if hour < 12 {
            "AM"
          } else {
            "PM"
          }
        } else if s == "A/P" {
          if hour < 12 {
            "A"
          } else {
            "P"
          }
        } else if s.has_prefix("y") {
          if s.length() <= 2 {
            xlsx_pad_number(year % 100, 2)
          } else {
            year.to_string()
          }
        } else if s.has_prefix("b") {
          if s.length() <= 2 {
            xlsx_pad_number((year + 543) % 100, 2)
          } else {
            (year + 543).to_string()
          }
        } else if s.has_prefix("m") && minute_flags[i] {
          xlsx_pad_number(minute, s.length())
        } else if s.has_prefix("m") {
          if s.length() <= 2 {
            xlsx_pad_number(month, s.length())
          } else if s.length() == 3 {
            if ja {
              month.to_string() + "月"
            } else {
              months[month - 1][:3].to_owned()
            }
          } else if s.length() == 4 {
            if ja {
              month.to_string() + "月"
            } else {
              months[month - 1]
            }
          } else {
            months[month - 1][:1].to_owned()
          }
        } else if s.has_prefix("d") {
          if s.length() <= 2 {
            xlsx_pad_number(day, s.length())
          } else if s.length() == 3 {
            if ja {
              ja_days[weekday]
            } else {
              weekdays[weekday][:3].to_owned()
            }
          } else if ja {
            ja_days[weekday] + "曜日"
          } else {
            weekdays[weekday]
          }
        } else if s.has_prefix("a") {
          if s.length() >= 4 {
            ja_days[weekday] + "曜日"
          } else {
            ja_days[weekday]
          }
        } else if s.has_prefix("h") {
          let h = if hour12 {
            if hour % 12 == 0 {
              12
            } else {
              hour % 12
            }
          } else {
            hour
          }
          xlsx_pad_number(h, s.length())
        } else if s.has_prefix("s") {
          xlsx_pad_number(second, s.length())
        } else if s.has_prefix("g") || s.has_prefix("e") {
          let eras = [
            (2019, 5, 1, "令和", "令", "R"),
            (1989, 1, 8, "平成", "平", "H"),
            (1926, 12, 25, "昭和", "昭", "S"),
            (1912, 7, 30, "大正", "大", "T"),
            (1868, 1, 1, "明治", "明", "M"),
          ]
          let mut era_year = cyear
          let mut name = ""
          let mut short = ""
          let mut initial = ""
          for (y, m, d, n, a, c) in eras {
            if (cyear, cmonth, cday) >= (y, m, d) {
              era_year = cyear - y + 1
              name = n
              short = a
              initial = c
              break
            }
          }
          if s.has_prefix("e") {
            xlsx_pad_number(era_year, if s.length() >= 2 { 2 } else { 1 })
          } else if s.length() == 1 {
            initial
          } else if s.length() == 2 {
            short
          } else {
            name
          }
        } else {
          s
        }
        xlsx_date_piece_text(out, text)
      }
      _ => ()
    }
  }
  Some(out)
}
