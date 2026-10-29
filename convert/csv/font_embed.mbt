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

///|
fn csv_encode_font(
  data : Bytes,
  no_woff2 : Bool,
  warnings : Array[String],
) -> Bytes {
  if no_woff2 {
    return data
  }
  @woff2.encode(data) catch {
    @woff2.Woff2Failure(message) => {
      if message != "woff2: the font compresses more than decoders accept" {
        warnings.push("font: not stored as WOFF2: " + message)
      }
      data
    }
    error => {
      warnings.push("font: not stored as WOFF2: " + error.to_string())
      data
    }
  }
}
