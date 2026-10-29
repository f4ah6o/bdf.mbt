///|
/// Parse the face's glyph classes and mark filtering sets, if it has a GDEF table.
pub fn FileFace::glyph_definitions(self : FileFace) -> @otlayout.Gdef? {
  match self.font.table("GDEF") {
    Some(data) => @otlayout.parse_gdef(data[:])
    None => None
  }
}
