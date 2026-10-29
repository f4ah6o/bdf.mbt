///|
/// Build the unsubsetted sample font for this face, or None when it exceeds
/// upstream's size limits. The caller checks embedding permissions.
pub fn FileFace::sample_whole_program(self : FileFace) -> Bytes? raise {
  self.font.specimen_whole_sample(self.size)
}

///|
/// Build a TrueType sample from glyphs reachable by shaping. The caller
/// supplies the substitution closure and checks embedding permissions.
pub fn FileFace::sample_pruned_truetype(
  self : FileFace,
  glyphs : Array[Int32],
) -> Bytes? raise {
  self.font.specimen_pruned_truetype(glyphs, self.size)
}

///|
/// Build a TrueType specimen sample for text, including glyphs reachable by
/// GSUB substitutions. Returns None for unsupported outlines or size limits.
/// The caller checks embedding and subsetting permissions.
pub fn FileFace::sample_truetype(
  self : FileFace,
  text : String,
) -> Bytes? raise {
  self.font.specimen_sample_truetype(text, self.size)
}
