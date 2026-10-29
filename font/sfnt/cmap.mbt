///|
fn parse_cmap(data : BytesView) -> Map[Int32, Int32] raise {
  let mut result : Map[Int32, Int32] = Map([])
  if data.length() < 4 {
    return result
  }
  let mut best = -1
  let budget = Ref(4 * 0x110000)
  let cached : Map[Int32, Map[Int32, Int32]?] = Map([])
  let count = u16(data, 2)
  for i in 0..<count {
    let rec = 4 + i * 8
    let platform = u16(data, rec)
    let encoding = u16(data, rec + 2)
    let off = u32(data, rec + 4)
    if off >= data.length().reinterpret_as_uint() {
      continue
    }
    let offset = off.reinterpret_as_int()
    let table = match cached.get(offset) {
      Some(value) => value
      None => {
        let value = cmap_subtable(data[offset:], budget)
        if budget.val < 0 {
          raise InvalidFont("sfnt: the cmap table maps too many characters")
        }
        cached[offset] = value
        value
      }
    }
    guard table is Some(map) else { continue }
    let score = if platform == 3 && encoding == 10 {
      3
    } else if platform == 3 && encoding == 1 {
      2
    } else if platform == 0 {
      1
    } else {
      -1
    }
    if score > best {
      best = score
      result = map
    }
  }
  result
}

///|
fn cmap_subtable(data : BytesView, budget : Ref[Int32]) -> Map[Int32, Int32]? {
  let map : Map[Int32, Int32] = Map([])
  match u16(data, 0) {
    0 => {
      budget.val -= 256
      for c in 0..<256 {
        if 6 + c >= data.length() {
          break
        }
        let g = data[6 + c].to_int()
        if g != 0 {
          map[c] = g
        }
      }
    }
    4 => {
      let seg_x2 = u16(data, 6)
      let ends = 14
      let starts = 16 + seg_x2
      let deltas = 16 + 2 * seg_x2
      let offsets = 16 + 3 * seg_x2
      for s in 0..<(seg_x2 / 2) {
        let end = u16(data, ends + s * 2)
        let start = u16(data, starts + s * 2)
        if start > end {
          continue
        }
        budget.val -= end - start + 1
        if budget.val < 0 {
          return None
        }
        let delta = u16(data, deltas + s * 2)
        let range = u16(data, offsets + s * 2)
        for c in start..<=end {
          if c == 0xffff {
            break
          }
          let glyph = if range == 0 {
            (c + delta) & 0xffff
          } else {
            let address = offsets + s * 2 + range + (c - start) * 2
            if address >= data.length() - 1 {
              continue
            }
            let raw = u16(data, address)
            if raw == 0 {
              0
            } else {
              (raw + delta) & 0xffff
            }
          }
          if glyph != 0 {
            map[c] = glyph
          }
        }
      }
    }
    6 => {
      let first = u16(data, 6)
      let count = u16(data, 8)
      budget.val -= count
      for i in 0..<count {
        let glyph = u16(data, 10 + i * 2)
        if glyph != 0 {
          map[first + i] = glyph
        }
      }
    }
    12 => {
      let declared = u32(data, 12)
      let available = if data.length() < 16 {
        0
      } else {
        (data.length() - 16) / 12
      }
      let count = if declared > available.reinterpret_as_uint() {
        available
      } else {
        declared.reinterpret_as_int()
      }
      let mut left = 0x110000
      for i in 0..<count {
        if left == 0 {
          break
        }
        let rec = 16 + i * 12
        let start = u32(data, rec)
        let end = u32(data, rec + 4)
        let glyph = u32(data, rec + 8)
        if start > 0x10ffffU || end < start {
          continue
        }
        let last = UInt32::min(end, UInt32::min(0x10ffffU, start + 0xffffU))
        let mut c = start
        while c <= last && left > 0 {
          map[c.reinterpret_as_int()] = ((glyph + c - start) & 0xffffU).reinterpret_as_int()
          left -= 1
          c += 1U
        }
      }
      budget.val -= 0x110000 - left
    }
    _ => return None
  }
  Some(map)
}
