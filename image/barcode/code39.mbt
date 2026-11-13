// Code 39 patterns and framing adapted from shibukawa/bdf at
// a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22 (MIT).
// See licenses/Shibukawa-bdf.txt for the upstream copyright and license.

///|
/// The maximum UTF-8 byte length accepted by the barcode encoder.
pub const MAX_TEXT : Int32 = 8192

///|
/// A barcode input or geometry error.
pub suberror BarcodeError {
  BarcodeError(String)
}

///|
/// A Code 39 symbol represented as a row of modules, including quiet zones.
/// Other symbologies are not yet implemented.
pub struct Symbol {
  text : String
  modules : Bytes
}

///|
/// The barcode formats currently supported by this module.
pub fn kinds() -> Array[String] {
  ["code39"]
}

///|
/// Normalize an implemented symbology name. Unknown and unimplemented names
/// return the empty string; they are not advertised as supported.
pub fn kind(name : String) -> String {
  let expected : Array[Char] = ['c', 'o', 'd', 'e', '3', '9']
  let mut index = 0
  for ch in name {
    if ch == '-' || ch == '_' || ch == ' ' {
      continue
    }
    let code = ch.to_int()
    let lowered = if code >= 65 && code <= 90 {
      (code + 32).unsafe_to_char()
    } else {
      ch
    }
    if index >= expected.length() || lowered != expected[index] {
      return ""
    }
    index += 1
  }
  if index == expected.length() {
    "code39"
  } else {
    ""
  }
}

///|
/// The encoded payload, excluding optional start and stop asterisks.
pub fn Symbol::text(self : Symbol) -> String {
  self.text
}

///|
/// Width in modules, including quiet zones.
pub fn Symbol::width(self : Symbol) -> Int32 {
  self.modules.length()
}

///|
/// Code 39 is a linear symbol, one module tall.
pub fn Symbol::height(_self : Symbol) -> Int32 {
  1
}

///|
/// Whether a module is dark. Coordinates outside the symbol are light.
pub fn Symbol::at(self : Symbol, x : Int32, y : Int32) -> Bool {
  if y != 0 || x < 0 || x >= self.modules.length() {
    false
  } else {
    self.modules[x] != b'\x00'
  }
}

///|
fn code39_pattern(c : Char) -> String? {
  if c >= '0' && c <= '9' {
    return Some(
      [
        "000110100", "100100001", "001100001", "101100000", "000110001", "100110000",
        "001110000", "000100101", "100100100", "001100100",
      ][c.to_int() - '0'.to_int()],
    )
  }
  if c >= 'A' && c <= 'Z' {
    return Some(
      [
        "100001001", "001001001", "101001000", "000011001", "100011000", "001011000",
        "000001101", "100001100", "001001100", "000011100", "100000011", "001000011",
        "101000010", "000010011", "100010010", "001010010", "000000111", "100000110",
        "001000110", "000010110", "110000001", "011000001", "111000000", "010010001",
        "110010000", "011010000",
      ][c.to_int() - 'A'.to_int()],
    )
  }
  match c {
    '-' => Some("010000101")
    '.' => Some("110000100")
    ' ' => Some("011000100")
    '*' => Some("010010100")
    '$' => Some("010101000")
    '/' => Some("010100010")
    '+' => Some("010001010")
    '%' => Some("000101010")
    _ => None
  }
}

///|
/// Encode a Code 39 payload. `quiet=0` uses the standard 10-module margin;
/// a negative value suppresses it, and a positive value is capped at 64.
/// An optional leading and trailing `*` are treated as start/stop markers.
/// Lowercase, internal `*`, non-ASCII and unsupported formats are rejected.
/// The optional Mod-43 check character is neither added nor validated;
/// any supplied data character is encoded unchanged.
pub fn encode(
  name : String,
  text : String,
  quiet~ : Int32 = 0,
) -> Symbol raise BarcodeError {
  if kind(name) != "code39" {
    raise BarcodeError("barcode: unsupported symbology")
  }
  // A UTF-16 code unit occupies at least one UTF-8 byte, so the first check
  // rejects oversized inputs without allocating a UTF-8 copy. At most 8192
  // units remain to scan before any payload or module arrays are made.
  if text.length() > MAX_TEXT {
    raise BarcodeError("barcode: text exceeds 8192 bytes")
  }
  let mut bytes = 0
  for ch in text {
    let code = ch.to_int()
    bytes += if code < 0x80 {
      1
    } else if code < 0x800 {
      2
    } else if code < 0x10000 {
      3
    } else {
      4
    }
    if bytes > MAX_TEXT {
      raise BarcodeError("barcode: text exceeds 8192 bytes")
    }
  }
  let chars = text.to_array()
  let start = if chars.length() > 0 && chars[0] == '*' { 1 } else { 0 }
  let end = if chars.length() > start && chars[chars.length() - 1] == '*' {
    chars.length() - 1
  } else {
    chars.length()
  }
  if start >= end {
    raise BarcodeError("barcode: empty Code 39 payload")
  }
  let payload = String::from_array(chars[start:end])
  let symbols : Array[Char] = ['*']
  for ch in payload {
    if ch == '*' || code39_pattern(ch) is None {
      raise BarcodeError("barcode: character cannot be encoded as Code 39")
    }
    symbols.push(ch)
  }
  symbols.push('*')
  let margin = if quiet < 0 {
    0
  } else if quiet == 0 {
    10
  } else {
    Int32::min(quiet, 64)
  }
  // Each 9-element pattern has six narrow and three wide elements: 15
  // modules, plus one white separator between adjacent characters.
  let width = symbols.length() * 15 + symbols.length() - 1 + margin * 2
  let modules : Array[Byte] = Array::make(width, b'\x00')
  let mut cursor = margin
  for index, ch in symbols {
    if index > 0 {
      cursor += 1
    }
    let pattern = code39_pattern(ch).unwrap()
    let mut dark = true
    for element in pattern {
      let size = if element == '1' { 3 } else { 1 }
      if dark {
        for i in 0..<size {
          modules[cursor + i] = b'\x01'
        }
      }
      cursor += size
      dark = !dark
    }
  }
  { text: payload, modules: Bytes::from_array(modules), }
}
