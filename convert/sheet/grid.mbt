///|
/// An unformatted cell displayed in a sheet.
pub(all) struct Cell {
  text : String
  number : Bool
} derive(Debug, Eq)

///|
/// The upstream font fallback's character width in points at size 11.
pub fn fallback_advance(character : Char, _bold : Bool) -> Double {
  let code = character.to_int()
  if code == 0x20 || code == 0xa0 {
    2.75
  } else if is_cjk(code) {
    11.0
  } else if code < 0x20 || code == 0x200b || code == 0xfeff {
    0.0
  } else {
    0.55 * 11.0
  }
}

///|
fn is_cjk(code : Int32) -> Bool {
  (code >= 0x1100 && code <= 0x11ff) ||
  (code >= 0x2e80 && code <= 0x2fdf) ||
  (code >= 0x2ff0 && code <= 0x303f) ||
  (code >= 0x3040 && code <= 0x33ff) ||
  (code >= 0x3400 && code <= 0x4dbf) ||
  (code >= 0x4e00 && code <= 0x9fff) ||
  (code >= 0xa960 && code <= 0xa97f) ||
  (code >= 0xac00 && code <= 0xd7ff) ||
  (code >= 0xf900 && code <= 0xfaff) ||
  (code >= 0xfe30 && code <= 0xfe4f) ||
  (code >= 0xff00 && code <= 0xffef) ||
  (code >= 0x20000 && code <= 0x3ffff) ||
  (code >= 0x16fe2 && code <= 0x16fe3) ||
  (code >= 0x16ff0 && code <= 0x16ff6)
}

///|
fn text_width(
  text : String,
  bold : Bool,
  advance : (Char, Bool) -> Double,
) -> Double {
  let mut best = 0.0
  let mut width = 0.0
  let mut count = 0
  for character in text {
    if character == '\n' || character == '\r' {
      best = Double::max(best, width)
      width = 0.0
      continue
    }
    let character = if character == '\t' { ' ' } else { character }
    if character.to_int() < 0x20 {
      continue
    }
    width += advance(character, bold)
    count += 1
    if count >= 1024 {
      break
    }
  }
  Double::max(best, width)
}

///|
/// Calculate the fitted widths of all used columns in points. The maximum
/// digit width is in pixels at 96 dpi; advance measures a character in
/// points. Header filter buttons add 16 pixels. Text widths are capped at
/// 50 digits, while numeric values can widen a column beyond that cap.
pub fn fit_columns(
  rows : Array[Array[Cell]],
  header_rows~ : Int32 = 0,
  subheader~ : Bool = false,
  filter_buttons~ : Bool = false,
  mdw~ : Double = 7.0,
  advance~ : (Char, Bool) -> Double = fallback_advance,
) -> Array[Float] raise {
  if mdw.is_nan() || mdw.is_inf() || mdw <= 0.0 {
    raise InvalidArgument("invalid maximum digit width")
  }
  let widest : Array[Double] = []
  let numeric : Array[Double] = []
  for row_index, row in rows {
    if row_index >= 1048576 {
      break
    }
    for column, cell in row {
      if column >= 16384 {
        break
      }
      if cell.text == "" {
        continue
      }
      while widest.length() <= column {
        widest.push(0.0)
        numeric.push(0.0)
      }
      let bold = row_index < header_rows &&
        !(subheader && row_index == header_rows - 1)
      let mut width = text_width(cell.text, bold, advance)
      if filter_buttons && row_index < header_rows {
        width += 12.0
      }
      if cell.number {
        numeric[column] = Double::max(numeric[column], width)
      } else {
        widest[column] = Double::max(widest[column], width)
      }
    }
  }
  let default_width = ((8.0 * mdw + 5.0) / 8.0).ceil() * 8.0 * 0.75
  let max_text_width = (50.0 * mdw + 5.0) * 0.75
  let result : Array[Float] = []
  for i in 0..<widest.length() {
    let text_fit = ((widest[i] / 0.75 - 0.01).ceil() + 7.0) * 0.75
    let number_fit = ((numeric[i] / 0.75 - 0.01).ceil() + 7.0) * 0.75
    let text_width = Double::min(text_fit, max_text_width)
    result.push(
      Float::from_double(
        Double::max(default_width, Double::max(text_width, number_fit)),
      ),
    )
  }
  result
}

///|
pub suberror SheetError {
  InvalidArgument(String)
} derive(Debug)
