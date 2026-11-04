///|
test "PPTX chart titles read text properties" {
  let title = pptx_parse_xml(
    "<c:title xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" " +
    "xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">" +
    "<c:txPr><a:p><a:pPr><a:defRPr sz=\"1400\"><a:solidFill>" +
    "<a:srgbClr val=\"FF0000\"/></a:solidFill></a:defRPr></a:pPr></a:p></c:txPr>" +
    "</c:title>",
  )
  assert_eq(pptx_chart_tx_size(Some(title), 10.0), 14.0)
  assert_eq(pptx_chart_tx_color(Some(title), Map([]), 0U), 0xff0000ffU)
}
