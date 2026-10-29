///|
fn default_head(units : Int32) -> Array[Byte] {
  let result = Bytes::make(54, 0).to_array()
  put32(result, 0, 0x00010000U)
  put32(result, 4, 0x00010000U)
  put32(result, 12, 0x5f0f3cf5U)
  put16(result, 16, 0x000b)
  put16(result, 18, units)
  put16(result, 38, -(units / 5))
  put16(result, 40, units)
  put16(result, 42, units)
  put16(result, 46, 8)
  put16(result, 48, 2)
  result
}

///|
fn default_hhea(
  ascent : Int32,
  descent : Int32,
  units : Int32,
  count : Int32,
) -> Array[Byte] {
  let result = Bytes::make(36, 0).to_array()
  put32(result, 0, 0x00010000U)
  put16(result, 4, ascent)
  put16(result, 6, descent)
  put16(result, 10, units)
  put16(result, 18, 1)
  put16(result, 34, count)
  result
}

///|
fn default_hmtx(
  font : Font,
  count : Int32,
  advances : Array[Int32],
) -> Array[Byte] {
  let result : Array[Byte] = []
  for glyph in 0..<count {
    let advance = if glyph < advances.length() {
      advances[glyph]
    } else {
      font.metrics.units_per_em / 2
    }
    push16(result, advance)
    push16(result, 0)
  }
  result
}

///|
fn default_maxp(count : Int32, cff : Bool) -> Array[Byte] {
  let result = Bytes::make(if cff { 6 } else { 32 }, 0).to_array()
  put32(result, 0, if cff { 0x00005000U } else { 0x00010000U })
  put16(result, 4, count)
  if !cff {
    put16(result, 6, 512)
    put16(result, 8, 64)
    put16(result, 10, 512)
    put16(result, 12, 64)
    put16(result, 14, 2)
    for offset in [16, 18, 20, 22, 24, 26, 28, 30] {
      put16(result, offset, 64)
    }
  }
  result
}

///|
fn rebuild_ascent_descent(font : Font) -> (Int32, Int32) {
  let hhea = sfnt_table(font.source, font.tables, "hhea")
  let ascent = if hhea.length() >= 36 { s16(hhea, 4) } else { 0 }
  let descent = if hhea.length() >= 36 { s16(hhea, 6) } else { 0 }
  if ascent == 0 && descent == 0 {
    let units = font.metrics.units_per_em
    (
      ((units * 8 / 10 + 32768) & 0xffff) - 32768,
      ((-(units * 2 / 10) + 32768) & 0xffff) - 32768,
    )
  } else {
    (ascent, descent)
  }
}
