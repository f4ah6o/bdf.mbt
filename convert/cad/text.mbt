///|
/// The font a piece of CAD text asks for.
pub(all) struct FontSpec {
  mut family : String
  east_asian : String
  bold : Bool
  italic : Bool
} derive(Eq, Debug)

///|
pub fn FontSpec::new(
  family~ : String = "",
  east_asian~ : String = "",
  bold~ : Bool = false,
  italic~ : Bool = false,
) -> FontSpec {
  { family, east_asian, bold, italic }
}

///|
/// How a text joins the text drawn before it, for text extraction.
pub(all) enum Break {
  BreakBox
  BreakParagraph
  BreakLine
  BreakWrap
  BreakNone
} derive(Eq, Debug)

///|
/// A line of text in one font. Its em space has the origin at the start of
/// the baseline, x along the text and y up, in ems; `m` maps it into the
/// drawing.
pub(all) struct CadText {
  s : String
  font : FontSpec
  color : UInt32
  m : @canvas.Matrix
  advance : Double
  cells : Array[Double]?
  spacing : Double
  asc : Double
  desc : Double
  cap : Double
  underline : Bool
  overline : Bool
  strike : Bool
  line_break : Break
  vertical : Bool
}

///|
pub fn CadText::new(
  s : String,
  m : @canvas.Matrix,
  font~ : FontSpec = FontSpec::new(),
  color~ : UInt32 = 0x000000ffU,
  advance~ : Double = 0.0,
  cells~ : Array[Double]? = None,
  spacing~ : Double = 0.0,
  asc~ : Double = 0.9,
  desc~ : Double = 0.25,
  cap~ : Double = 0.7,
  underline~ : Bool = false,
  overline~ : Bool = false,
  strike~ : Bool = false,
  line_break~ : Break = BreakBox,
  vertical~ : Bool = false,
) -> CadText {
  {
    s,
    font,
    color,
    m,
    advance,
    cells,
    spacing,
    asc,
    desc,
    cap,
    underline,
    overline,
    strike,
    line_break,
    vertical,
  }
}

///|
pub fn CadText::bounds(self : CadText) -> Rect {
  let rect : Rect = if self.vertical {
    {
      min: { x: 0.0, y: -0.5 },
      max: { x: self.advance, y: 0.5 },
      ok: true,
    }
  } else {
    {
      min: { x: 0.0, y: -self.desc },
      max: { x: self.advance, y: self.asc },
      ok: true,
    }
  }
  rect.transform(self.m)
}

///|
/// A line of text drawn with a stroke (plotter) font, such as KiCad's.
pub(all) struct CadStrokeText {
  s : String
  m : @canvas.Matrix
  strokes : CadPath
  pen : Pen
  parts : Array[CadText]
  line_break : Break
}

///|
/// Measure a string in ems with the fonts of the document.
pub fn measure(fonts : @canvas.Fonts, font : FontSpec, text : String) -> Double {
  fonts.measure(
    font.family,
    font.east_asian,
    font.bold,
    font.italic,
    text,
  )
}

///|
/// The ascent, descent and cap height of a font in ems.
pub fn font_metrics(
  fonts : @canvas.Fonts,
  font : FontSpec,
) -> (Double, Double, Double) {
  let choice = fonts.face(
    font.family,
    font.east_asian,
    72,
    bold=font.bold,
    italic=font.italic,
  )
  let metrics = fonts.metrics(choice)
  (metrics.asc, metrics.desc, metrics.cap)
}

///|
/// The underline position and thickness of a font in ems.
pub fn underline_metrics(
  fonts : @canvas.Fonts,
  font : FontSpec,
) -> (Double, Double) {
  let choice = fonts.face(
    font.family,
    font.east_asian,
    72,
    bold=font.bold,
    italic=font.italic,
  )
  let metrics = fonts.metrics(choice)
  (metrics.ul_pos, metrics.ul_thick)
}

///|
/// The language a character implies: "ja" for kana and "ko" for Hangul.
pub fn rune_lang(code : Int32) -> String {
  if (code >= 0x3040 && code <= 0x30ff) || (code >= 0xff66 && code <= 0xff9d) {
    return "ja"
  }
  if (code >= 0x1100 && code <= 0x11ff) || (code >= 0xac00 && code <= 0xd7af) {
    return "ko"
  }
  ""
}

///|
/// The East Asian script a language tag stands for.
pub fn script_of(lang : String) -> String {
  let lowered = lang.to_lower()
  if lowered.has_prefix("ja") {
    "Jpan"
  } else if lowered.has_prefix("zh-tw") ||
    lowered.has_prefix("zh-hk") ||
    lowered.has_prefix("zh-mo") ||
    lowered.has_prefix("zh-hant") {
    "Hant"
  } else if lowered.has_prefix("zh") {
    "Hans"
  } else if lowered.has_prefix("ko") {
    "Hang"
  } else {
    ""
  }
}
