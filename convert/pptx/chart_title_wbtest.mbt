///|
test "PPTX chart uses an explicit title" {
  let xml = "<c:chartSpace xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" " +
    "xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">" +
    "<c:chart><c:title><c:tx><c:rich><a:p><a:r><a:t>Quarterly</a:t></a:r></a:p>" +
    "</c:rich></c:tx></c:title></c:chart></c:chartSpace>"
  let root = pptx_parse_xml(xml) catch { _ => return }
  let chart = pptx_child(Some(root), "chart")
  assert_eq(pptx_chart_title_text(chart), "Quarterly")
}
