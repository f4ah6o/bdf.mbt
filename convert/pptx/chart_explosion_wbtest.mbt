///|
test "PPTX pie data point explosions are parsed" {
  let series = pptx_parse_xml(
    "<c:ser xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\">" +
    "<c:dPt><c:idx val=\"1\"/><c:explosion val=\"50\"/></c:dPt>" +
    "<c:dPt><c:idx val=\"0\"/><c:explosion val=\"25\"/></c:dPt></c:ser>",
  )
  let explosions = pptx_chart_explosions(series)
  assert_eq(explosions.length(), 2)
  assert_eq(explosions[0], 25.0)
  assert_eq(explosions[1], 50.0)
}
