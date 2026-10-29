///|
/// Prepared glyph outlines for one font specimen face.
pub struct SpecimenOutlines {
  priv font : @sfnt.Font
  priv cff : @sfnt.CffOutlines?
}

///|
/// Prepare TrueType or CFF glyph outlines for specimen rendering.
pub fn FileFace::outlines(self : FileFace) -> SpecimenOutlines {
  { font: self.font, cff: self.font.cff_outlines(), }
}

///|
/// Return a glyph's unscaled bounds in font units, with y pointing up.
pub fn SpecimenOutlines::bounds(
  self : SpecimenOutlines,
  glyph : Int32,
) -> (Double, Double, Double, Double)? {
  match self.cff {
    Some(cff) => cff.bounds(glyph)
    None => self.font.bounds_truetype(glyph)
  }
}

///|
/// Convert an outline to a BDF path in font units, with y pointing down.
/// Empty or unreadable outlines have no path, including partially read glyphs.
pub fn SpecimenOutlines::path(
  self : SpecimenOutlines,
  glyph : Int32,
) -> @core.Path? {
  let (ok, commands) = match self.cff {
    Some(cff) => cff.outline(glyph)
    None => self.font.outline_truetype(glyph)
  }
  if !ok || commands.length() == 0 {
    return None
  }
  let verbs : Array[Byte] = []
  let coords : Array[Double] = []
  for command in commands {
    let (verb, pairs) = match command {
      @sfnt.Move(x, y) => (0, [(x, y)])
      @sfnt.Line(x, y) => (1, [(x, y)])
      @sfnt.Quad(a, b, x, y) => (2, [(a, b), (x, y)])
      @sfnt.Cubic(a, b, c, d, x, y) => (3, [(a, b), (c, d), (x, y)])
      @sfnt.Close => (4, [])
    }
    verbs.push(verb.to_byte())
    for (x, y) in pairs {
      coords.push(specimen_f32(x).to_double())
      coords.push(specimen_f32(-y).to_double())
    }
  }
  Some({ verbs: Bytes::from_array(verbs), coordinates: coords, })
}
