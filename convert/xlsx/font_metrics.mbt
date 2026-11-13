///|
/// The maximum digit width (MDW) of the workbook's default font, in whole
/// pixels at 96 dpi, measured with the supplied face the way upstream
/// measures it (`converter/xlsx/geom.go`, `maxDigitWidth`): the widest
/// digit advance of the default font times whole-pixel ppem, rounded —
/// except Calibri and Carlito, whose hinting draws digits a pixel narrower,
/// so their ppem stays unrounded. Characters the face lacks get the same
/// estimated advances as cell measurement. Without a face (the estimate
/// path) the MDW is the fixed 7 the estimated metrics assume.
fn xlsx_default_font_mdw(
  styles : XlsxStyles,
  theme : @ooxml.OoxmlThemeFonts,
  script : String,
  font : @sfnt.Font?,
) -> Double {
  let face = match font {
    Some(face) => face
    None => return 7.0
  }
  let (name, size) = if styles.fonts.is_empty() {
    // Real conversions always have a synthesized minor-scheme Calibri 11
    // entry; this branch only serves direct callers without one.
    ("Calibri", 11.0)
  } else {
    let default_font = styles.fonts[0]
    let themed = if default_font.scheme == "minor" {
      theme.resolve("+mn-lt", script)
    } else if default_font.scheme == "major" {
      theme.resolve("+mj-lt", script)
    } else {
      ""
    }
    let name = if themed != "" {
      themed
    } else if default_font.name != "" {
      default_font.name
    } else {
      "Calibri"
    }
    let size = if default_font.size > 0.0 { default_font.size } else { 11.0 }
    (name, size)
  }
  let mut widest = 0.0
  for code in 48..<=57 {
    let character = code.unsafe_to_char()
    let em = match face.glyph(character.to_int()) {
      Some(glyph) => face.advance(glyph)
      None => @sheet.fallback_advance(character, false) / 11.0
    }
    widest = Double::max(widest, em)
  }
  if widest == 0.0 {
    return 7.0
  }
  let ppem = if name.to_lower() == "calibri" || name.to_lower() == "carlito" {
    size * 96.0 / 72.0
  } else {
    (size * 96.0 / 72.0).round()
  }
  Double::max(1.0, (widest * ppem).round())
}

///|
/// The workbook's fallback row height is based on the default face's line
/// metrics when a face was provided; without a face keep the estimate path.
/// The SFNT parser expresses both ascent and descent as positive em values.
fn xlsx_default_font_line_height(size : Double, font : @sfnt.Font?) -> Double {
  let estimate = (0.9 + 0.25) * size
  match font {
    Some(face) => {
      let line_em = face.metrics.ascent + face.metrics.descent
      if line_em.is_nan() || line_em.is_inf() || line_em <= 0.0 {
        estimate
      } else {
        line_em * size
      }
    }
    None => estimate
  }
}

///|
/// Keep the estimate path's arithmetic order unchanged for byte parity.
fn xlsx_fitted_line_height(size : Double, font : @sfnt.Font?) -> Double {
  match font {
    Some(_) => xlsx_default_font_line_height(size, font)
    None => 0.9 * size + 0.25 * size
  }
}

///|
/// Match the renderer's single-face advances, keeping its estimate when the
/// selected face does not contain the character.
fn xlsx_fitted_advance(
  c : Char,
  bold : Bool,
  size : Double,
  font : @sfnt.Font?,
) -> Double {
  match font {
    Some(face) =>
      match face.glyph(c.to_int()) {
        Some(glyph) => face.advance(glyph) * size
        None => @sheet.sized_fallback_advance(c, bold, size)
      }
    None => @sheet.sized_fallback_advance(c, bold, size)
  }
}
