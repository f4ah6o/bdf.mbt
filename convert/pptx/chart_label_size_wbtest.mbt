///|
test "PPTX data label text properties set the label size" {
  let chart = pptx_parse_xml(
    "<c:chart xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" " +
    "xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">" +
    "<c:dLbls><c:txPr><a:p><a:pPr><a:defRPr sz=\"1200\"/></a:pPr></a:p></c:txPr></c:dLbls>" +
    "</c:chart>",
  )
  assert_eq(pptx_chart_data_label_size(Some(chart)), 12.0)
}
