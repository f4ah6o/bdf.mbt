///|
fn csv_fixed_number(data : Bytes, at : Int32, length : Int32) -> Int32? {
  if at < 0 || at + length > data.length() {
    return None
  }
  let mut value = 0
  for i in at..<(at + length) {
    let digit = data[i].to_int() - 48
    if digit < 0 || digit > 9 {
      return None
    }
    value = value * 10 + digit
  }
  Some(value)
}

///|
fn csv_date_days(year : Int32, month : Int32, day : Int32) -> Int64 {
  let y = year - (if month <= 2 { 1 } else { 0 })
  let era = if y >= 0 { y / 400 } else { (y - 399) / 400 }
  let yoe = y - era * 400
  let adjusted_month = month + (if month > 2 { -3 } else { 9 })
  let doy = (153 * adjusted_month + 2) / 5 + day - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  (era * 146097 + doe - 719468).to_int64()
}

///|
fn csv_table_date(value : String) -> Int64? {
  let data = @utf8.encode(value)
  if data.length() != 10 || data[4] != b'-' || data[7] != b'-' {
    return None
  }
  guard csv_fixed_number(data, 0, 4) is Some(year) &&
    csv_fixed_number(data, 5, 2) is Some(month) &&
    csv_fixed_number(data, 8, 2) is Some(day) else {
    return None
  }
  if !csv_valid_day(year.to_int64(), month.to_int64(), day.to_int64()) {
    return None
  }
  Some(csv_date_days(year, month, day))
}

///|
fn csv_table_datetime(value : String) -> Int64? {
  let data = @utf8.encode(value)
  if data.length() < 16 ||
    (data[10] != b'T' && data[10] != b' ') ||
    data[13] != b':' {
    return None
  }
  let date_text = @utf8.decode(data[:10]) catch { _ => return None }
  guard csv_table_date(date_text) is Some(days) else { return None }
  guard csv_fixed_number(data, 11, 2) is Some(hour) &&
    csv_fixed_number(data, 14, 2) is Some(minute) else {
    return None
  }
  if hour > 23 || minute > 59 {
    return None
  }
  let mut at = 16
  let mut second = 0
  let mut millis = 0
  let mut has_seconds = false
  if at < data.length() && data[at] == b':' {
    guard csv_fixed_number(data, at + 1, 2) is Some(n) else { return None }
    if n > 59 {
      return None
    }
    second = n
    has_seconds = true
    at += 3
    if at < data.length() && data[at] == b'.' {
      at += 1
      let start = at
      while at < data.length() && data[at] >= b'0' && data[at] <= b'9' {
        if at - start < 3 {
          millis = millis * 10 + data[at].to_int() - 48
        }
        at += 1
      }
      if at == start {
        return None
      }
      let precision = if at - start < 3 { at - start } else { 3 }
      for _ in 0..<(3 - precision) {
        millis *= 10
      }
    }
  }
  let mut offset = 0
  if at < data.length() {
    if !has_seconds {
      return None
    }
    if data[at] == b'Z' {
      at += 1
    } else if data[at] == b'+' || data[at] == b'-' {
      let negative = data[at] == b'-'
      let remaining = data.length() - at
      let with_colon = remaining == 6 && data[at + 3] == b':'
      if !with_colon && !(remaining == 5 && data[10] == b'T') {
        return None
      }
      let minute_at = at + (if with_colon { 4 } else { 3 })
      guard csv_fixed_number(data, at + 1, 2) is Some(zh) &&
        csv_fixed_number(data, minute_at, 2) is Some(zm) else {
        return None
      }
      if zh > 24 || zm > 60 {
        return None
      }
      offset = (zh * 60 + zm) * 60 * (if negative { -1 } else { 1 })
      at = data.length()
    } else {
      return None
    }
  }
  if at != data.length() {
    return None
  }
  Some(
    (days * 86400L + (hour * 3600 + minute * 60 + second - offset).to_int64()) *
    1000L +
    millis.to_int64(),
  )
}
