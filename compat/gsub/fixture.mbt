///|
#export_name("inspect_gsub")
pub fn inspect_gsub(data : Bytes, roots : Array[Int32]) -> String {
  let (valid, result, truncated) = match @otlayout.parse_gsub(data[:]) {
    Some(gsub) => (true, gsub.reachable(roots), gsub.truncated())
    None => {
      let unique : Map[Int32, Bool] = Map([])
      for root in roots {
        if root >= 0 && root <= 65535 {
          unique[root] = true
        }
      }
      let result = unique.keys().collect()
      result.sort()
      (false, result, false)
    }
  }
  Json::object({
    "valid": Json::boolean(valid),
    "result": Json::array(result.map(glyph => Json::number(glyph.to_double()))),
    "truncated": Json::boolean(truncated),
  }).stringify()
}
