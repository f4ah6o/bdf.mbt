///|
test "shape theme colors and opacity match DrawingML" {
  let theme : Map[Int32, XlsxRgb] = Map([
    (0, xlsx_rgb_from_uint(0xabcdefU)),
    (4, xlsx_rgb_from_uint(0x123456U)),
  ])
  for
    (name, expected) in [
      ("accent1", Some(0x123456ffU)),
      ("bg1", Some(0xabcdefffU)),
      ("phClr", Some(0x000000ffU)),
      ("unknown", None),
    ] {
    let reader = @xml.NamespaceReader::from_string(
      "<schemeClr val=\"" + name + "\"/>",
    )
    let element = match reader.read_event().kind {
      Empty(element) => element
      _ => fail("expected a color element")
    }
    assert_eq(xlsx_simple_shape_color(element, theme, Map([])), expected)
  }
  let reader = @xml.NamespaceReader::from_string("<schemeClr val=\"accent1\"/>")
  let element = match reader.read_event().kind {
    Empty(element) => element
    _ => fail("expected a color element")
  }
  assert_eq(
    xlsx_simple_shape_color(element, theme, Map([(4, 128.0 / 255.0)])),
    Some(0x12345680U),
  )
  let reader = @xml.NamespaceReader::from_string("<alpha val=\"50000\"/>")
  let element = match reader.read_event().kind {
    Empty(element) => element
    _ => fail("expected an alpha element")
  }
  assert_eq(xlsx_simple_shape_alpha(element, 0x123456ffU), Some(0x12345680U))
}

///|
test "shape system colors use the upstream fallback" {
  for
    (source, expected) in [
      ("<sysClr val=\"window\"/>", Some(0xffffffffU)),
      ("<sysClr val=\"menu\" lastClr=\"00FF22\"/>", Some(0x00ff22ffU)),
      ("<sysClr val=\"other\" lastClr=\"invalid\"/>", Some(0x000000ffU)),
      ("<sysClr lastClr=\"aabbcc\"/>", Some(0xaabbccffU)),
      ("<sysClr val=\"menu\" extra=\"1\"/>", None),
    ] {
    let reader = @xml.NamespaceReader::from_string(source)
    let element = match reader.read_event().kind {
      Empty(element) => element
      _ => fail("expected a system color element")
    }
    assert_eq(xlsx_simple_shape_color(element, Map([]), Map([])), expected)
  }
}
