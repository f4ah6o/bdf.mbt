///|
/// Number of contextual rules and unique nested lookups in first-seen order.
pub(all) struct LookupContext {
  rules : Int32
  nested : Array[Int32]
}

///|
fn lookup_context(
  typ : Int32,
  subtables : Array[BytesView],
  lookup_count : Int32,
  gpos : Bool,
  spend : (Int32) -> Bool,
  truncated : () -> Bool,
) -> LookupContext? {
  let contextual = if gpos { 7 } else { 5 }
  let chained_type = if gpos { 8 } else { 6 }
  if !gpos && typ == 8 {
    return Some({ rules: subtables.length(), nested: [], })
  }
  if typ != contextual && typ != chained_type {
    return None
  }
  let chained = typ == chained_type
  let rules = Ref(0)
  let nested : Array[Int32] = []
  let seen : Map[Int32, Bool] = Map([])
  let records = (data : BytesView, offset : Int32, total : Int32) => {
    let n = count(data, total, offset, 4)
    if !spend(n) {
      return
    }
    for k in 0..<n {
      let index = u16(data, offset + k * 4 + 2)
      if index < lookup_count && !seen.contains(index) {
        seen[index] = true
        nested.push(index)
      }
    }
  }
  let rule = (data : BytesView?) => {
    guard data is Some(data) else { return }
    rules.val += 1
    if !chained {
      let glyphs = u16(data, 0)
      records(data, 4 + Int32::max(glyphs - 1, 0) * 2, u16(data, 2))
    } else {
      let mut pos = 0
      pos += 2 + u16(data, pos) * 2
      pos += 2 + Int32::max(u16(data, pos) - 1, 0) * 2
      pos += 2 + u16(data, pos) * 2
      records(data, pos + 2, u16(data, pos))
    }
  }
  for data in subtables {
    if !spend(1) {
      break
    }
    match u16(data, 0) {
      1 | 2 => {
        let offset = if u16(data, 0) == 1 {
          4
        } else if chained {
          10
        } else {
          6
        }
        let n = count(data, u16(data, offset), offset + 2, 2)
        for k in 0..<n {
          guard at(data, u16(data, offset + 2 + k * 2)) is Some(set) else {
            continue
          }
          let m = count(set, u16(set, 0), 2, 2)
          if !spend(1 + m) {
            break
          }
          for j in 0..<m {
            rule(at(set, u16(set, 2 + j * 2)))
          }
        }
      }
      3 => {
        rules.val += 1
        if !chained {
          records(data, 6 + u16(data, 2) * 2, u16(data, 4))
        } else {
          let mut pos = 2
          pos += 2 + u16(data, pos) * 2
          pos += 2 + u16(data, pos) * 2
          pos += 2 + u16(data, pos) * 2
          records(data, pos + 2, u16(data, pos))
        }
      }
      _ => ()
    }
    if truncated() {
      break
    }
  }
  Some({ rules: rules.val, nested, })
}

///|
/// Read a GSUB contextual lookup's rules and referenced lookups.
pub fn Gsub::context(self : Gsub, index : Int32) -> LookupContext? {
  guard self.lookups.get(index) is Some(lookup) else { return None }
  lookup_context(
    lookup.typ,
    lookup.subtables,
    self.lookups.length(),
    false,
    n => self.spend(n),
    () => self.truncated(),
  )
}

///|
/// Read a GPOS contextual lookup's rules and referenced lookups.
pub fn Gpos::context(self : Gpos, index : Int32) -> LookupContext? {
  guard self.lookups.get(index) is Some(lookup) else { return None }
  lookup_context(
    lookup.typ,
    lookup.subtables,
    self.lookups.length(),
    true,
    n => self.spend(n.to_int64()),
    () => self.truncated(),
  )
}
