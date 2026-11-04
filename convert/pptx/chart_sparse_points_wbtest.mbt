///|
test "PPTX chart caches keep sparse point indices" {
  let series = pptx_parse_xml(
    "<c:ser xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\">" +
    "<c:cat><c:strRef><c:strCache><c:pt idx=\"0\"><c:v>A</c:v></c:pt>" +
    "<c:pt idx=\"2\"><c:v>C</c:v></c:pt></c:strCache></c:strRef></c:cat>" +
    "<c:val><c:numRef><c:numCache><c:pt idx=\"0\"><c:v>1</c:v></c:pt>" +
    "<c:pt idx=\"2\"><c:v>3</c:v></c:pt></c:numCache></c:numRef></c:val></c:ser>",
  )
  let categories = pptx_chart_values(Some(series), "cat")
  let values = pptx_chart_values(Some(series), "val")
  assert_eq(categories.length(), 3)
  assert_eq(categories[1], "")
  assert_eq(categories[2], "C")
  assert_eq(values.length(), 3)
  assert_eq(values[1], "")
  assert_eq(values[2], "3")
}
