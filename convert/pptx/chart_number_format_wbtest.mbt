///|
test "PPTX chart number formats handle decimals, groups and percent" {
  assert_eq(pptx_chart_format_number(1.25, "0.0"), "1.3")
  assert_eq(pptx_chart_format_number(1234.0, "#,##0"), "1,234")
  assert_eq(pptx_chart_format_number(0.5, "0%"), "50%")
}
