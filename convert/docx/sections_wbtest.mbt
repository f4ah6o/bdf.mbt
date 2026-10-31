///|
fn check_docx_sections(
  name : String,
  chunks : Array[String],
  part : String,
  expected : Array[
    (Double, Double, Double, Double, Double, Double, Double, Double, Bool, Bool),
  ],
) -> Unit raise {
  let joined = StringBuilder()
  for chunk in chunks {
    joined.write_string(chunk)
  }
  let compressed = @base64.decode(joined.to_string()[:])
  let input = @gzip.decompress(compressed[:])
  let (actual_part, sections) = docx_sections(input)
  assert_eq(actual_part, part, msg=name)
  assert_eq(sections.length(), expected.length(), msg=name)
  for i in 0..<expected.length() {
    let (
      width,
      height,
      top,
      bottom,
      left,
      right,
      header,
      footer,
      top_exact,
      bottom_exact,
    ) = expected[i]
    assert_eq(
      sections[i],
      {
        width,
        height,
        top,
        bottom,
        left,
        right,
        header,
        footer,
        top_exact,
        bottom_exact,
      },
      msg="\{name} section \{i}",
    )
  }
}

///|
test "DOCX section units" {
  assert_eq(docx_measure("1440", 0.0), 72.0)
  assert_eq(docx_measure("1in", 0.0), 72.0)
  assert_eq(docx_measure("2.54cm", 0.0), 72.0)
  assert_eq(docx_measure("invalid", 5.0), 5.0)
}
