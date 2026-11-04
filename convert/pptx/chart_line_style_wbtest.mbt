///|
test "PPTX chart series line width and markers are parsed" {
  let series = pptx_parse_xml(
    "<c:ser xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" " +
    "xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">" +
    "<c:spPr><a:ln w=\"63500\"/></c:spPr>" +
    "<c:marker><c:symbol val=\"circle\"/><c:size val=\"8\"/></c:marker>" +
    "</c:ser>",
  )
  assert_eq(pptx_series_line_width(series), 5.0)
  let (symbol, size) = pptx_series_marker(series)
  assert_eq(symbol, "circle")
  assert_eq(size, 8.0)
}
