// Adapted from golang.org/x/text/encoding/{simplifiedchinese,traditionalchinese}
// (Copyright 2013 The Go Authors, BSD-3-Clause); see licenses/Go-x-text.txt.

///|
// Match the Go decoders' consumption of invalid GBK and Big5 byte pairs.
fn csv_decode_chinese(data : Bytes, name : String) -> String {
  let output = StringBuilder()
  let mut at = 0
  while at < data.length() {
    let first = data[at].to_int()
    if first < 0x80 {
      output.write_char(first.unsafe_to_char())
      at += 1
      continue
    }
    if name != "BIG5" && first == 0x80 {
      output.write_char('€')
      at += 1
      continue
    }
    if first >= 0x81 && first < 0xff {
      if at + 1 >= data.length() {
        output.write_char('\u{fffd}')
        at += 1
        continue
      }
      let second = data[at + 1].to_int()
      if name == "GB18030" && second >= 0x30 && second < 0x40 {
        if at + 3 >= data.length() {
          output.write_char('\u{fffd}')
          at += 1
          continue
        }
        let third = data[at + 2].to_int()
        let fourth = data[at + 3].to_int()
        if third < 0x81 || third >= 0xff || fourth < 0x30 || fourth >= 0x3a {
          output.write_char('\u{fffd}')
          at += 1
          continue
        }
        let pointer = (
            ((first - 0x81) * 10 + second - 0x30) * 126 + third - 0x81
          ) *
          10 +
          fourth -
          0x30
        if pointer == 7457 {
          output.write_char('\u{1e3f}')
          at += 4
          continue
        }
        if pointer >= 39420 {
          let code = pointer - 189000
          if code < 0 || code >= 0x100000 {
            output.write_char('\u{fffd}')
            at += 1
            continue
          }
          output.write_char((code + 0x10000).unsafe_to_char())
          at += 4
          continue
        }
        let normalized = Bytes::from_array([
          (pointer / 12600 + 0x81).to_byte(),
          (pointer / 1260 % 10 + 0x30).to_byte(),
          (pointer / 10 % 126 + 0x81).to_byte(),
          (pointer % 10 + 0x30).to_byte(),
        ])
        match @encoding.decode(normalized, "gb18030") {
          Ok(text) => output.write_string(text)
          Err(_) => output.write_char('\u{fffd}')
        }
        at += 4
        continue
      }
      let valid = if name != "BIG5" {
        (second >= 0x40 && second < 0x7f) || (second >= 0x80 && second < 0xff)
      } else {
        (second >= 0x40 && second < 0x7f) || (second >= 0xa1 && second < 0xff)
      }
      if valid {
        if name != "BIG5" && csv_gbk_missing(first, second) {
          output.write_char('\u{fffd}')
          at += 2
          continue
        }
        let label = if name != "BIG5" { "gbk" } else { "big5" }
        match @encoding.decode(data[at:at + 2].to_owned(), label) {
          Ok(text) if !(text.has_prefix("�") && text.char_length() > 1) =>
            if name != "BIG5" && text.char_length() == 1 {
              let mut private_use = false
              for c in text {
                private_use = c.to_int() >= 0xe000 && c.to_int() <= 0xf8ff
              }
              if private_use {
                output.write_char('\u{fffd}')
              } else {
                output.write_string(text)
              }
            } else {
              output.write_string(text)
            }
          _ => output.write_char('\u{fffd}')
        }
        at += 2
        continue
      }
      output.write_char('\u{fffd}')
      at += if name == "BIG5" && second >= 0x40 { 2 } else { 1 }
      continue
    }
    output.write_char('\u{fffd}')
    at += 1
  }
  output.to_string()
}

///|
// WHATWG's newer GB18030 mappings filled positions that the upstream Go GBK
// table still leaves undefined.
fn csv_gbk_missing(first : Int32, second : Int32) -> Bool {
  if first == 0xa6 {
    return (second >= 0xd9 && second <= 0xdf) ||
      second == 0xec ||
      second == 0xed ||
      second == 0xf3
  }
  if first == 0xa8 {
    return second == 0xbc
  }
  if first == 0xfe {
    return second == 0x59 ||
      second == 0x61 ||
      second == 0x66 ||
      second == 0x67 ||
      second == 0x6d ||
      second == 0x7e ||
      second == 0x90 ||
      second == 0xa0
  }
  false
}
