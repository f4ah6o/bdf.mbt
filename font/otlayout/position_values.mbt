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

///|
/// One nonzero pair-positioning adjustment.
pub(all) struct PositionPair {
  first : Int32
  second : Int32
  first_value : PositionValue
  second_value : PositionValue
}

///|
priv struct PositionClassAdjustment {
  second_class : Int32
  first_value : PositionValue
  second_value : PositionValue
}

///|
fn PositionValue::is_zero(self : PositionValue) -> Bool {
  self.x_placement == 0 &&
  self.y_placement == 0 &&
  self.x_advance == 0 &&
  self.y_advance == 0
}

///|
/// Visit nonzero pair adjustments, expanding class pairs in upstream order.
/// The callback can stop iteration before large class expansions complete.
pub fn Gpos::each_pair(
  self : Gpos,
  index : Int32,
  visit : (PositionPair) -> Bool,
) -> Unit {
  for sub in self.pair_subtables(index) {
    let s1 = value_size(sub.vf1)
    let s2 = value_size(sub.vf2)
    let cov = coverage(at(sub.data, u16(sub.data, 2)))
    if sub.format == 1 {
      if !self.spend(1L + cov.length().to_int64()) {
        return
      }
      for first in cov {
        let k = sub.coverage[first]
        if k >= u16(sub.data, 8) {
          continue
        }
        let set = at(sub.data, u16(sub.data, 10 + k * 2)).unwrap_or(b""[:])
        let n = count(set, u16(set, 0), 2, 2 + s1 + s2)
        if !self.spend(n.to_int64()) {
          return
        }
        for j in 0..<n {
          let pos = 2 + j * (2 + s1 + s2)
          let v1 = position_value(set, pos + 2, sub.vf1)
          let v2 = position_value(set, pos + 2 + s1, sub.vf2)
          if (!v1.is_zero() || !v2.is_zero()) &&
            !visit({
              first,
              second: u16(set, pos),
              first_value: v1,
              second_value: v2,
            }) {
            return
          }
        }
      }
    } else {
      if !self.spend(
          1L +
          cov.length().to_int64() +
          sub.class2.length().to_int64() +
          sub.n1.to_int64() * sub.n2.to_int64(),
        ) {
        return
      }
      let class_glyphs : Map[Int32, Array[Int32]] = Map([])
      for glyph, class in sub.class2 {
        let glyphs = match class_glyphs.get(class) {
          Some(glyphs) => glyphs
          None => {
            let glyphs : Array[Int32] = []
            class_glyphs[class] = glyphs
            glyphs
          }
        }
        glyphs.push(glyph)
      }
      for _, glyphs in class_glyphs {
        glyphs.sort()
      }
      let adjustments : Array[Array[PositionClassAdjustment]] = [
        for _ in 0..<sub.n1 => []
      ]
      for c1 in 0..<sub.n1 {
        for c2 in 1..<sub.n2 {
          let pos = 16 + (c1 * sub.n2 + c2) * (s1 + s2)
          let v1 = position_value(sub.data, pos, sub.vf1)
          let v2 = position_value(sub.data, pos + s1, sub.vf2)
          if (!v1.is_zero() || !v2.is_zero()) &&
            class_glyphs.get(c2).unwrap_or([]).length() > 0 {
            adjustments[c1].push({
              second_class: c2,
              first_value: v1,
              second_value: v2,
            })
          }
        }
      }
      for first in cov {
        let c1 = sub.class1.get(first).unwrap_or(0)
        if c1 >= sub.n1 {
          continue
        }
        for a in adjustments[c1] {
          let glyphs = class_glyphs[a.second_class]
          if !self.spend(glyphs.length().to_int64()) {
            return
          }
          for second in glyphs {
            if !visit({
                first,
                second,
                first_value: a.first_value,
                second_value: a.second_value,
              }) {
              return
            }
          }
        }
      }
    }
  }
}
