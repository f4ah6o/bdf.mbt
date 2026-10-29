///|
/// Prepare a UI font program with the upstream font-set embedding limits.
/// Returns a warning when the face cannot be embedded under the given options.
pub fn prepare_font_program(
  font : @sfnt.Font,
  size : Int32,
  codepoints : Array[Int32],
  no_subset : Bool,
  ignore_restrictions : Bool,
) -> (Bytes?, String?) raise {
  let limit = 2 * 1024 * 1024
  let family = font.info.family
  if !no_subset && !font.can_subset(ignore_restrictions~) && size > limit {
    return (
      None,
      Some(
        "font " +
        family +
        " is not embedded: its outlines cannot be subset and the file is " +
        (size / 1024).to_string() +
        " KB",
      ),
    )
  }
  if !font.metrics.embeddable && !ignore_restrictions {
    return (
      None,
      Some(
        "font " +
        family +
        " is not embedded: its license does not allow embedding",
      ),
    )
  }
  let program = if no_subset {
    font.canvas_program()
  } else if font.metrics.subsettable || ignore_restrictions {
    match font.subset_program(codepoints) {
      Some(program) => program
      None => font.mapped_program(codepoints)
    }
  } else {
    font.mapped_program(codepoints)
  }
  if font.metrics.is_cff &&
    !no_subset &&
    size > limit &&
    program.length() > size / 2 {
    return (
      None,
      Some(
        "font " +
        family +
        " is not embedded: its outlines could not be subset and the file is " +
        (size / 1024).to_string() +
        " KB",
      ),
    )
  }
  (Some(program), None)
}
