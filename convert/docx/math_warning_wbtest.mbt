///|
// The MATH-table warning follows the formulas the converter parses and draws:
// the body, table cells (including nested tables), headers and footers. A
// document without a formula must not carry it, and it must appear once
// whichever views are made.

///|
const DOCX_TEST_MATH_WARNING : String = "no font with a MATH table (such as STIX Two Math or Cambria Math) is available; formulas are laid out with the text font"

///|
const DOCX_TEST_NO_FONT_WARNING : String = "no fonts found; text is laid out with estimated metrics and not embedded"

///|
fn docx_test_formula() -> String {
  "<m:oMath><m:r><m:t>x</m:t></m:r></m:oMath>"
}

///|
fn docx_test_math_warning_count(warnings : Array[String]) -> Int {
  let mut count = 0
  for warning in warnings {
    if warning == DOCX_TEST_MATH_WARNING {
      count += 1
    }
  }
  count
}

///|
fn docx_test_table_with(content : String) -> String {
  "<w:tbl><w:tblGrid><w:gridCol w:w=\"3000\"/></w:tblGrid>" +
  "<w:tr><w:tc><w:p>" +
  content +
  "</w:p></w:tc></w:tr></w:tbl>"
}

///|
fn docx_test_nested_table_with(content : String) -> String {
  "<w:tbl><w:tblGrid><w:gridCol w:w=\"6000\"/></w:tblGrid>" +
  "<w:tr><w:tc><w:p><w:r><w:t>Outer</w:t></w:r></w:p>" +
  docx_test_table_with(content) +
  "</w:tc></w:tr></w:tbl>"
}

///|
fn docx_test_footer(root : String) -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<w:ftr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"" +
  " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"" +
  " xmlns:m=\"http://schemas.openxmlformats.org/officeDocument/2006/math\">" +
  root +
  "</w:ftr>"
}

///|
fn docx_test_story_document(
  body : String,
  header? : String,
  footer? : String,
) -> Bytes {
  let mut section = "<w:sectPr>"
  let mut rels = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
  let entries : Array[(String, Bytes)] = []
  match header {
    Some(root) => {
      section = section + "<w:headerReference w:type=\"default\" r:id=\"rIdH\"/>"
      rels = rels +
        "<Relationship Id=\"rIdH\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/header\" Target=\"header1.xml\"/>"
      entries.push(("word/header1.xml", @utf8.encode(docx_test_header(root))))
    }
    None => ()
  }
  match footer {
    Some(root) => {
      section = section + "<w:footerReference w:type=\"default\" r:id=\"rIdF\"/>"
      rels = rels +
        "<Relationship Id=\"rIdF\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer\" Target=\"footer1.xml\"/>"
      entries.push(("word/footer1.xml", @utf8.encode(docx_test_footer(root))))
    }
    None => ()
  }
  section = section +
    "<w:pgSz w:w=\"12240\" w:h=\"15840\"/>" +
    "<w:pgMar w:top=\"1440\" w:right=\"1440\" w:bottom=\"1440\" w:left=\"1440\" w:header=\"720\" w:footer=\"720\"/></w:sectPr>"
  rels = rels + "</Relationships>"
  entries.push(("word/_rels/document.xml.rels", @utf8.encode(rels)))
  docx_test_docx(body, section, entries)
}

///|
test "DOCX document text records a formula in every parsed location" {
  let formula = docx_test_formula()
  let body = "<w:p><w:r><w:t>Body</w:t></w:r></w:p>"
  let cases : Array[(String, Bytes)] = [
    ("body", docx_test_docx("<w:p>" + formula + "</w:p>", DOCX_TEST_SECTION, [])),
    (
      "table cell",
      docx_test_docx(docx_test_table_with(formula), DOCX_TEST_SECTION, []),
    ),
    (
      "nested table cell",
      docx_test_docx(docx_test_nested_table_with(formula), DOCX_TEST_SECTION, []),
    ),
    (
      "header",
      docx_test_story_document(body, header="<w:p>" + formula + "</w:p>"),
    ),
    (
      "table in a header",
      docx_test_story_document(body, header=docx_test_table_with(formula)),
    ),
    (
      "footer",
      docx_test_story_document(body, footer="<w:p>" + formula + "</w:p>"),
    ),
  ]
  for entry in cases {
    let (label, data) = entry
    let document = docx_document_text(data)
    assert_true(document.has_math, msg=label)
  }
}

