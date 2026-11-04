///|
test "PPTX pie percentages use the label number format" {
  assert_eq(pptx_chart_percent_text(1.0, 4.0, "0.0%"), "25.0%")
  assert_eq(pptx_chart_percent_text(1.0, 3.0, ""), "33%")
}
