///|
/// Decode MML as UTF-8, BOM-marked UTF-16, or Shift_JIS, then normalize
/// CRLF and CR line endings as the upstream parser does.
pub fn decode_mml(data : Bytes) -> String {
  let text = if data.has_prefix(b"\xef\xbb\xbf") {
    @csv.decode_charset(data[3:].to_owned(), "UTF-8") catch {
      _ => @utf8.decode_lossy(data[3:])
    }
  } else if data.has_prefix(b"\xff\xfe") {
    mml_utf16(data[2:].to_owned(), true)
  } else if data.has_prefix(b"\xfe\xff") {
    mml_utf16(data[2:].to_owned(), false)
  } else {
    @utf8.decode(data[:]) catch {
      _ =>
        @csv.decode_charset(data, "Shift_JIS") catch {
          _ => @utf8.decode_lossy(data[:])
        }
    }
  }
  let out = StringBuilder()
  let mut previous_cr = false
  for c in text {
    if c == '\r' {
      out.write_char('\n')
      previous_cr = true
    } else {
      if c != '\n' || !previous_cr {
        out.write_char(c)
      }
      previous_cr = false
    }
  }
  out.to_string()
}

///|
fn mml_utf16(data : Bytes, little : Bool) -> String {
  let out = StringBuilder()
  let mut i = 0
  while i < data.length() {
    if i + 1 >= data.length() {
      out.write_char('\u{fffd}')
      break
    }
    let a = data[i].to_int()
    let b = data[i + 1].to_int()
    let unit = if little { a | (b << 8) } else { (a << 8) | b }
    i += 2
    if unit >= 0xd800 && unit <= 0xdfff {
      let mut rune = 0xfffd
      if i + 1 < data.length() {
        let x = data[i].to_int()
        let y = data[i + 1].to_int()
        let low = if little { x | (y << 8) } else { (x << 8) | y }
        if low >= 0xdc00 && low <= 0xdfff {
          if unit <= 0xdbff {
            rune = 0x10000 + (unit - 0xd800) * 1024 + low - 0xdc00
          }
          i += 2
        }
      }
      out.write_char(rune.unsafe_to_char())
    } else {
      out.write_char(unit.unsafe_to_char())
    }
  }
  out.to_string()
}
