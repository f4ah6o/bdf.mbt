///|
/// A positioning adjustment in font units.
pub(all) struct PositionValue {
  x_placement : Int32
  y_placement : Int32
  x_advance : Int32
  y_advance : Int32
}

///|
fn position_value(
  data : BytesView,
  offset : Int32,
  format : Int32,
) -> PositionValue {
  let fields = [0, 0, 0, 0]
  let mut pos = offset
  for bit in 0..<4 {
    if (format & (1 << bit)) != 0 {
      let raw = u16(data, pos)
      fields[bit] = if raw >= 32768 { raw - 65536 } else { raw }
      pos += 2
    }
  }
  {
    x_placement: fields[0],
    y_placement: fields[1],
    x_advance: fields[2],
    y_advance: fields[3],
  }
}

///|
/// Visit single-glyph positioning adjustments in subtable order. The first
/// applicable subtable wins for each glyph; the callback can stop iteration.
pub fn Gpos::each_single(
  self : Gpos,
  index : Int32,
  visit : (Int32, PositionValue) -> Bool,
) -> Unit {
  guard self.lookups.get(index) is Some(lookup) && lookup.typ == 1 else {
    return
  }
  let seen : Map[Int32, Bool] = Map([])
  for st in lookup.subtables {
    let cov = coverage(at(st, u16(st, 2)))
    if !self.spend(1L + cov.length().to_int64()) {
      return
    }
    let format = u16(st, 0)
    let vf = u16(st, 4)
    let size = value_size(vf)
    let n = if size == 0 { u16(st, 6) } else { count(st, u16(st, 6), 8, size) }
    for k, glyph in cov {
      let offset = if format == 1 {
        6
      } else if format == 2 && k < n {
        8 + k * size
      } else {
        continue
      }
      if seen.contains(glyph) {
        continue
      }
      seen[glyph] = true
      if !visit(glyph, position_value(st, offset, vf)) {
        return
      }
    }
  }
}

///|
/// Return the first applicable adjustment for a glyph pair, if any.
pub fn Gpos::pair_value(
  self : Gpos,
  index : Int32,
  first : Int32,
  second : Int32,
) -> (PositionValue, PositionValue)? {
  for sub in self.pair_subtables(index) {
    if !self.spend(1L) {
      return None
    }
    guard sub.coverage.get(first) is Some(k) else { continue }
    let s1 = value_size(sub.vf1)
    let s2 = value_size(sub.vf2)
    if sub.format == 1 {
      guard at(sub.data, u16(sub.data, 10 + k * 2)) is Some(set) else {
        continue
      }
      if k >= u16(sub.data, 8) {
        continue
      }
      let n = count(set, u16(set, 0), 2, 2 + s1 + s2)
      let mut low = 0
      let mut high = n
      while low < high {
        let mid = (low + high) / 2
        if u16(set, 2 + mid * (2 + s1 + s2)) < second {
          low = mid + 1
        } else {
          high = mid
        }
      }
      if low < n {
        let pos = 2 + low * (2 + s1 + s2)
        if u16(set, pos) == second {
          return Some(
            (
              position_value(set, pos + 2, sub.vf1),
              position_value(set, pos + 2 + s1, sub.vf2),
            ),
          )
        }
      }
    } else {
      let c1 = sub.class1.get(first).unwrap_or(0)
      let c2 = sub.class2.get(second).unwrap_or(0)
      if c1 >= sub.n1 || c2 >= sub.n2 {
        continue
      }
      let pos = 16 + (c1 * sub.n2 + c2) * (s1 + s2)
      return Some(
        (
          position_value(sub.data, pos, sub.vf1),
          position_value(sub.data, pos + s1, sub.vf2),
        ),
      )
    }
  }
  None
}
