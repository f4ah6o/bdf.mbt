///|
fn xlsx_fixed_number(data : Bytes, at : Int32, length : Int32) -> Int32? {
  if at < 0 || at + length > data.length() {
    return None
  }
  let mut value = 0
  for i in at..<(at + length) {
    let d = data[i].to_int() - 48
    if d < 0 || d > 9 {
      return None
    }
    value = value * 10 + d
  }
  Some(value)
}

///|
fn xlsx_days(year : Int32, month : Int32, day : Int32) -> Int64 {
  let y = year - (if month <= 2 { 1 } else { 0 })
  let era = if y >= 0 { y / 400 } else { (y - 399) / 400 }
  let yoe = y - era * 400
  let adjusted = month + (if month > 2 { -3 } else { 9 })
  let doy = (153 * adjusted + 2) / 5 + day - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  (era * 146097 + doe - 719468).to_int64()
}

///|
/// Read an ISO 8601 date or time into the Excel serial date system.
pub fn xlsx_iso_serial(value : String, date1904 : Bool) -> Double? {
  let data = @utf8.encode(value)
  let date = data.length() >= 10 && data[4] == b'-' && data[7] == b'-'
  let mut days = 0L
  let mut at = 0
  if date {
    guard xlsx_fixed_number(data, 0, 4) is Some(year) &&
      xlsx_fixed_number(data, 5, 2) is Some(month) &&
      xlsx_fixed_number(data, 8, 2) is Some(day) else {
      return None
    }
    if month < 1 || month > 12 {
      return None
    }
    let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
    let lengths = [
      31,
      if leap {
        29
      } else {
        28
      },
      31,
      30,
      31,
      30,
      31,
      31,
      30,
      31,
      30,
      31,
    ]
    if day < 1 || day > lengths[month - 1] {
      return None
    }
    days = xlsx_days(year, month, day) -
      xlsx_days(
        if date1904 {
          1904
        } else {
          1899
        },
        if date1904 {
          1
        } else {
          12
        },
        if date1904 {
          1
        } else {
          30
        },
      )
    at = 10
    if at < data.length() {
      if data[at] != b'T' {
        return None
      }
      at += 1
      if at == data.length() {
        return None
      }
    }
  }
  let mut seconds = 0
  let mut nanos = 0L
  let mut zone = 0
  if at < data.length() {
    if at + 8 > data.length() || data[at + 2] != b':' || data[at + 5] != b':' {
      return None
    }
    guard xlsx_fixed_number(data, at, 2) is Some(hour) &&
      xlsx_fixed_number(data, at + 3, 2) is Some(minute) &&
      xlsx_fixed_number(data, at + 6, 2) is Some(second) else {
      return None
    }
    if hour > 23 || minute > 59 || second > 59 {
      return None
    }
    seconds = hour * 3600 + minute * 60 + second
    at += 8
    if at < data.length() && (data[at] == b'.' || data[at] == b',') {
      at += 1
      let start = at
      while at < data.length() && data[at] >= b'0' && data[at] <= b'9' {
        if at - start < 9 {
          nanos = nanos * 10L + (data[at].to_int() - 48).to_int64()
        }
        at += 1
      }
      if at == start {
        return None
      }
      for _ in 0..<Int32::max(9 - (at - start), 0) {
        nanos *= 10L
      }
    }
    if at < data.length() && date {
      if data[at] == b'Z' {
        at += 1
      } else if data[at] == b'+' || data[at] == b'-' {
        let neg = data[at] == b'-'
        if at + 6 != data.length() || data[at + 3] != b':' {
          return None
        }
        guard xlsx_fixed_number(data, at + 1, 2) is Some(h) &&
          xlsx_fixed_number(data, at + 4, 2) is Some(m) else {
          return None
        }
        if h > 24 || m > 60 {
          return None
        }
        zone = (h * 60 + m) * 60 * (if neg { -1 } else { 1 })
        at += 6
      }
    }
  } else if !date {
    return None
  }
  if at != data.length() {
    return None
  }
  if !date {
    return Some(seconds.to_double() / 86400.0)
  }
  let sec = days * 86400L + (seconds - zone).to_int64()
  let max_sec = 9223372036L
  let ns = if sec > max_sec || (sec == max_sec && nanos > 854775807L) {
    9223372036854775807L
  } else if sec < -9223372037L || (sec == -9223372037L && nanos < 145224192L) {
    -9223372036854775807L - 1L
  } else if sec == -9223372037L {
    (sec + 1L) * 1000000000L + nanos - 1000000000L
  } else {
    sec * 1000000000L + nanos
  }
  let hours = ns / 3600000000000L
  let remainder = ns % 3600000000000L
  let mut serial = (hours.to_double() + remainder.to_double() / 3600000000000.0) /
    24.0
  if !date1904 && serial < 61.0 {
    serial -= 1.0
  }
  Some(serial)
}
