///|
fn csv_detect_charset(data : Bytes) -> String raise {
  let size = if data.length() < 65536 { data.length() } else { 65536 }
  let sample = data[:size].to_owned()
  let pairs = sample.length() / 2
  let mut even = 0
  let mut odd = 0
  for i in 0..<pairs {
    if sample[i * 2] == 0 {
      even += 1
    }
    if sample[i * 2 + 1] == 0 {
      odd += 1
    }
  }
  let threshold = if pairs / 50 > 2 { pairs / 50 } else { 2 }
  if even >= threshold && odd * 10 <= even {
    return "UTF-16BE"
  }
  if odd >= threshold && even * 10 <= odd {
    return "UTF-16LE"
  }
  if csv_iso2022(sample) {
    return "ISO-2022-JP"
  }
  if csv_mostly_utf8(data) {
    return "UTF-8"
  }
  let mut end = sample.length()
  if data.length() > sample.length() {
    let mut i = sample.length() - 1
    while i > 0 {
      if sample[i] == b'\n' || sample[i] == b'\r' {
        end = i
        break
      }
      i -= 1
    }
  }
  let sample = sample[:end].to_owned()
  let mut best = ""
  let mut best_score = -1000000000.0
  for name in ["Shift_JIS", "EUC-JP", "WINDOWS-1252"] {
    let text = csv_decode_charset(sample, name)
    let score = csv_text_score(text, name)
    if score > best_score {
      best = name
      best_score = score
    }
  }
  best
}

///|
fn csv_iso2022(data : Bytes) -> Bool {
  for b in data {
    if b >= 0x80 {
      return false
    }
  }
  let mut i = 0
  while i + 2 < data.length() {
    if data[i] == 0x1b {
      if data[i + 1] == b'$' && (data[i + 2] == b'B' || data[i + 2] == b'@') {
        return true
      }
      if data[i + 1] == b'(' && data[i + 2] == b'I' {
        return true
      }
      if data[i + 1] == b'$' &&
        data[i + 2] == b'(' &&
        i + 3 < data.length() &&
        data[i + 3] == b'D' {
        return true
      }
    }
    i += 1
  }
  false
}

///|
// Unicode Han script ranges used by upstream's charset scoring.
fn csv_han(c : Int32) -> Bool {
  (c >= 0x2e80 && c <= 0x2e99) ||
  (c >= 0x2e9b && c <= 0x2ef3) ||
  (c >= 0x2f00 && c <= 0x2fd5) ||
  c == 0x3005 ||
  c == 0x3007 ||
  (c >= 0x3021 && c <= 0x3029) ||
  (c >= 0x3038 && c <= 0x303b) ||
  (c >= 0x3400 && c <= 0x4dbf) ||
  (c >= 0x4e00 && c <= 0x9fff) ||
  (c >= 0xf900 && c <= 0xfa6d) ||
  (c >= 0xfa70 && c <= 0xfad9) ||
  (c >= 0x16fe2 && c <= 0x16fe3) ||
  (c >= 0x16ff0 && c <= 0x16ff6) ||
  (c >= 0x20000 && c <= 0x2a6df) ||
  (c >= 0x2a700 && c <= 0x2b81d) ||
  (c >= 0x2b820 && c <= 0x2cead) ||
  (c >= 0x2ceb0 && c <= 0x2ebe0) ||
  (c >= 0x2ebf0 && c <= 0x2ee5d) ||
  (c >= 0x2f800 && c <= 0x2fa1d) ||
  (c >= 0x30000 && c <= 0x3134a) ||
  (c >= 0x31350 && c <= 0x33479)
}

///|
fn csv_text_score(text : String, name : String) -> Double {
  let mut total = 0.0
  let mut n = 0
  let mut previous_high = false
  for c in text {
    let code = c.to_int()
    if code < 0x80 {
      if code < 0x20 && c != '\t' && c != '\n' && c != '\r' {
        total -= 1.0
        n += 1
      }
      previous_high = false
      continue
    }
    n += 1
    let run = previous_high
    previous_high = true
    if code == 0xfffd {
      total -= 5.0
    } else if (code >= 0x80 && code <= 0x9f) ||
      (code >= 0xe000 && code <= 0xf8ff) {
      total -= 1.0
    } else if name == "WINDOWS-1252" {
      if run {
        total -= 0.5
      } else if @ucd.general_category(c).group() == @ucd.L ||
        (code >= 0x2010 && code <= 0x2044) ||
        code == 0x20ac {
        total += 0.8
      } else {
        total += 0.3
      }
    } else if code >= 0x3041 && code <= 0x309f {
      total += 1.0
    } else if (code >= 0x30a0 && code <= 0x30ff) ||
      (code >= 0x3000 && code <= 0x303f) {
      total += 0.8
    } else if code >= 0xff01 && code <= 0xff5e {
      total += 0.6
    } else if code >= 0xff61 && code <= 0xff9f {
      total += 0.2
    } else if csv_han(code) {
      let one = StringBuilder()
      one.write_char(c)
      match @encoding.encode(one.to_string(), "shift_jis") {
        Ok(bytes) if bytes.length() == 2 && bytes[0] >= 0x88 && bytes[0] <= 0x98 =>
          total += 0.7
        _ => total += 0.1
      }
    }
  }
  if n == 0 {
    0.0
  } else {
    total / n.to_double()
  }
}
