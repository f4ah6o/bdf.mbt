///|
// Go's quoted formatting uses Go escapes and Unicode printability.
fn xlsx_go_quote(text : String, quote : Char) -> String {
  let output = StringBuilder()
  let hex = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
  ]
  output.write_char(quote)
  for c in text {
    if c == quote || c == '\\' {
      output.write_char('\\')
      output.write_char(c)
      continue
    }
    match c {
      '\u{07}' => output.write_string("\\a")
      '\b' => output.write_string("\\b")
      '\u{0c}' => output.write_string("\\f")
      '\n' => output.write_string("\\n")
      '\r' => output.write_string("\\r")
      '\t' => output.write_string("\\t")
      '\u{0b}' => output.write_string("\\v")
      _ => {
        let category = @ucd.general_category(c).group()
        if c == ' ' || (category != @ucd.C && category != @ucd.Z) {
          output.write_char(c)
        } else {
          let code = c.to_int()
          let digits = if code < 0x20 || code == 0x7f {
            output.write_string("\\x")
            2
          } else if code < 0x10000 {
            output.write_string("\\u")
            4
          } else {
            output.write_string("\\U")
            8
          }
          for i = digits - 1; i >= 0; i = i - 1 {
            output.write_char(hex[(code >> (i * 4)) & 15])
          }
        }
      }
    }
  }
  output.write_char(quote)
  output.to_string()
}
