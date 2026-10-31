///|
fn check_pdf_vertical_font(
  data : Bytes,
  encoded : Bytes,
  expected : Array[(Int64, Int32, Int64, Double, Double, Double, Double)],
) -> Unit raise {
  let file = pdf_open_file(data)
  let (pages, _) = file.page_leaves()
  let resources = file.page_deref(pages[0].attrs.resources)
  let fonts = file.page_deref(pdf_dict_get(resources, b"Font"))
  let object = pdf_dict_get(fonts, b"F1").unwrap()
  let font = file.simple_font(object)
  assert_true(
    match font.composite_map {
      Some(map) => map.vertical
      None => false
    },
  )
  let glyphs = font.decode(encoded)
  assert_eq(glyphs.length(), expected.length())
  for i in 0..<glyphs.length() {
    let glyph = glyphs[i]
    let (w, x, y) = font.glyph_vertical_metrics(glyph)
    assert_eq(
      (glyph.code, glyph.size, glyph.cid, font.glyph_width(glyph), w, x, y),
      expected[i],
      msg="glyph \{i}",
    )
  }
}
