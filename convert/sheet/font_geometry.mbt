///|
/// Measure a single-font grid with the supplied SFNT face. Unmapped
/// characters use the same estimated advances as the upstream font set.
/// This computes geometry only; embedding and font selection are separate.
pub fn grid_geometry_with_font(
  cells : Array[Array[Cell]],
  font : @sfnt.Font,
  header_rows~ : Int32 = 0,
  subheader~ : Bool = false,
  filter_buttons~ : Bool = false,
  table_rows~ : Int32 = 0,
  language~ : String = "",
) -> GridGeometry raise {
  let advance = (character : Char, _bold : Bool) => {
    font_advance(font, character)
  }
  let mdw = font_mdw(font, language)
  let ascent = font.metrics.ascent * 11.0
  let descent = font.metrics.descent * 11.0
  grid_geometry(
    cells,
    header_rows~,
    subheader~,
    filter_buttons~,
    table_rows~,
    mdw~,
    advance~,
    metrics=(_, _) => (ascent, descent),
    default_line_height=ascent + descent,
  )
}

///|
fn font_advance(font : @sfnt.Font, character : Char) -> Double {
  match font.glyph(character.to_int()) {
    Some(glyph) => font.advance(glyph) * 11.0
    None => fallback_advance(character, false)
  }
}

///|
fn font_mdw(font : @sfnt.Font, language : String) -> Double {
  let mut widest = 0.0
  for digit in 48..<=57 {
    widest = Double::max(
      widest,
      font_advance(font, digit.unsafe_to_char()) / 11.0,
    )
  }
  if widest == 0.0 {
    7.0
  } else {
    let ppem = if grid_script(language) == 0 {
      11.0 * 96.0 / 72.0
    } else {
      15.0
    }
    Double::max(1.0, (widest * ppem).round())
  }
}
