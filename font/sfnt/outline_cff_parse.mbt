///|
/// Parsed CFF charstrings and subroutines for glyph-outline drawing.
pub struct CffOutlines {
  priv charstrings : Array[BytesView]
  priv global : Array[BytesView]
  priv local : Array[Array[BytesView]]
  priv fd_select : Array[Int32]?
}

///|
fn outline_cff_index(
  data : BytesView,
  pos : Int32,
) -> (Array[BytesView], Int32)? {
  if pos < 0 || pos > data.length() - 2 {
    return None
  }
  let count = u16(data, pos)
  if count == 0 {
    return Some(([], pos + 2))
  }
  if pos + 3 > data.length() {
    return None
  }
  let size = data[pos + 2].to_int()
  if size < 1 || size > 4 {
    return None
  }
  let offsets = pos + 3
  let base = offsets + (count + 1) * size - 1
  if base >= data.length() {
    return None
  }
  let get = (i : Int32) => {
    let mut n = 0L
    for k in 0..<size {
      n = (n << 8) | data[offsets + i * size + k].to_int64()
    }
    n
  }
  let items : Array[BytesView] = []
  for i in 0..<count {
    let start = base.to_int64() + get(i)
    let end = base.to_int64() + get(i + 1)
    if start > end || end > data.length().to_int64() {
      return None
    }
    items.push(data[start.to_int():end.to_int()])
  }
  Some((items, (base.to_int64() + get(count)).to_int()))
}

///|
fn outline_cff_dict(data : BytesView) -> Map[Int32, Array[Double]] {
  let result : Map[Int32, Array[Double]] = Map([])
  let mut operands : Array[Double] = []
  let mut i = 0
  while i < data.length() {
    let byte = data[i].to_int()
    if byte <= 21 {
      let mut op = byte
      i += 1
      if byte == 12 && i < data.length() {
        op = 1200 + data[i].to_int()
        i += 1
      }
      result[op] = operands
      operands = []
    } else if byte == 28 && i + 2 < data.length() {
      operands.push(s16(data, i + 1).to_double())
      i += 3
    } else if byte == 29 && i + 4 < data.length() {
      operands.push(u32(data, i + 1).reinterpret_as_int().to_double())
      i += 5
    } else if byte == 30 {
      i += 1
      while i < data.length() {
        let b = data[i].to_int()
        i += 1
        if (b & 15) == 15 || b >> 4 == 15 {
          break
        }
      }
      operands.push(0.0)
    } else if byte >= 32 && byte <= 246 {
      operands.push((byte - 139).to_double())
      i += 1
    } else if byte >= 247 && byte <= 250 && i + 1 < data.length() {
      operands.push(
        ((byte - 247) * 256 + data[i + 1].to_int() + 108).to_double(),
      )
      i += 2
    } else if byte >= 251 && byte <= 254 && i + 1 < data.length() {
      operands.push(
        (-(byte - 251) * 256 - data[i + 1].to_int() - 108).to_double(),
      )
      i += 2
    } else {
      i += 1
    }
  }
  result
}

///|
fn outline_cff_private(
  data : BytesView,
  args : Array[Double],
) -> Array[BytesView] {
  if args.length() != 2 {
    return []
  }
  let size = args[0].to_int()
  let pos = args[1].to_int()
  if pos < 0 || size < 0 || pos > data.length() || size > data.length() - pos {
    return []
  }
  let dict = outline_cff_dict(data[pos:pos + size])
  guard dict.get(19) is Some(offsets) && offsets.length() == 1 else {
    return []
  }
  let offset = offsets[0].to_int64() + pos.to_int64()
  if offset < 0L || offset > 2147483647L {
    return []
  }
  match outline_cff_index(data, offset.to_int()) {
    Some((subrs, _)) => subrs
    None => []
  }
}

///|
fn outline_cff_fd_select(
  data : BytesView,
  pos : Int32,
  count : Int32,
) -> Array[Int32] {
  let result = [ for _ in 0..<count => 0 ]
  if pos < 0 || pos >= data.length() {
    return result
  }
  match data[pos].to_int() {
    0 =>
      if count <= data.length() - pos - 1 {
        for i in 0..<count {
          result[i] = data[pos + 1 + i].to_int()
        }
      }
    3 => {
      let ranges = u16(data, pos + 1)
      for i in 0..<ranges {
        let rec = pos + 3 + i * 3
        if rec + 5 > data.length() {
          break
        }
        let first = u16(data, rec)
        let last = u16(data, rec + 3)
        let fd = data[rec + 2].to_int()
        for glyph in first..<Int32::min(last, count) {
          result[glyph] = fd
        }
      }
    }
    _ => ()
  }
  result
}

///|
fn parse_cff_outlines(data : BytesView) -> CffOutlines? {
  if data.length() < 4 {
    return None
  }
  guard outline_cff_index(data, data[2].to_int()) is Some((_, p1)) else {
    return None
  }
  guard outline_cff_index(data, p1) is Some((tops, p2)) && tops.length() > 0 else {
    return None
  }
  guard outline_cff_index(data, p2) is Some((_, p3)) else { return None }
  guard outline_cff_index(data, p3) is Some((global, _)) else { return None }
  let top = outline_cff_dict(tops[0])
  guard top.get(17) is Some(cs) && cs.length() == 1 else { return None }
  guard outline_cff_index(data, cs[0].to_int()) is Some((charstrings, _)) &&
    charstrings.length() > 0 else {
    return None
  }
  let local : Array[Array[BytesView]] = []
  let mut fd_select = None
  match (top.get(1236), top.get(1237)) {
    (Some(fda), Some(fds)) if fda.length() == 1 && fds.length() == 1 => {
      guard outline_cff_index(data, fda[0].to_int()) is Some((dicts, _)) &&
        dicts.length() > 0 else {
        return None
      }
      for dict in dicts {
        local.push(
          outline_cff_private(
            data,
            outline_cff_dict(dict).get(18).unwrap_or([]),
          ),
        )
      }
      fd_select = Some(
        outline_cff_fd_select(data, fds[0].to_int(), charstrings.length()),
      )
    }
    _ => local.push(outline_cff_private(data, top.get(18).unwrap_or([])))
  }
  Some({ charstrings, global, local, fd_select, })
}

///|
/// Parse CFF drawing data once for use by multiple glyphs. Returns None when
/// the face is not CFF or its charstring tables cannot be read.
pub fn Font::cff_outlines(self : Font) -> CffOutlines? {
  if !self.metrics.is_cff {
    return None
  }
  parse_cff_outlines(sfnt_table(self.source, self.tables, "CFF "))
}
