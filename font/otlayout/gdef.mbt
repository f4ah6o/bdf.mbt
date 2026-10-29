///|
/// Glyph classes, mark attachment classes, and mark-filtering sets from GDEF.
pub(all) struct Gdef {
  classes : Map[Int32, Int32]
  mark_attach : Map[Int32, Int32]
  mark_sets : Array[Array[Int32]]
}

///|
fn class_definition(data : BytesView?) -> Map[Int32, Int32] {
  let out : Map[Int32, Int32] = Map([])
  guard data is Some(data) else { return out }
  match u16(data, 0) {
    1 => {
      let start = u16(data, 2)
      let n = count(data, u16(data, 4), 6, 2)
      for i in 0..<n {
        let c = u16(data, 6 + i * 2)
        if c != 0 && start + i < 65536 {
          out[start + i] = c
        }
      }
    }
    2 => {
      let n = count(data, u16(data, 2), 4, 6)
      let mut total = 0
      for i in 0..<n {
        let rec = 4 + i * 6
        let start = u16(data, rec)
        let end = u16(data, rec + 2)
        let c = u16(data, rec + 4)
        if c == 0 {
          continue
        }
        for glyph in start..<=end {
          if total >= 65536 {
            break
          }
          out[glyph] = c
          total += 1
        }
      }
    }
    _ => ()
  }
  out
}

///|
/// Parse a GDEF table. Invalid headers return None; shared mark coverages
/// are bounded by the same aggregate work limit as the upstream converter.
pub fn parse_gdef(data : BytesView) -> Gdef? {
  if data.length() < 12 || u16(data, 0) != 1 {
    return None
  }
  let classes = class_definition(at(data, u16(data, 4)))
  let mark_attach = class_definition(at(data, u16(data, 10)))
  let mark_sets : Array[Array[Int32]] = []
  if u16(data, 2) >= 2 && data.length() >= 14 {
    match at(data, u16(data, 12)) {
      Some(ms) if u16(ms, 0) == 1 => {
        let n = count(ms, u16(ms, 2), 4, 4)
        let left = Ref(1048576)
        for i in 0..<n {
          let cov = coverage(at32(ms, u32(ms, 4 + i * 4)))
          if !take(left, 1 + cov.length()) {
            break
          }
          mark_sets.push(cov)
        }
      }
      _ => ()
    }
  }
  Some({ classes, mark_attach, mark_sets, })
}
