///|
fn check_docx_run_props(
  layers : Array[String],
  expected : DocxRunProps,
) -> Unit raise {
  let actual = docx_default_run_props()
  for layer in layers {
    actual.apply_xml(layer)
  }
  assert_eq(actual, expected)
}

///|
test "DOCX run properties reject unresolved features" {
  for
    xml in [
      "<rPr><u color=\"FF0000\"/></rPr>", "<rPr><eastAsianLayout combine=\"1\"/></rPr>",
    ] {
    let props = docx_default_run_props()
    let rejected = try {
      props.apply_xml(xml)
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg=xml)
  }
}
