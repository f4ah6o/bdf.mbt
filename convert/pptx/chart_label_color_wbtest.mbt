///|
test "PPTX data label text properties set the label colour" {
  let chart = pptx_parse_xml(
    "<c:chart xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" " +
    "xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">" +
    "<c:dLbls><c:txPr><a:p><a:pPr><a:defRPr><a:solidFill>" +
    "<a:srgbClr val=\"FF0000\"/></a:solidFill></a:defRPr></a:pPr></a:p></c:txPr></c:dLbls>" +
    "</c:chart>",
  )
  assert_eq(pptx_chart_data_label_color(Some(chart), Map([])), 0xff0000ffU)
}
