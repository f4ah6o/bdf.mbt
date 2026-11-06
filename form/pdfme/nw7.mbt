///|
fn nw7_pattern(c : Char) -> String? {
  let patterns : Map[Char, String] = {
    '0': "nnnnnww", '1': "nnnnwwn", '2': "nnnwnnw", '3': "wwnnnnn",
    '4': "nnwnnwn", '5': "wnnnnwn", '6': "nwnnnnw", '7': "nwnnwnn",
    '8': "nwwnnnn", '9': "wnnwnnn", '-': "nnnnwnw", '$': "nwnwnnn",
    ':': "wnnwnnn", '/': "nwnwnnn", '.': "nwnwnwn", '+': "nnwnwnw",
    'A': "nnwnwnn", 'B': "nwnnwnn", 'C': "nnnwnwn", 'D': "nnnwnnw",
    'a': "nnwnwnn", 'b': "nwnnwnn", 'c': "nnnwnwn", 'd': "nnnwnnw",
  }
  patterns.get(c)
}

///|
fn nw7_bits(value : String) -> String raise PdfmeError {
  let text = if value.length() >= 2 &&
    nw7_pattern(value[0].to_char().unwrap()).is_some() &&
    nw7_pattern(value[value.length() - 1].to_char().unwrap()).is_some() {
    value
  } else {
    "A" + value + "A"
  }
  let out = StringBuilder()
  let mut first = true
  for c in text {
    let pattern = match nw7_pattern(c) {
      Some(pattern) => pattern
      None => raise PdfmeError("pdfme: NW-7 has no such character")
    }
    if !first {
      out.write_char('0')
    }
    first = false
    let mut bar = true
    for element in pattern {
      let units = if element == 'w' { 3 } else { 1 }
      for _ in 0..<units {
        out.write_char(if bar { '1' } else { '0' })
      }
      bar = !bar
    }
  }
  out.to_string()
}

///|
fn FieldPainter::draw_nw7(
  self : FieldPainter,
  field : Json,
  data : Json,
  x : Float,
  y_top : Float,
  width : Float,
  height : Float,
) -> Unit raise PdfmeError {
  let value = field_text(field, data)
  if value == "" {
    return
  }
  let bits = nw7_bits(value)
  let cell = width / Float::from_double(bits.length().to_double())
  self.builder.fill_color(0x000000ff)
  for i in 0..<bits.length() {
    if bits[i] == '1' {
      self.builder.fill_rect(
        x + Float::from_double(i.to_double()) * cell,
        y_top - height,
        cell,
        height,
      )
    }
  }
}

