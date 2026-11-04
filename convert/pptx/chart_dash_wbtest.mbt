///|
test "PPTX chart series dash style is parsed" {
  let series = pptx_parse_xml(
    "<c:ser xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" " +
    "xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">" +
    "<c:spPr><a:ln w=\"25400\"><a:prstDash val=\"dash\"/></a:ln></c:spPr>" +
    "</c:ser>",
  )
  assert_eq(pptx_series_dash(series), "dash")
  assert_eq(pptx_series_line_width(series), 2.0)
}
