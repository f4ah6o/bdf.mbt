///|
test "glyph programs map the last glyphs away from noncharacters" {
  let tables : Map[String, Array[Byte]] = { "maxp": [0, 1, 0, 0, 255, 255] }
  let source = build_tables(tables, false)
  let font = parse(source)
  let generated = parse(font.glyph_program())
  assert_eq(generated.glyph(0xffffd), Some(65533))
  assert_eq(generated.glyph(0xffffe), None)
  assert_eq(generated.glyph(0x100000), Some(65534))
}

///|
test "specimen pruning retains glyph IDs and shared advances" {
  let head = Bytes::make(54, 0).to_array()
  let hhea = Bytes::make(36, 0).to_array()
  put16(hhea, 34, 2)
  let tables : Map[String, Array[Byte]] = {
    "head": head,
    "hhea": hhea,
    "hmtx": [0, 5, 0, 1, 0, 9, 0, 2, 0, 3],
    "maxp": [0, 1, 0, 0, 0, 3],
    "glyf": Bytes::make(30, 0).to_array(),
    "loca": [0, 0, 0, 5, 0, 10, 0, 15],
  }
  let font = parse(build_tables(tables, false))
  let program = font.specimen_pruned_truetype([2], 100L).unwrap()
  let pruned = parse(program)
  let loca = sfnt_table(pruned.source, pruned.tables, "loca")
  assert_eq(u16(loca, 0), 0)
  assert_eq(u16(loca, 2), 6)
  assert_eq(u16(loca, 4), 6)
  assert_eq(u16(loca, 6), 12)
  let hmtx = sfnt_table(pruned.source, pruned.tables, "hmtx")
  assert_eq(hmtx.to_owned(), b"\x00\x05\x00\x01\x00\x09\x00\x00\x00\x03")
}
