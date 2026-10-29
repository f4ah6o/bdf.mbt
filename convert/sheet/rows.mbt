///|
/// Upstream's fallback ascent and descent, in points at size 11.
pub fn fallback_line_metrics(
  _character : Char,
  _bold : Bool,
) -> (Double, Double) {
  (0.9 * 11.0, 0.25 * 11.0)
}

///|
/// Calculate automatic heights for the supplied grid rows. Each character's
/// metrics callback returns its ascent and descent in points; it can choose
/// different faces for bold headers or individual characters.
pub fn fit_rows(
  rows : Array[Array[Cell]],
  columns : Array[Float],
  header_rows~ : Int32 = 0,
  subheader~ : Bool = false,
  mdw~ : Double = 7.0,
  advance~ : (Char, Bool) -> Double = fallback_advance,
  metrics~ : (Char, Bool) -> (Double, Double) = fallback_line_metrics,
  default_line_height~ : Double = (0.9 + 0.25) * 11.0,
  style_line_height~ : ((Bool) -> Double)? = None,
) -> Array[Float] raise {
  if mdw.is_nan() ||
    mdw.is_inf() ||
    mdw <= 0.0 ||
    default_line_height.is_nan() ||
    default_line_height.is_inf() ||
    default_line_height <= 0.0 {
    raise InvalidArgument("invalid font metrics")
  }
  let default_column = ((8.0 * mdw + 5.0) / 8.0).ceil() * 8.0 * 0.75
  let default_row = ((default_line_height / 0.75 - 0.05).ceil() + 2.0) * 0.75
  let result : Array[Float] = []
  for row_index, row in rows {
    if row_index >= 1048576 {
      break
    }
    let mut height = default_row
    let bold = row_index < header_rows &&
      !(subheader && row_index == header_rows - 1)
    for column, cell in row {
      if column >= 16384 {
        break
      }
      if cell.text == "" {
        continue
      }
      let wraps = cell.text.contains("\n") || cell.text.contains("\r")
      let style_height = match style_line_height {
        Some(get_height) => get_height(bold)
        None => default_line_height
      }
      if !wraps && style_height <= default_line_height + 0.01 {
        continue
      }
      let column_width = if column < columns.length() {
        columns[column].to_double()
      } else {
        default_column
      }
      let width = if wraps { column_width - 3.75 } else { 1.0e300 }
      let lines = wrap_text(cell.text, width, bold~, advance~)
      let mut text_height = 0.0
      for line in lines {
        let mut ascent = 0.0
        let mut descent = 0.0
        for character in line.text {
          let (a, d) = metrics(character, bold)
          ascent = Double::max(ascent, a)
          descent = Double::max(descent, d)
        }
        if ascent == 0.0 && descent == 0.0 {
          let (a, d) = metrics('x', bold)
          ascent = a
          descent = d
        }
        text_height += ascent + descent
      }
      let fitted = ((text_height / 0.75 - 0.05).ceil() + 2.0) * 0.75
      height = Double::max(height, fitted)
    }
    result.push(Float::from_double(Double::min(height, 409.5)))
  }
  result
}
