///|
fn info_signed16(data : BytesView, offset : Int32) -> Int32 {
  let n = be16(data, offset)
  if n >= 32768 {
    n - 65536
  } else {
    n
  }
}

///|
fn info_fixed(data : BytesView, offset : Int32) -> Double {
  be32(data, offset).reinterpret_as_int().to_double() / 65536.0
}

///|
fn info_decimal(value : Double) -> String {
  let negative = value < 0.0
  let absolute = if negative { -value } else { value }
  let rounded = (absolute * 1000.0 + 0.5).to_int()
  let out = StringBuilder()
  if negative {
    out.write_char('-')
  }
  out.write_string((rounded / 1000).to_string())
  let fraction = rounded % 1000
  if fraction != 0 {
    out.write_char('.')
    out.write_char((48 + fraction / 100).unsafe_to_char())
    if fraction % 100 != 0 {
      out.write_char((48 + fraction / 10 % 10).unsafe_to_char())
    }
    if fraction % 10 != 0 {
      out.write_char((48 + fraction % 10).unsafe_to_char())
    }
  }
  out.to_string()
}

///|
fn info_bytesize(n : Int32) -> String {
  if n >= 1048576 {
    let rounded = (n.to_double() / 1048576.0 * 10.0 + 0.5).to_int()
    info_decimal(rounded.to_double() / 10.0) + " MB"
  } else if n >= 1024 {
    let rounded = (n.to_double() / 1024.0 * 10.0 + 0.5).to_int()
    info_decimal(rounded.to_double() / 10.0) + " KB"
  } else {
    info_number(n.to_int64()) + " bytes"
  }
}

///|
fn info_two(value : Int32) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn info_head_time(data : BytesView, offset : Int32) -> (String, String) {
  let hi = be32(data, offset).to_int64()
  let lo = be32(data, offset + 4).to_int64()
  let seconds = (hi << 32) | lo
  if hi > 1L || seconds <= 0L || seconds > 6307200000L {
    return ("", "")
  }
  let mut days = (seconds / 86400L).to_int()
  let remaining = (seconds % 86400L).to_int()
  let mut year = 1904
  while true {
    let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
    let length = if leap { 366 } else { 365 }
    if days < length {
      break
    }
    days -= length
    year += 1
  }
  let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
  let months = [
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
  let mut month = 0
  while days >= months[month] {
    days -= months[month]
    month += 1
  }
  let date = year.to_string() +
    "-" +
    info_two(month + 1) +
    "-" +
    info_two(days + 1)
  let clock = info_two(remaining / 3600) +
    ":" +
    info_two(remaining % 3600 / 60) +
    ":" +
    info_two(remaining % 60)
  (date + " " + clock + " UTC", date + "T" + clock + "Z")
}