///|
test "DOCX document text leaves the formula flag clear without a formula" {
  let body = "<w:p><w:r><w:t>Body</w:t></w:r></w:p>"
  let cases : Array[(String, Bytes)] = [
    ("body", docx_test_docx(body, DOCX_TEST_SECTION, [])),
    (
      "table cell",
      docx_test_docx(
        docx_test_table_with("<w:r><w:t>x</w:t></w:r>"), DOCX_TEST_SECTION, [],
      ),
    ),
    (
      "nested table cell",
      docx_test_docx(
        docx_test_nested_table_with("<w:r><w:t>x</w:t></w:r>"),
        DOCX_TEST_SECTION,
        [],
      ),
    ),
    (
      "header",
      docx_test_story_document(body, header="<w:p><w:r><w:t>H</w:t></w:r></w:p>"),
    ),
    (
      "footer",
      docx_test_story_document(body, footer="<w:p><w:r><w:t>F</w:t></w:r></w:p>"),
    ),
  ]
  for entry in cases {
    let (label, data) = entry
    let document = docx_document_text(data)
    assert_false(document.has_math, msg=label)
  }
}

///|
test "DOCX formula in a table cell warns once in every view" {
  let data = docx_test_docx(
    docx_test_table_with(docx_test_formula()), DOCX_TEST_SECTION, [],
  )
  for views in ["pages", "scroll", "both"] {
    let result = convert(data, views=views)
    assert_eq(
      docx_test_math_warning_count(result.warnings), 1, msg="views " + views,
    )
    assert_eq(result.warnings.length(), 2, msg="views " + views)
  }
  let result = convert(data, views="pages")
  let text = docx_test_commands_text(
    docx_test_page_commands(result, "pages", 0, "body"),
  )
  assert_true(text.contains("x"), msg="table formula is drawn")
}

///|
test "DOCX formula in a nested table cell warns once" {
  let result = convert(
    docx_test_docx(
      docx_test_nested_table_with(docx_test_formula()), DOCX_TEST_SECTION, [],
    ),
  )
  assert_eq(docx_test_math_warning_count(result.warnings), 1)
  assert_eq(result.warnings.length(), 2)
}

///|
test "DOCX formula in a header warns once in every view" {
  let data = docx_test_story_document(
    "<w:p><w:r><w:t>Body</w:t></w:r></w:p>",
    header="<w:p>" + docx_test_formula() + "</w:p>",
  )
  for views in ["pages", "scroll", "both"] {
    let result = convert(data, views=views)
    assert_eq(
      docx_test_math_warning_count(result.warnings), 1, msg="views " + views,
    )
    assert_eq(result.warnings.length(), 2, msg="views " + views)
  }
  let result = convert(data, views="pages")
  let text = docx_test_commands_text(
    docx_test_page_commands(result, "pages", 0, "header"),
  )
  assert_true(text.contains("x"), msg="header formula is drawn")
}

///|
test "DOCX formula in a footer warns once in every view" {
  let data = docx_test_story_document(
    "<w:p><w:r><w:t>Body</w:t></w:r></w:p>",
    footer="<w:p>" + docx_test_formula() + "</w:p>",
  )
  for views in ["pages", "scroll", "both"] {
    let result = convert(data, views=views)
    assert_eq(
      docx_test_math_warning_count(result.warnings), 1, msg="views " + views,
    )
    assert_eq(result.warnings.length(), 2, msg="views " + views)
  }
  let result = convert(data, views="pages")
  let text = docx_test_commands_text(
    docx_test_page_commands(result, "pages", 0, "footer"),
  )
  assert_true(text.contains("x"), msg="footer formula is drawn")
}

///|
test "DOCX formulas in a table, a header and a footer warn once" {
  let formula = docx_test_formula()
  let result = convert(
    docx_test_story_document(
      docx_test_table_with(formula),
      header="<w:p>" + formula + "</w:p>",
      footer="<w:p>" + formula + "</w:p>",
    ),
  )
  assert_eq(docx_test_math_warning_count(result.warnings), 1)
  assert_eq(result.warnings.length(), 2)
}

///|
test "DOCX tables and stories without a formula omit the MATH-table warning" {
  let body = "<w:p><w:r><w:t>Body</w:t></w:r></w:p>"
  let cases : Array[(String, Bytes)] = [
    (
      "table cell",
      docx_test_docx(
        docx_test_table_with("<w:r><w:t>x</w:t></w:r>"), DOCX_TEST_SECTION, [],
      ),
    ),
    (
      "nested table cell",
      docx_test_docx(
        docx_test_nested_table_with("<w:r><w:t>x</w:t></w:r>"),
        DOCX_TEST_SECTION,
        [],
      ),
    ),
    (
      "header",
      docx_test_story_document(body, header="<w:p><w:r><w:t>H</w:t></w:r></w:p>"),
    ),
    (
      "footer",
      docx_test_story_document(body, footer="<w:p><w:r><w:t>F</w:t></w:r></w:p>"),
    ),
  ]
  for entry in cases {
    let (label, data) = entry
    for views in ["pages", "scroll", "both"] {
      let result = convert(data, views=views)
      assert_eq(
        docx_test_math_warning_count(result.warnings), 0, msg=label + " " + views,
      )
      assert_eq(result.warnings, [DOCX_TEST_NO_FONT_WARNING], msg=label)
    }
  }
}
