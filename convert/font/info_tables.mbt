///|
/// Count cmap format 14 variation sequences. The boolean reports that the
/// upstream range-work limit was reached and the count is a lower bound.
pub fn variation_sequences(data : Bytes) -> (Int64, Bool) {
  let n = be16(data[:], 2)
  for i in 0..<n {
    let rec = 4 + i * 8
    if be16(data[:], rec) != 0 || be16(data[:], rec + 2) != 5 {
      continue
    }
    let raw = be32(data[:], rec + 4)
    let pos = if raw > data.length().reinterpret_as_uint() {
      data.length()
    } else {
      raw.reinterpret_as_int()
    }
    let st = data[pos:]
    if be16(st, 0) != 14 {
      continue
    }
    let available = Int32::max(st.length() - 10, 0) / 11
    let declared = be32(st, 6)
    let selectors = if declared > available.reinterpret_as_uint() {
      available
    } else {
      declared.reinterpret_as_int()
    }
    let defaults : Map[UInt32, Int64] = Map([])
    let mut left = 4194304
    let mut count = 0L
    for j in 0..<selectors {
      let r = 10 + j * 11
      let d = be32(st, r + 3)
      if d > 0U && d.to_int64() + 4L <= st.length().to_int64() {
        let sum = match defaults.get(d) {
          Some(v) => v
          None => {
            let off = d.reinterpret_as_int()
            let n = be32(st, off)
            let available = (st.length() - off - 4) / 4
            let ranges = if n > available.reinterpret_as_uint() {
              available
            } else {
              n.reinterpret_as_int()
            }
            left -= ranges
            if left < 0 {
              return (count, true)
            }
            let mut total = 0L
            for k in 0..<ranges {
              total += st[off + 4 + k * 4 + 3].to_int64() + 1L
            }
            defaults[d] = total
            total
          }
        }
        count += sum
      }
      let u = be32(st, r + 7)
      if u > 0U && u.to_int64() + 4L <= st.length().to_int64() {
        count += UInt32::min(be32(st, u.reinterpret_as_int()), 1048576U).to_int64()
      }
    }
    return (count, false)
  }
  (0L, false)
}

///|
/// Read design and supported language strings from an OpenType meta table.
pub fn metadata_languages(data : Bytes) -> (String, String) {
  if data.length() < 16 || be32(data[:], 0) != 1U {
    return ("", "")
  }
  let declared = be32(data[:], 12)
  let available = (data.length() - 16) / 12
  let n = if declared > available.reinterpret_as_uint() {
    available
  } else {
    declared.reinterpret_as_int()
  }
  let mut design = ""
  let mut supported = ""
  for i in 0..<n {
    let rec = 16 + i * 12
    let off = be32(data[:], rec + 4)
    let len = be32(data[:], rec + 8)
    if off.to_int64() + len.to_int64() > data.length().to_int64() {
      continue
    }
    let start = off.reinterpret_as_int()
    let value = @utf8.decode_lossy(data[start:start + len.reinterpret_as_int()]).replace(
      old=",",
      new=", ",
    )
    let tag = data[rec:rec + 4]
    if tag == b"dlng"[:] {
      design = value
    } else if tag == b"slng"[:] {
      supported = value
    }
  }
  (design, supported)
}

///|
fn info_number(n : Int64) -> String {
  let s = n.to_string()
  let chars : Array[Char] = [ for c in s => c ]
  let out = StringBuilder()
  for i in 0..<chars.length() {
    if i > 0 && (chars.length() - i) % 3 == 0 {
      out.write_char(',')
    }
    out.write_char(chars[i])
  }
  out.to_string()
}

///|
fn bitmap_strikes(data : Bytes) -> String {
  if data.length() < 8 {
    return ""
  }
  let available = (data.length() - 8) / 48
  let declared = be32(data[:], 4)
  let n = if declared > available.reinterpret_as_uint() {
    available
  } else {
    declared.reinterpret_as_int()
  }
  let out = StringBuilder()
  for i in 0..<n {
    if i > 0 {
      out.write_string(", ")
    }
    out.write_string(data[8 + i * 48 + 44].to_int().to_string())
  }
  out.to_string()
}

///|
/// Describe supported color glyph tables in the upstream overview's wording.
pub fn color_formats(
  colr : Bytes,
  cpal : Bytes,
  sbix : Bytes,
  cblc : Bytes,
  svg : Bytes,
) -> String {
  let parts : Array[String] = []
  if colr.length() >= 14 {
    let mut count = be16(colr[:], 2).to_int64()
    let version = if be16(colr[:], 0) >= 1 && colr.length() >= 34 {
      let off = be32(colr[:], 14)
      if off > 0U && off.to_int64() + 4L <= colr.length().to_int64() {
        count = Int64::max(
          count,
          be32(colr[:], off.reinterpret_as_int()).to_int64(),
        )
      }
      "COLRv1"
    } else {
      "COLRv0"
    }
    parts.push(version + " (" + info_number(count) + " glyphs)")
  }
  if cpal.length() >= 12 {
    parts.push(
      "CPAL (" +
      be16(cpal[:], 4).to_string() +
      " palettes of " +
      be16(cpal[:], 2).to_string() +
      " colors)",
    )
  }
  if sbix.length() >= 8 {
    let sizes : Array[String] = []
    let available = (sbix.length() - 8) / 4
    let declared = be32(sbix[:], 4)
    let n = if declared > available.reinterpret_as_uint() {
      available
    } else {
      declared.reinterpret_as_int()
    }
    for i in 0..<n {
      let off = be32(sbix[:], 8 + i * 4)
      if off.to_int64() + 2L <= sbix.length().to_int64() {
        sizes.push(be16(sbix[:], off.reinterpret_as_int()).to_string())
      }
    }
    parts.push("sbix bitmaps (" + sizes.join(", ") + " ppem)")
  }
  let strikes = bitmap_strikes(cblc)
  if strikes != "" {
    parts.push("CBDT bitmaps (" + strikes + " ppem)")
  }
  if svg.length() >= 10 {
    let off = be32(svg[:], 2)
    if off.to_int64() + 2L <= svg.length().to_int64() {
      parts.push(
        "SVG (" +
        info_number(be16(svg[:], off.reinterpret_as_int()).to_int64()) +
        " documents)",
      )
    }
  }
  parts.join(", ")
}

///|
/// Decode up to 64 CPAL palettes with up to 256 RGBA colors each.
pub fn color_palettes(data : Bytes) -> Array[Array[UInt32]] {
  let output : Array[Array[UInt32]] = []
  if data.length() < 12 {
    return output
  }
  let entries = be16(data[:], 2)
  let n = Int32::min(be16(data[:], 4), 64)
  let records = be16(data[:], 6)
  let off = be32(data[:], 8).to_int64()
  for i in 0..<n {
    let first = be16(data[:], 12 + i * 2)
    let pal : Array[UInt32] = []
    for k in 0..<Int32::min(entries, 256) {
      let p = off + (first + k).to_int64() * 4L
      if first + k >= records || p + 4L > data.length().to_int64() {
        break
      }
      let p = p.to_int()
      pal.push(
        (data[p + 2].to_uint() << 24) |
        (data[p + 1].to_uint() << 16) |
        (data[p].to_uint() << 8) |
        data[p + 3].to_uint(),
      )
    }
    output.push(pal)
  }
  output
}
