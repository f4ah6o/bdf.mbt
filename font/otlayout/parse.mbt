///|
priv struct Lookup {
  typ : Int32
  subtables : Array[BytesView]
}

///|
/// Parsed GSUB lookup data, with the upstream work budget.
pub struct Gsub {
  priv lookups : Array[Lookup]
  priv mut steps : Int64
}

///|
fn budget_language(data : BytesView, left : Ref[Int32]) -> Unit {
  ignore(take(left, count(data, u16(data, 4), 6, 2)))
}

///|
fn budget_scripts(data : BytesView?, left : Ref[Int32]) -> Unit {
  guard data is Some(data) else { return }
  let n = count(data, u16(data, 0), 2, 6)
  if !take(left, n) {
    return
  }
  for i in 0..<n {
    let rec = 2 + i * 6
    guard at(data, u16(data, rec + 4)) is Some(script) else { continue }
    match at(script, u16(script, 0)) {
      Some(lang) => budget_language(lang, left)
      None => ()
    }
    let m = count(script, u16(script, 2), 4, 6)
    if !take(left, m) {
      return
    }
    for j in 0..<m {
      match at(script, u16(script, 4 + j * 6 + 4)) {
        Some(lang) => budget_language(lang, left)
        None => ()
      }
    }
    if left.val < 0 {
      return
    }
  }
}

///|
fn budget_features(data : BytesView?, left : Ref[Int32]) -> Unit {
  guard data is Some(data) else { return }
  let n = count(data, u16(data, 0), 2, 6)
  if !take(left, n) {
    return
  }
  for i in 0..<n {
    let rec = 2 + i * 6
    guard at(data, u16(data, rec + 4)) is Some(feature) else { continue }
    let m = count(feature, u16(feature, 2), 4, 2)
    if !take(left, m) {
      return
    }
    match at(feature, u16(feature, 0)) {
      Some(params) if data[rec] == b'c' &&
        data[rec + 1] == b'v' &&
        data[rec + 2] >= b'0' &&
        data[rec + 2] <= b'9' &&
        data[rec + 3] >= b'0' &&
        data[rec + 3] <= b'9' &&
        params.length() >= 14 &&
        u16(params, 0) == 0 =>
        ignore(take(left, count(params, u16(params, 12), 14, 3)))
      _ => ()
    }
    if left.val < 0 {
      return
    }
  }
}

///|
/// Parse the GSUB lookup list. Invalid or excessively large layout tables
/// return None, matching the font specimen converter's treatment.
pub fn parse_gsub(data : BytesView) -> Gsub? {
  let view = data
  if view.length() < 10 || u16(view, 0) != 1 {
    return None
  }
  let left = Ref(1048576)
  budget_scripts(at(view, u16(view, 4)), left)
  budget_features(at(view, u16(view, 6)), left)
  let lookups : Array[Lookup] = []
  match at(view, u16(view, 8)) {
    Some(list) => {
      let n = count(list, u16(list, 0), 2, 2)
      if !take(left, n) {
        return None
      }
      for i in 0..<n {
        let mut typ = 0
        let subtables : Array[BytesView] = []
        match at(list, u16(list, 2 + i * 2)) {
          Some(lookup) => {
            typ = u16(lookup, 0)
            let n = count(lookup, u16(lookup, 4), 6, 2)
            if !take(left, n) {
              return None
            }
            let extension = typ == 7
            if extension {
              typ = 0
            }
            for j in 0..<n {
              guard at(lookup, u16(lookup, 6 + j * 2)) is Some(subtable) else {
                continue
              }
              if extension {
                let ext_type = u16(subtable, 2)
                if u16(subtable, 0) != 1 ||
                  ext_type == 7 ||
                  (typ != 0 && typ != ext_type) {
                  continue
                }
                match at32(subtable, u32(subtable, 4)) {
                  Some(real) => {
                    typ = ext_type
                    subtables.push(real)
                  }
                  None => ()
                }
              } else {
                subtables.push(subtable)
              }
            }
          }
          None => ()
        }
        lookups.push({ typ, subtables, })
      }
    }
    None => ()
  }
  if left.val < 0 {
    return None
  }
  let budget = Int64::min(268435456L, 4194304L + 32L * data.length().to_int64())
  Some({ lookups, steps: budget, })
}
