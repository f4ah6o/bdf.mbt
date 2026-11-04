///|
test "XLSX shape text wraps to the shape width" {
  let body = xlsx_draw_parse(
    "<txBody><p><r><rPr sz=\"1200\"/><t>word word word word word word word word word</t></r></p></txBody>",
  )
  let lines = xlsx_draw_shape_text(Some(body), 60.0, [])
  assert_eq(lines.length() > 1, true)
  let mut text = ""
  for line in lines {
    for run in line.runs {
      text += run.text
      text += " "
    }
  }
  assert_eq(text.contains("word"), true)
}
