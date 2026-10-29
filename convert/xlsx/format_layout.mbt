///|
/// Numeric placeholders and scaling directives in a format section.
pub(all) struct XlsxNumberLayout {
  mut integer : String
  mut fraction_digits : String
  mut point : Bool
  mut thousands : Bool
  mut scale : Int32
  mut percent : Int32
  mut exponent : String
  mut exponent_digits : String
  mut numerator : String
  mut denominator : String
  mut fixed_denominator : Int64
  mut fraction : Bool
  mut general : Bool
}

///|
/// Analyze the numeric parts of a parsed XLSX format section.
pub fn xlsx_analyze_number_format(
  section : XlsxFormatSection,
) -> XlsxNumberLayout {
  let layout : XlsxNumberLayout = {
    integer: "",
    fraction_digits: "",
    point: false,
    thousands: false,
    scale: 0,
    percent: 0,
    exponent: "",
    exponent_digits: "",
    numerator: "",
    denominator: "",
    fixed_denominator: 0L,
    fraction: false,
    general: false,
  }
  let tokens = section.tokens
  let mut last_digit = -1
  for i in 0..<tokens.length() {
    match tokens[i].kind {
      12 => layout.general = true
      9 => layout.fraction = true
      4 => last_digit = i
      _ => ()
    }
  }
  if layout.fraction {
    let mut slash = -1
    for i in 0..<tokens.length() {
      if tokens[i].kind == 9 {
        slash = i
      }
    }
    let mut i = slash + 1
    while i < tokens.length() {
      let token = tokens[i]
      if token.kind == 4 {
        layout.denominator += token.text
        i += 1
        continue
      }
      if token.kind == 0 && layout.denominator == "" {
        match xlsx_int(xlsx_trim(token.text)) {
          Some(n) => if n > 0L { layout.fixed_denominator = n }
          None => ()
        }
      }
      break
    }
    let mut j = slash - 1
    while j >= 0 && tokens[j].kind == 0 {
      j -= 1
    }
    while j >= 0 && tokens[j].kind == 4 {
      layout.numerator = tokens[j].text + layout.numerator
      j -= 1
    }
    for k in 0..<(j + 1) {
      if tokens[k].kind == 4 {
        layout.integer += tokens[k].text
      }
      if tokens[k].kind == 6 {
        layout.thousands = true
      }
    }
    for token in tokens {
      if token.kind == 7 {
        layout.percent += 1
      }
    }
    return layout
  }
  let mut part = 0
  for i in 0..<tokens.length() {
    let token = tokens[i]
    match token.kind {
      4 =>
        if part == 0 {
          layout.integer += token.text
        } else if part == 1 {
          layout.fraction_digits += token.text
        } else if part == 2 {
          layout.exponent_digits += token.text
        }
      5 =>
        if part == 0 {
          layout.point = true
          part = 1
        }
      8 =>
        if part < 2 {
          layout.exponent = token.text
          part = 2
        }
      7 => layout.percent += 1
      6 => {
        if part != 0 && part != 1 {
          continue
        }
        let mut j = i + 1
        while j < tokens.length() && tokens[j].kind == 6 {
          j += 1
        }
        let next = if j < tokens.length() { tokens[j].kind } else { 0 }
        if part == 0 && next == 4 && layout.integer != "" {
          layout.thousands = true
        } else if i > last_digit || next != 4 {
          let mut k = i - 1
          while k >= 0 && tokens[k].kind == 6 {
            k -= 1
          }
          if k >= 0 && tokens[k].kind == 4 {
            layout.scale += 1
          }
        }
      }
      _ => ()
    }
  }
  layout
}
