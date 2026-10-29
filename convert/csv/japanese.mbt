// Adapted from golang.org/x/text/encoding/japanese (Copyright 2013 The Go
// Authors, BSD-3-Clause); see licenses/Go-x-text.txt.

///|
// Go's decoders consume some malformed byte pairs differently from WHATWG.
// Handle their byte boundaries here and use the encoding library for the
// character table of complete, valid JIS sequences.
fn csv_decode_japanese(data : Bytes, name : String) -> String {
  let output = StringBuilder()
  let mut at = 0
  while at < data.length() {
    let first = data[at].to_int()
    if first < 0x80 {
      output.write_char(first.unsafe_to_char())
      at += 1
      continue
    }
    if name == "Shift_JIS" {
      if first >= 0xa1 && first < 0xe0 {
        output.write_char((first + 0xff61 - 0xa1).unsafe_to_char())
        at += 1
        continue
      }
      if first == 0x80 {
        output.write_char('\u{80}')
        at += 1
        continue
      }
      if (first >= 0x81 && first < 0xa0) || (first >= 0xe0 && first < 0xfd) {
        if at + 1 >= data.length() {
          output.write_char('\u{fffd}')
          at += 1
          continue
        }
        let second = data[at + 1].to_int()
        if second < 0x40 || second == 0x7f {
          output.write_char('\u{fffd}')
          at += 1
          continue
        }
        if second >= 0xfd || (first >= 0xf0 && first <= 0xf9) {
          output.write_char('\u{fffd}')
          at += 2
          continue
        }
        output.write_string(
          csv_jis_sequence(data[at:at + 2].to_owned(), "shift_jis"),
        )
        at += 2
        continue
      }
    } else {
      if first == 0x8e {
        if at + 1 >= data.length() {
          output.write_char('\u{fffd}')
          at += 1
          continue
        }
        let second = data[at + 1].to_int()
        if second < 0xa1 || second == 0xff {
          output.write_char('\u{fffd}')
          at += 1
          continue
        }
        if second > 0xdf {
          output.write_char('\u{fffd}')
          at += 2
          continue
        }
        output.write_char((second + 0xff61 - 0xa1).unsafe_to_char())
        at += 2
        continue
      }
      if first == 0x8f {
        if at + 2 >= data.length() {
          let count = if at + 1 < data.length() &&
            data[at + 1] >= 0xa1 &&
            data[at + 1] < 0xfe {
            2
          } else {
            1
          }
          output.write_char('\u{fffd}')
          at += count
          continue
        }
        let second = data[at + 1].to_int()
        let third = data[at + 2].to_int()
        if second < 0xa1 || second > 0xfe {
          output.write_char('\u{fffd}')
          at += 1
          continue
        }
        if third < 0xa1 || third > 0xfe {
          output.write_char('\u{fffd}')
          at += 2
          continue
        }
        output.write_string(
          csv_jis_sequence(data[at:at + 3].to_owned(), "euc-jp"),
        )
        at += 3
        continue
      }
      if first >= 0xa1 && first <= 0xfe {
        if at + 1 >= data.length() {
          output.write_char('\u{fffd}')
          at += 1
          continue
        }
        let second = data[at + 1].to_int()
        if second < 0xa1 || second > 0xfe {
          output.write_char('\u{fffd}')
          at += 1
          continue
        }
        output.write_string(
          csv_jis_sequence(data[at:at + 2].to_owned(), "euc-jp"),
        )
        at += 2
        continue
      }
    }
    output.write_char('\u{fffd}')
    at += 1
  }
  output.to_string()
}

///|
fn csv_jis_sequence(data : Bytes, label : String) -> String {
  match @encoding.decode(data, label) {
    Ok(text) if text.char_length() == 1 => text
    _ => "�"
  }
}
