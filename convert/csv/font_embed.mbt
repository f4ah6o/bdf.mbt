///|
fn csv_embed_font(
  font : @sfnt.Font,
  size : Int32,
  codepoints : Array[Int32],
  no_subset : Bool,
  ignore_restrictions : Bool,
) -> (Bytes?, String?) raise {
  @fontdb.prepare_font_program(
    font, size, codepoints, no_subset, ignore_restrictions,
  )
}
