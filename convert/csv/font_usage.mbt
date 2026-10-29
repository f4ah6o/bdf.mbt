///|
fn csv_hex(code : Int32) -> String {
  let digits : Array[Char] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
  ]
  let mut value = code
  let reverse : Array[Char] = []
  while value > 0 {
    reverse.push(digits[value % 16])
    value /= 16
  }
  while reverse.length() < 4 {
    reverse.push('0')
  }
  let result = StringBuilder()
  for i = reverse.length() - 1; i >= 0; i = i - 1 {
    result.write_char(reverse[i])
  }
  result.to_string()
}

///|
fn csv_missing_warning(codes : Array[Int32]) -> String? {
  if codes.length() == 0 {
    return None
  }
  let out = StringBuilder()
  out.write_string("no available font has glyphs for:")
  for i, code in codes {
    if i == 20 {
      out.write_string(" … (" + (codes.length() - 20).to_string() + " more)")
      break
    }
    out.write_char(' ')
    out.write_char(code.unsafe_to_char())
    out.write_string(" U+")
    out.write_string(csv_hex(code))
  }
  out.write_string("; viewers draw them with their own fonts")
  Some(out.to_string())
}

///|
// Go orders font paths lexicographically by UTF-8 bytes. Unicode scalar order
// has the same ordering for well-formed UTF-8; MoonBit's String.compare first
// compares lengths, so it cannot be used here.
fn csv_path_compare(a : String, b : String) -> Int32 {
  let left : Array[Char] = [ for c in a => c ]
  let right : Array[Char] = [ for c in b => c ]
  for i in 0..<Int32::min(left.length(), right.length()) {
    if left[i] != right[i] {
      return left[i].to_int().compare(right[i].to_int())
    }
  }
  left.length().compare(right.length())
}
