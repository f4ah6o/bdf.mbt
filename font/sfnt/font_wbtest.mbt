///|
test "SFNT and TTC headers are checked before reading table records" {
  let short = try {
    ignore(parse(b"\x00\x01"))
    false
  } catch {
    InvalidFont(_) => true
    _ => false
  }
  assert_true(short)
  let invalid = try {
    ignore(parse(b"123456789012"))
    false
  } catch {
    InvalidFont(_) => true
    _ => false
  }
  assert_true(invalid)
  let plain : Bytes = b"\x00\x01\x00\x00\xff\xff\x00\x00\x00\x00\x00\x00"
  let face = parse(plain)
  assert_eq(face.metrics.units_per_em, 1000)
  assert_eq(face.metrics.glyph_count, 0)
  assert_eq(face.metrics.ascent, 0.9)
  assert_eq(face.metrics.descent, 0.3)
  assert_eq(face.advance_units(0), 500)
  let bad_index = try {
    ignore(parse(plain, index=1))
    false
  } catch {
    InvalidFont(_) => true
    _ => false
  }
  assert_true(bad_index)
  let collection : Bytes = b"ttcf\x00\x01\x00\x00\x00\x00\x00\x01\x00\x00\x00\x10\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
  assert_eq(face_count(collection), 1)
  assert_eq(parse(collection).metrics.units_per_em, 1000)
  let bad_collection = try {
    ignore(parse(collection[:12].to_owned()))
    false
  } catch {
    InvalidFont(_) => true
    _ => false
  }
  assert_true(bad_collection)
}

///|
test "cmap formats and limits reject oversized maps" {
  let format6 : Bytes = b"\x00\x06\x00\x10\x00\x00\x00\x41\x00\x03\x00\x05\x00\x00\x00\x09"
  let budget = Ref(1000)
  let map = cmap_subtable(format6[:], budget).unwrap()
  assert_eq(map[65], 5)
  assert_eq(map.get(66), None)
  assert_eq(map[67], 9)
  assert_eq(budget.val, 997)
  let format4 : Bytes = b"\x00\x04\x00\x20\x00\x00\x00\x04\x00\x00\x00\x00\x00\x00\x00\x43\xff\xff\x00\x00\x00\x41\xff\xff\xff\xc2\x00\x01\x00\x00\x00\x00"
  let tiny = Ref(2)
  assert_true(cmap_subtable(format4[:], tiny) is None)
  assert_true(tiny.val < 0)
}

///|
test "font names decode UTF-16 pairs and malformed surrogates" {
  let raw : Bytes = b"\x00\x41\xd8\x3d\xde\x00\xd8\x00\x00\x42\xdc\x00\x00"
  assert_eq(decode_name_utf16(raw[:]), "A😀\u{fffd}B\u{fffd}")
  assert_eq(trim_name(" \u{3000}Family Name\u{3000} "), "Family Name")
}

///|
test "format 12 maps supplementary code points" {
  let data : Bytes = b"\x00\x0c\x00\x00\x00\x00\x00\x1c\x00\x00\x00\x00\x00\x00\x00\x01\x00\x01\xf6\x00\x00\x01\xf6\x02\x00\x00\x00\x09"
  let map = cmap_subtable(data[:], Ref(100)).unwrap()
  assert_eq(map[0x1f600], 9)
  assert_eq(map[0x1f602], 11)
  assert_eq(map.get(0x1f603), None)
}

///|
test "whole canvas font has corrected checksum and synthesized metrics" {
  let source = Bytes::make(90, 0).to_array()
  put16(source, 18, 1000)
  put16(source, 58, 800)
  put16(source, 60, -200)
  let data = Bytes::from_array(source)
  let face : Font = {
    metrics: {
      units_per_em: 1000,
      glyph_count: 0,
      is_cff: false,
      ascent: 0.8,
      descent: 0.2,
      underline_position: -0.1,
      underline_thickness: 0.05,
      cap_height: 0.7,
      embeddable: true,
      subsettable: true,
    },
    info: {
      family: "Test",
      style: "Regular",
      weight: 400,
      italic: false,
      monospace: false,
      has_math: false,
    },
    cmap: Map([]),
    advances: [],
    source: data,
    tables: { "head": (0, 54), "hhea": (54, 36) },
  }
  let result = face.canvas_program()
  assert_eq(checksum(result.to_array()), 0xb1b0afbaU)
  let decoded = parse(result)
  assert_eq(decoded.metrics.units_per_em, 1000)
  assert_eq(decoded.metrics.ascent, 0.8)
  assert_eq(decoded.metrics.descent, 0.2)
  assert_eq(u32(sfnt_table(result, decoded.tables, "post"), 0), 0x00030000U)
  assert_eq(u16(sfnt_table(result, decoded.tables, "OS/2"), 8), 4)
  assert_eq(data, Bytes::from_array(source))
}
