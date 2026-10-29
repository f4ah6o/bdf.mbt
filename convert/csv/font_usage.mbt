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
