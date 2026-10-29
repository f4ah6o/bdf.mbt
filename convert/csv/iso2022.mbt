// Adapted from golang.org/x/text/encoding/japanese (Copyright 2013 The Go
// Authors, BSD-3-Clause); see licenses/Go-x-text.txt.

///|
// Go's ISO-2022-JP reader supports JIS X 0212 and half-width katakana and
// differs from the narrower WHATWG decoder on malformed escape sequences.
fn csv_decode_iso2022(data : Bytes) -> String {
  let output = StringBuilder()
  let mut at = 0
  let mut state = 0 // ASCII, katakana, JIS 0208, JIS 0212
  while at < data.length() {
    let first = data[at].to_int()
    if first >= 0x80 {
      output.write_char('\u{fffd}')
      at += 1
      continue
    }
    if first == 0x1b {
      if at + 2 >= data.length() {
        output.write_char('\u{fffd}')
        at += 1
        continue
      }
      let second = data[at + 1].to_int()
      let third = data[at + 2].to_int()
      if second == 0x24 && (third == 0x40 || third == 0x42) {
        state = 2
        at += 3
        continue
      }
      if second == 0x24 &&
        third == 0x28 &&
        at + 3 < data.length() &&
        data[at + 3] == b'D' {
        state = 3
        at += 4
        continue
      }
      if second == 0x28 && (third == 0x42 || third == 0x4a) {
        state = 0
        at += 3
        continue
      }
      if second == 0x28 && third == 0x49 {
        state = 1
        at += 3
        continue
      }
      output.write_char('\u{fffd}')
      at += 1
      continue
    }
    if state == 0 {
      output.write_char(first.unsafe_to_char())
      at += 1
      continue
    }
    if state == 1 {
      if first < 0x21 || first >= 0x60 {
        output.write_char('\u{fffd}')
      } else {
        output.write_char((first + 0xff61 - 0x21).unsafe_to_char())
      }
      at += 1
      continue
    }
    if first == 0x0a {
      state = 0
      output.write_char('\n')
      at += 1
      continue
    }
    if at + 1 >= data.length() {
      output.write_char('\u{fffd}')
      at += 1
      continue
    }
    let second = data[at + 1].to_int()
    let pointer = ((first - 0x21) & 255) * 94 + ((second - 0x21) & 255)
    if state == 2 && pointer <= 11103 {
      let lead_offset = pointer / 188
      let trail_offset = pointer % 188
      let lead = lead_offset + (if lead_offset < 0x1f { 0x81 } else { 0xc1 })
      let trail = trail_offset + (if trail_offset < 0x3f { 0x40 } else { 0x41 })
      output.write_string(
        csv_decode_japanese(
          Bytes::from_array([lead.to_byte(), trail.to_byte()]),
          "Shift_JIS",
        ),
      )
    } else if state == 3 && pointer <= 7210 {
      let lead = pointer / 94 + 0xa1
      let trail = pointer % 94 + 0xa1
      output.write_string(
        csv_decode_japanese(
          Bytes::from_array([0x8f, lead.to_byte(), trail.to_byte()]),
          "EUC-JP",
        ),
      )
    } else {
      output.write_char('\u{fffd}')
    }
    at += 2
  }
  output.to_string()
}
