///|
test "row height accounts for a taller bold header face" {
  let rows = [
    [{ text: "Header", number: false, }],
    [{ text: "Value", number: false, }],
  ]
  let metrics = (_ : Char, bold : Bool) => {
    if bold {
      (18.0, 4.0)
    } else {
      (9.0, 3.0)
    }
  }
  let style_height = (bold : Bool) => if bold { 22.0 } else { 12.0 }
  let heights = fit_rows(
    rows,
    [48.0F],
    header_rows=1,
    metrics~,
    default_line_height=12.0,
    style_line_height=Some(style_height),
  )
  assert_true(heights[0] > heights[1])
}
