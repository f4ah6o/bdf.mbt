///|
/// Draws specimen glyph runs as paths in one BDF object, caching path resources.
pub struct OutlinePainter {
  priv object : @core.ObjectBuilder
  priv outlines : SpecimenOutlines
  priv upem : Double
  priv paths : Map[Int32, Int32]
  priv mut fill_set : Bool
}

///|
/// Prepare an outline painter bound to one object and one font face.
pub fn FileFace::outline_painter(
  self : FileFace,
  object : @core.ObjectBuilder,
) -> OutlinePainter {
  {
    object,
    outlines: self.outlines(),
    upem: self.font.metrics.units_per_em.to_double(),
    paths: Map([]),
    fill_set: false,
  }
}

///|
/// Invalidate the cached fill after changing the object's drawing state.
pub fn OutlinePainter::reset_fill(self : OutlinePainter) -> Unit {
  self.fill_set = false
}

///|
fn OutlinePainter::ensure_fill(self : OutlinePainter) -> Unit {
  if !self.fill_set {
    self.object.fill_color(0x1f1f1fffU)
    self.fill_set = true
  }
}

///|
/// Draw glyphs at the supplied em offsets, with optional accessible replacement
/// text. Returns whether at least one outline was drawn.
pub fn OutlinePainter::draw(
  self : OutlinePainter,
  glyphs : Array[Int32],
  offsets : Array[Double],
  x : Double,
  y : Double,
  size : Double,
  alt : String,
) -> Bool raise {
  if glyphs.length() != offsets.length() {
    raise InvalidFontInput("font: glyph and offset counts differ")
  }
  if glyphs.length() == 0 {
    return false
  }
  self.ensure_fill()
  let run : Array[@core.ObjectGlyph] = []
  for i, glyph in glyphs {
    let ref = match self.paths.get(glyph) {
      Some(ref) => Some(ref)
      None =>
        match self.outlines.path(glyph) {
          Some(path) => {
            let ref = self.object.add_path(@core.Inline(path))
            self.paths[glyph] = ref
            Some(ref)
          }
          None => None
        }
    }
    match ref {
      Some(path) =>
        run.push({ path, x: specimen_f32(offsets[i] * self.upem), y: 0.0F, })
      None => ()
    }
  }
  if run.length() == 0 {
    return false
  }
  let k = specimen_f32(size / self.upem)
  self.object.save()
  self.object.transform(k, 0.0F, 0.0F, k, specimen_f32(x), specimen_f32(y))
  if alt != "" {
    self.object.mark(4, alt)
  }
  self.object.fill_path_run(0, run)
  self.object.restore()
  true
}
