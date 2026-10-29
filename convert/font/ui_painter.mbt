///|
/// Draw measured UI labels into the same object as specimen glyphs.
pub struct SpecimenUIPainter {
  priv painter : GlyphPainter
  priv texter : SpecimenTexter
  priv embedded : SpecimenUIFonts
  priv fonts : Map[String, Int32]
}

///|
/// Prepare UI drawing after all labels have been measured and fonts embedded.
pub fn SpecimenUIPainter::new(
  painter : GlyphPainter,
  texter : SpecimenTexter,
  embedded : SpecimenUIFonts,
) -> SpecimenUIPainter {
  { painter, texter, embedded, fonts: Map([]), }
}

///|
fn specimen_use_key(choice : @db.Choice) -> String {
  let resolved = choice.resolved
  let requested = choice.requested
  let generic = resolved.generic
  resolved.face.unwrap_or(-1).to_string() +
  ":" +
  choice.bold.to_string() +
  ":" +
  choice.italic.to_string() +
  ":" +
  resolved.synth_bold.to_string() +
  ":" +
  resolved.synth_italic.to_string() +
  ":" +
  requested.length().to_string() +
  ":" +
  requested +
  ":" +
  generic.length().to_string() +
  ":" +
  generic
}

///|
/// Draw one measured line. `x` is its left edge and `y` its baseline.
pub fn SpecimenUIPainter::text(
  self : SpecimenUIPainter,
  line : SpecimenTextLine,
  x : Double,
  y : Double,
  color : UInt32,
) -> Unit raise {
  let p = self.painter
  p.outlines.set_fill(color)
  for run in line.runs {
    if run.text == "" {
      continue
    }
    p.set_language(run.lang)
    let key = specimen_use_key(run.choice)
    let reference = match self.fonts.get(key) {
      Some(reference) => reference
      None => {
        let font = self.texter.font_record(run.choice, self.embedded)
        let reference = p.object.add_font(font)
        self.fonts[key] = reference
        reference
      }
    }
    p.set_font(reference, line.size)
    p.object.fill_text(
      run.text,
      specimen_f32(x + run.x),
      specimen_f32(y),
      specimen_f32(run.width),
    )
  }
  p.set_language("")
}

///|
/// Draw a measured label, aligned left (0), center (1) or right (2) at x.
pub fn SpecimenUIPainter::label(
  self : SpecimenUIPainter,
  line : SpecimenTextLine,
  x : Double,
  y : Double,
  color : UInt32,
  align : Int32,
) -> Double raise {
  self.text(line, x - line.width * align.to_double() / 2.0, y, color)
  line.width
}
