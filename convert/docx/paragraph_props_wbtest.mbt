///|
fn check_docx_ppr(
  layers : Array[String],
  expected : DocxParagraphProps,
) -> Unit raise {
  let actual = docx_default_paragraph_props()
  for layer in layers {
    actual.apply_xml(layer)
  }
  assert_eq(actual, expected)
}

///|
test "DOCX paragraph props reject unresolved border and shading" {
  let props = docx_default_paragraph_props()
  let border = try {
    props.apply_xml("<pPr><pBdr/></pPr>")
    false
  } catch {
    _ => true
  }
  assert_true(border)
  let shading = try {
    props.apply_xml("<pPr><shd/></pPr>")
    false
  } catch {
    _ => true
  }
  assert_true(shading)
}
