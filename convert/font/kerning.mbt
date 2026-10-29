///|
/// Describe GPOS kern features and the legacy kern table as in the upstream
/// font overview. Lookup counting uses GPOS's bounded shared work budget.
pub fn FileFace::kerning(self : FileFace) -> String {
  let parts : Array[String] = []
  match self.font.table("GPOS") {
    Some(data) =>
      match
        (
          @otlayout.parse_layout(data[:], gpos=true),
          @otlayout.parse_gpos(data[:]),
        ) {
        (Some(layout), Some(gpos)) => {
          let mut pairs = 0L
          for feature in layout.features {
            if feature.tag == "kern" {
              for lookup in feature.lookups {
                pairs += gpos.pair_count(lookup)
              }
            }
          }
          if pairs > 0L {
            parts.push("GPOS kern (about " + info_number(pairs) + " pairs)")
          }
        }
        _ => ()
      }
    None => ()
  }
  match self.font.table("kern") {
    Some(data) if data.length() >= 18 && be16(data[:], 0) == 0 =>
      parts.push(
        "kern table (" + info_number(be16(data[:], 10).to_int64()) + " pairs)",
      )
    _ => ()
  }
  parts.join(", ")
}
