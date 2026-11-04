///|
test "PPTX data label bold flag is parsed" {
  let chart = pptx_parse_xml(
    "<c:chart xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" " +
    "xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">" +
    "<c:dLbls><c:txPr><a:p><a:pPr><a:defRPr b=\"1\"/></a:pPr></a:p></c:txPr></c:dLbls>" +
    "</c:chart>",
  )
  assert_true(pptx_chart_data_label_bold(Some(chart)))
}
