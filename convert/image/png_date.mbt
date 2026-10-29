///|
fn png_month(value : String) -> Int32 {
  match value.to_lower() {
    "jan" => 1
    "feb" => 2
    "mar" => 3
    "apr" => 4
    "may" => 5
    "jun" => 6
    "jul" => 7
    "aug" => 8
    "sep" => 9
    "oct" => 10
    "nov" => 11
    "dec" => 12
    _ => 0
  }
}

///|
fn png_integer(value : String) -> Int32? {
  let data = @utf8.encode(value)
  if data.length() < 1 || data.length() > 4 {
    None
  } else {
    xmp_digits(data, 0, data.length())
  }
}

///|
fn png_two(value : Int32) -> String {
  if value < 10 {
    "0\{value}"
  } else {
    value.to_string()
  }
}

///|
// PNG Creation Time is commonly RFC 1123; the ISO and EXIF forms are
// accepted directly. Additional RFC-style layouts use the same components.
fn png_creation_date(value : String) -> String raise {
  let cleaned = xmp_clean(value)
  let iso = xmp_date(cleaned)
  if iso != "" {
    return iso
  }
  let parts : Array[String] = []
  for item in xmp_collapse(cleaned).split(" ") {
    if item.length() > 0 {
      parts.push(item.to_string())
    }
  }
  if parts.length() == 0 {
    return ""
  }
  let mut weekday_style = 0 // none, short comma, long comma, or short without comma
  if parts[0].has_suffix(",") {
    let weekday = parts[0].to_lower()
    match weekday {
      "mon," | "tue," | "wed," | "thu," | "fri," | "sat," | "sun," =>
        weekday_style = 1
      "monday,"
      | "tuesday,"
      | "wednesday,"
      | "thursday,"
      | "friday,"
      | "saturday,"
      | "sunday," => weekday_style = 2
      _ => return ""
    }
    ignore(parts.remove(0))
  }
  if weekday_style == 0 && parts.length() == 5 && png_month(parts[1]) > 0 {
    match parts[0].to_lower() {
      "mon" | "tue" | "wed" | "thu" | "fri" | "sat" | "sun" => {
        weekday_style = 3
        ignore(parts.remove(0))
      }
      _ => ()
    }
  }
  if parts.length() == 0 {
    return ""
  }
  let mut day = 0
  let mut month = 0
  let mut year = -1
  let mut clock = ""
  let mut zone = ""
  if weekday_style == 3 && png_month(parts[0]) > 0 && parts.length() == 4 {
    if parts[1].length() < 1 ||
      parts[1].length() > 2 ||
      parts[2].length() != 8 ||
      parts[3].length() != 4 {
      return ""
    }
    month = png_month(parts[0])
    day = png_integer(parts[1]).unwrap_or(0)
    clock = parts[2]
    year = png_integer(parts[3]).unwrap_or(-1)
  } else if weekday_style == 2 && parts[0].contains("-") && parts.length() == 3 {
    let date : Array[String] = [
      for field in parts[0].split("-") => field.to_string()
    ]
    if date.length() != 3 ||
      date[0].length() != 2 ||
      date[2].length() != 2 ||
      parts[1].length() != 8 {
      return ""
    }
    day = png_integer(date[0]).unwrap_or(0)
    month = png_month(date[1])
    year = png_integer(date[2]).unwrap_or(-1)
    if year < 0 {
      return ""
    }
    year += if year >= 69 { 1900 } else { 2000 }
    clock = parts[1]
    zone = parts[2]
    if zone.has_prefix("+") || zone.has_prefix("-") {
      return ""
    }
  } else if parts.length() == 5 && (weekday_style == 0 || weekday_style == 1) {
    let day_width = parts[0].length()
    let year_width = parts[2].length()
    let time_width = parts[3].length()
    let numeric_zone = parts[4].has_prefix("+") || parts[4].has_prefix("-")
    if weekday_style == 1 {
      if day_width < 1 || day_width > 2 || year_width != 4 || time_width != 8 {
        return ""
      }
    } else if year_width == 2 {
      if day_width != 2 || time_width != 5 {
        return ""
      }
    } else if year_width == 4 {
      if day_width < 1 || day_width > 2 || time_width != 8 || !numeric_zone {
        return ""
      }
    } else {
      return ""
    }
    day = png_integer(parts[0]).unwrap_or(0)
    month = png_month(parts[1])
    year = png_integer(parts[2]).unwrap_or(-1)
    if year < 0 {
      return ""
    }
    if year_width == 2 {
      year += if year >= 69 { 1900 } else { 2000 }
    }
    clock = parts[3]
    zone = parts[4]
  } else {
    return ""
  }
  if year < 0 || year > 9999 || month < 1 || day < 1 {
    return ""
  }
  let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
  let max_day = match month {
    2 => if leap { 29 } else { 28 }
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
  if day > max_day {
    return ""
  }
  let time : Array[String] = [
    for field in clock.split(":") => field.to_string()
  ]
  if time.length() < 2 || time.length() > 3 {
    return ""
  }
  let hour = png_integer(time[0]).unwrap_or(-1)
  let minute = png_integer(time[1]).unwrap_or(-1)
  let second = if time.length() == 3 {
    png_integer(time[2]).unwrap_or(-1)
  } else {
    0
  }
  if time[0].length() != 2 ||
    time[1].length() != 2 ||
    (time.length() == 3 && time[2].length() != 2) ||
    hour < 0 ||
    hour > 23 ||
    minute < 0 ||
    minute > 59 ||
    second < 0 ||
    second > 59 {
    return ""
  }
  let mut offset = "Z"
  let z = @utf8.encode(zone)
  if z.length() == 5 && (z[0] == b'+' || z[0] == b'-') {
    guard xmp_digits(z, 1, 2) is Some(h) && h <= 24 else { return "" }
    guard xmp_digits(z, 3, 2) is Some(m) && m <= 60 else { return "" }
    if h != 0 || m != 0 {
      let minutes = h * 60 + m
      offset = "\{zone[:1]}\{png_two(minutes / 60)}:\{png_two(minutes % 60)}"
    }
  } else if zone != "" && zone != "UTC" && zone != "GMT" {
    let mut uppercase = true
    for byte in z {
      if byte < b'A' || byte > b'Z' {
        uppercase = false
      }
    }
    let named = uppercase &&
      (
        z.length() == 3 ||
        (z.length() == 4 && (zone.has_suffix("T") || zone == "WITA")) ||
        (z.length() == 5 && zone.has_suffix("T"))
      )
    let special = zone == "ChST" ||
      zone == "MeST" ||
      zone.has_prefix("GMT+") ||
      zone.has_prefix("GMT-") ||
      zone.has_prefix("+") ||
      zone.has_prefix("-")
    if !named && !special {
      return ""
    }
    // Go resolves abbreviations against the host timezone. Do not silently
    // substitute UTC until equivalent host timezone handling is available.
    raise ImageFailure("image: PNG Creation Time timezone is not yet supported")
  }
  let padded_year = if year < 10 {
    "000\{year}"
  } else if year < 100 {
    "00\{year}"
  } else if year < 1000 {
    "0\{year}"
  } else {
    year.to_string()
  }
  let result = "\{padded_year}-\{png_two(month)}-\{png_two(day)}T\{png_two(hour)}:\{png_two(minute)}:\{png_two(second)}\{offset}"
  result
}
