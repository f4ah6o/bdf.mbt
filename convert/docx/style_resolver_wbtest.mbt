///|
fn check_docx_style(
  xml : String,
  ppr_xml : String,
  rpr_xml : String,
  expected_id : String,
  expected_p : (
    String,
    Double,
    Double,
    Double,
    Double,
    Double,
    Double,
    String,
    Bool,
    Bool,
    Int32,
    Array[(Double, String, String)],
  ),
  expected_r : DocxRunProps,
) -> Unit raise {
  let sheet = docx_styles_from_xml(xml)
  let (id, p) = sheet.resolve_paragraph(Some(docx_text_xml(ppr_xml)))
  assert_eq(id, expected_id)
  assert_eq(
    (
      p.alignment,
      p.left,
      p.right,
      p.first,
      p.before,
      p.after,
      p.line,
      p.line_rule,
      p.keep_next,
      p.snap_to_grid,
      p.outline,
      p.tabs.map(fn(tab) { (tab.position, tab.alignment, tab.leader) }),
    ),
    expected_p,
  )
  let run = sheet.resolve_run(id, Some(docx_text_xml(rpr_xml)))
  assert_eq(run, expected_r)
}

///|
test "DOCX style run copies isolate mutable arrays" {
  let props = docx_default_run_props()
  props.fonts[0] = "First"
  props.themes[1] = "theme"
  props.languages[2] = "ar"
  let copied = props.copy()
  copied.fonts[0] = "Other"
  copied.themes[1] = "other-theme"
  copied.languages[2] = "he"
  assert_eq(props.fonts[0], "First")
  assert_eq(props.themes[1], "theme")
  assert_eq(props.languages[2], "ar")
}

///|
test "DOCX style resolver rejects unsupported applied properties" {
  let sheet = docx_styles_from_xml(
    "<styles><style type=\"paragraph\" styleId=\"bad\"><rPr><color val=\"FF0000\"/></rPr></style><style type=\"paragraph\" styleId=\"num\"><pPr><numPr/></pPr></style><style type=\"paragraph\" styleId=\"good\" default=\"1\"/></styles>",
  )
  let good = sheet.resolve_paragraph(None)
  ignore(sheet.resolve_run(good.0, None))
  let bad = sheet.resolve_paragraph(
    Some(docx_text_xml("<pPr><pStyle val=\"bad\"/></pPr>")),
  )
  let reject_color = try {
    ignore(sheet.resolve_run(bad.0, None))
    false
  } catch {
    _ => true
  }
  assert_true(reject_color)
  let reject_numbering = try {
    ignore(
      sheet.resolve_paragraph(
        Some(docx_text_xml("<pPr><pStyle val=\"num\"/></pPr>")),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(reject_numbering)
}
