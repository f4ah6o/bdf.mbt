///|
test "PPTX chart data point colors are parsed" {
  let series = pptx_parse_xml(
    "<c:ser xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" " +
    "xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">" +
    "<c:dPt><c:idx val=\"1\"/><c:spPr><a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill></c:spPr></c:dPt>" +
    "</c:ser>",
  )
  let colors = pptx_chart_point_colors(series, Map([]))
  assert_eq(colors.length(), 2)
  assert_eq(colors[0], 0U)
  assert_eq(colors[1], 0xff0000ffU)
}
