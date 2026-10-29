///|
priv struct PositionLookup {
  typ : Int32
  subtables : Array[BytesView]
}

///|
priv struct PairSubtable {
  data : BytesView
  format : Int32
  vf1 : Int32
  vf2 : Int32
  coverage : Map[Int32, Int32]
  class1 : Map[Int32, Int32]
  class2 : Map[Int32, Int32]
  n1 : Int32
  n2 : Int32
}

///|
/// A GPOS table with a bounded shared work budget and cached pair subtables.
pub struct Gpos {
  priv lookups : Array[PositionLookup]
  priv cache : Map[Int32, Array[PairSubtable]]
  priv mut steps : Int64
}

///|
/// Parse GPOS pair-adjustment lookups. Invalid or oversized tables return None.
pub fn parse_gpos(data : BytesView) -> Gpos? {
  if parse_layout(data, gpos=true) is None {
    return None
  }
  let lookups : Array[PositionLookup] = []
  match at(data, u16(data, 8)) {
    Some(list) => {
      let n = count(list, u16(list, 0), 2, 2)
      for i in 0..<n {
        let mut typ = 0
        let subtables : Array[BytesView] = []
        match at(list, u16(list, 2 + i * 2)) {
          Some(lookup) => {
            typ = u16(lookup, 0)
            let n = count(lookup, u16(lookup, 4), 6, 2)
            let extension = typ == 9
            if extension {
              typ = 0
            }
            for j in 0..<n {
              guard at(lookup, u16(lookup, 6 + j * 2)) is Some(subtable) else {
                continue
              }
              if extension {
                let t = u16(subtable, 2)
                if u16(subtable, 0) != 1 || t == 9 || (typ != 0 && typ != t) {
                  continue
                }
                match at32(subtable, u32(subtable, 4)) {
                  Some(real) => {
                    typ = t
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
  Some({
    lookups,
    cache: Map([]),
    steps: Int64::min(268435456L, 4194304L + 32L * data.length().to_int64()),
  })
}

///|
/// Whether lookup enumeration exhausted the upstream table-wide work budget.
pub fn Gpos::truncated(self : Gpos) -> Bool {
  self.steps < 0L
}

///|
fn Gpos::spend(self : Gpos, n : Int64) -> Bool {
  self.steps -= n
  self.steps >= 0L
}

///|
fn value_size(format : Int32) -> Int32 {
  let mut bits = format & 255
  let mut size = 0
  while bits != 0 {
    size += 2 * (bits & 1)
    bits = bits >> 1
  }
  size
}

///|
fn value_nonzero(data : BytesView, offset : Int32, format : Int32) -> Bool {
  let mut pos = offset
  for bit in 0..<4 {
    if (format & (1 << bit)) != 0 {
      if u16(data, pos) != 0 {
        return true
      }
      pos += 2
    }
  }
  false
}

///|
fn Gpos::pair_subtables(self : Gpos, index : Int32) -> Array[PairSubtable] {
  if index < 0 || index >= self.lookups.length() || self.lookups[index].typ != 2 {
    return []
  }
  match self.cache.get(index) {
    Some(value) => return value
    None => ()
  }
  let out : Array[PairSubtable] = []
  for st in self.lookups[index].subtables {
    let format = u16(st, 0)
    let vf1 = u16(st, 4)
    let vf2 = u16(st, 6)
    let glyphs = coverage(at(st, u16(st, 2)))
    if !self.spend(1L + glyphs.length().to_int64()) {
      break
    }
    let cov : Map[Int32, Int32] = Map([])
    for i, glyph in glyphs {
      if !cov.contains(glyph) {
        cov[glyph] = i
      }
    }
    let class1 : Map[Int32, Int32] = Map([])
    let class2 : Map[Int32, Int32] = Map([])
    let mut n1 = 0
    let mut n2 = 0
    if format == 2 {
      let first = class_definition(at(st, u16(st, 8)))
      let second = class_definition(at(st, u16(st, 10)))
      for glyph, c in first {
        class1[glyph] = c
      }
      for glyph, c in second {
        class2[glyph] = c
      }
      if !self.spend(class1.length().to_int64() + class2.length().to_int64()) {
        continue
      }
      n1 = u16(st, 12)
      n2 = u16(st, 14)
      let rec = value_size(vf1) + value_size(vf2)
      if rec == 0 ||
        n1.to_int64() * n2.to_int64() > ((st.length() - 16) / rec).to_int64() {
        continue
      }
    } else if format != 1 {
      continue
    }
    out.push({
      data: st,
      format,
      vf1,
      vf2,
      coverage: cov,
      class1,
      class2,
      n1,
      n2,
    })
  }
  self.cache[index] = out
  out
}

///|
/// Approximate the nonzero glyph pairs in a GPOS pair lookup, preserving the
/// upstream subtable and class counting rules and shared work budget.
pub fn Gpos::pair_count(self : Gpos, index : Int32) -> Int64 {
  let mut total = 0L
  for sub in self.pair_subtables(index) {
    let s1 = value_size(sub.vf1)
    let s2 = value_size(sub.vf2)
    if sub.format == 1 {
      let n = count(sub.data, u16(sub.data, 8), 10, 2)
      for k in 0..<n {
        let set = at(sub.data, u16(sub.data, 10 + k * 2)).unwrap_or(b""[:])
        let m = count(set, u16(set, 0), 2, 2 + s1 + s2)
        if !self.spend(1L + m.to_int64()) {
          return total
        }
        for j in 0..<m {
          let pos = 2 + j * (2 + s1 + s2)
          if value_nonzero(set, pos + 2, sub.vf1) ||
            value_nonzero(set, pos + 2 + s1, sub.vf2) {
            total += 1L
          }
        }
      }
    } else {
      if !self.spend(
          sub.coverage.length().to_int64() +
          sub.class2.length().to_int64() +
          sub.n1.to_int64() * sub.n2.to_int64(),
        ) {
        return total
      }
      let sizes1 = [ for _ in 0..<sub.n1 => 0 ]
      let sizes2 = [ for _ in 0..<sub.n2 => 0 ]
      for glyph, _ in sub.coverage {
        let c = sub.class1.get(glyph).unwrap_or(0)
        if c < sub.n1 {
          sizes1[c] += 1
        }
      }
      for _, c in sub.class2 {
        if c < sub.n2 {
          sizes2[c] += 1
        }
      }
      for c1 in 0..<sub.n1 {
        for c2 in 1..<sub.n2 {
          let pos = 16 + (c1 * sub.n2 + c2) * (s1 + s2)
          if value_nonzero(sub.data, pos, sub.vf1) ||
            value_nonzero(sub.data, pos + s1, sub.vf2) {
            total += sizes1[c1].to_int64() * sizes2[c2].to_int64()
          }
        }
      }
    }
  }
  total
}
