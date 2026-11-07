///|
test "cgm detection" {
  assert_true(detect(b"\x1f\x8b\x08\x00"))
  assert_true(detect(b"\x00\x20\x00\x04BEGMF"))
  assert_false(detect(b"not a metafile"))
}

///|
test "cgm clear text is detected" {
  assert_true(cgm_is_clear_text(b"BEGMF 'shapes';"))
  assert_true(cgm_is_clear_text(b"\n  BEGMF 'shapes';"))
  assert_false(cgm_is_clear_text(b"\x00\x20\x00\x01"))
}

///|
test "cgm clear text tokens" {
  let tokens = cgm_text_tokens("BEGPIC 'a''b'; VDCEXT (0,0) (42000,29700);")
  assert_eq(tokens.length(), 15)
  assert_eq(tokens[0], Word("BEGPIC"))
  assert_eq(tokens[1], Quoted("a'b"))
  assert_eq(tokens[2], Delim(';'))
  assert_eq(tokens[3], Word("VDCEXT"))
  assert_eq(tokens[4], Delim('('))
  assert_eq(tokens[5], Number(0.0))
  assert_eq(tokens[6], Delim(','))
  assert_eq(tokens[7], Number(0.0))
  assert_eq(tokens[8], Delim(')'))
  assert_eq(tokens[9], Delim('('))
}

///|
test "cgm clear text elements" {
  let elements = read_clear_text_elements(
    b"BEGMF 'x'; SCALEMODE METRIC 0.01; VDCEXT (0,0) (42000,29700); TEXTALIGN 1 2; TEXT 100 200 0 'hi'; ENDMF;",
  )
  let classes = elements.map(element => (element.class, element.id))
  assert_eq(classes, [(0, 1), (2, 1), (2, 6), (5, 18), (4, 4), (0, 2)])
  // SCALEMODE METRIC 0.01: the mode is an integer, the metric a real.
  let scale = elements[1].data
  assert_eq(scale.length(), 4)
  assert_true((cgm_float(scale, 0) - 0.01).abs() < 1.0e-6)
  // VDCEXT: four 32-bit integers.
  assert_eq(elements[2].data.length(), 16)
  assert_eq(cgm_u32(elements[2].data, 8), 42000)
  // TEXT: the origin, the attribute list and the string.
  let text = elements[4].data
  assert_eq(cgm_u32(text, 0), 100)
  assert_eq(cgm_u32(text, 4), 200)
  assert_eq(text[12].to_int(), 2)
  assert_eq(@utf8.decode_lossy(text[13:15].to_owned()), "hi")
}

///|
test "cgm colour table entries" {
  // Bare values: white, black, then a direct RGB entry.
  assert_eq(cgm_direct_color(0xffffff, 8), 0xffffffffU)
  assert_eq(cgm_direct_color(0, 8), 0x000000ffU)
  assert_eq(cgm_direct_color(0xff0000, 8), 0xff0000ffU)
  assert_eq(cgm_direct_color(0x808080, 8), 0x808080ffU)
  // A four-bit direct colour is scaled to 8 bits.
  assert_eq(cgm_direct_color(0xf00, 4), 0xff0000ffU)
}
