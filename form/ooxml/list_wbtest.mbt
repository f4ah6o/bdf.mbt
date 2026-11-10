///|
// Regression tests of the fill of OOXML parts, adapted from the templates of
// upstream: a section repeats the rows, paragraphs or shapes it covers, the
// options of a tag are applied, a list of values fills {{.}}, and a comment
// tag leaves nothing.

///|
fn ooxml_test_count(text : String, needle : String) -> Int {
  let mut count = 0
  let mut pos = 0
  while pos < text.length() {
    match text[pos:].find(needle) {
      Some(index) => {
        count += 1
        pos = pos + index + needle.length()
      }
      None => break
    }
  }
  count
}

///|
fn ooxml_test_sheet(rows : Array[String]) -> String {
  let mut body = ""
  for row in rows {
    body = body + row
  }
  "<worksheet><sheetData>" + body + "</sheetData></worksheet>"
}

///|
fn ooxml_test_row(index : Int, text : String) -> String {
  "<row r=\"" +
  index.to_string() +
  "\"><c r=\"A" +
  index.to_string() +
  "\" t=\"inlineStr\"><is><t>" +
  text +
  "</t></is></c></row>"
}

///|
fn ooxml_test_items() -> Json {
  Json::object({
    "items": Json::array([
      Json::object({ "name": Json::string("a"), "qty": Json::number(1.0) }),
      Json::object({ "name": Json::string("b"), "qty": Json::number(2.0) }),
    ]),
  })
}

///|
test "ooxml repeats the row of a list across rows" {
  let sheet = ooxml_test_sheet([
    ooxml_test_row(1, "{{#items}}"),
    ooxml_test_row(2, "{{name}}"),
    ooxml_test_row(3, "{{/items}}"),
  ])
  let (filled, warnings) = fill_part(sheet, ooxml_test_items(), false, 1, true)
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  assert_eq(ooxml_test_count(filled, "<row"), 2, msg=filled)
  assert_eq(ooxml_test_count(filled, ">a<"), 1, msg=filled)
  assert_eq(ooxml_test_count(filled, ">b<"), 1, msg=filled)
  assert_true(!filled.contains("{{"), msg=filled)
}

///|
test "ooxml fills a list inside one cell" {
  let sheet = ooxml_test_sheet([
    ooxml_test_row(1, "{{#items}}{{_index}} {{name}} {{/items}}"),
  ])
  let (filled, warnings) = fill_part(sheet, ooxml_test_items(), false, 1, true)
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  assert_eq(ooxml_test_count(filled, "<row"), 1, msg=filled)
  assert_true(filled.contains("1 a"), msg=filled)
  assert_true(filled.contains("2 b"), msg=filled)
}

///|
test "ooxml repeats the paragraphs of a list across table rows" {
  let document =
    "<w:document><w:body><w:tbl>" +
    "<w:tr><w:tc><w:p><w:r><w:t>{{#items}}</w:t></w:r></w:p></w:tc></w:tr>" +
    "<w:tr><w:tc><w:p><w:r><w:t>{{name}}</w:t></w:r></w:p></w:tc></w:tr>" +
    "<w:tr><w:tc><w:p><w:r><w:t>{{/items}}</w:t></w:r></w:p></w:tc></w:tr>" +
    "</w:tbl></w:body></w:document>"
  let (filled, warnings) = fill_part(document, ooxml_test_items(), false, 2, true)
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  assert_eq(ooxml_test_count(filled, "<w:tr>"), 2, msg=filled)
  assert_eq(ooxml_test_count(filled, ">a<"), 1, msg=filled)
  assert_eq(ooxml_test_count(filled, ">b<"), 1, msg=filled)
  assert_true(!filled.contains("{{"), msg=filled)
}

///|
test "ooxml repeats the paragraphs of a list inside one table row" {
  let document =
    "<w:document><w:body><w:tbl><w:tr><w:tc>" +
    "<w:p><w:r><w:t>{{#items}}{{_index}}</w:t></w:r></w:p>" +
    "<w:p><w:r><w:t>{{name}}</w:t></w:r></w:p>" +
    "<w:p><w:r><w:t>{{qty}}{{/items}}</w:t></w:r></w:p>" +
    "</w:tc></w:tr></w:tbl></w:body></w:document>"
  let (filled, warnings) = fill_part(document, ooxml_test_items(), false, 2, true)
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  assert_eq(ooxml_test_count(filled, "<w:tr>"), 1, msg=filled)
  assert_eq(ooxml_test_count(filled, "<w:p>"), 6, msg=filled)
  assert_true(filled.contains("1"), msg=filled)
  assert_true(filled.contains("2"), msg=filled)
}

///|
test "ooxml applies the options of a tag" {
  let values = Json::object({
    "total": Json::number(13200.0),
    "price": Json::number(1200.0),
    "name": Json::string("ACME"),
  })
  let (filled, warnings) = fill_part(
    "<a>{{total | fmt:\"#,##0.00\"}}</a><b>{{price | fmt:\"#,##0\"}}</b><c>{{name | fmt:\"#,##0\"}}</c>",
    values,
    false,
    0,
    true,
  )
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  assert_eq(filled, "<a>13,200.00</a><b>1,200</b><c>ACME</c>")
}

///|
test "ooxml fills the variables of a list" {
  let values = Json::object({
    "items": Json::array([
      Json::object({ "name": Json::string("a") }),
      Json::object({ "name": Json::string("b") }),
    ]),
  })
  let (filled, warnings) = fill_part(
    "{{#items}}{{_index}}/{{_count}}/{{_first}}/{{_last}}={{name}};{{/items}}",
    values,
    false,
    0,
    true,
  )
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  assert_eq(filled, "1/2/TRUE/FALSE=a;2/2/FALSE/TRUE=b;")
}

///|
test "ooxml fills the page variables of a section of pages" {
  let values = Json::object({
    "pages": Json::array([
      Json::object({ "slip": Json::string("s1") }),
      Json::object({ "slip": Json::string("s2") }),
    ]),
  })
  let (filled, warnings) = fill_part(
    "{{#pages | pages}}{{_page}}/{{_pages}}={{slip}};{{/pages}}",
    values,
    false,
    0,
    true,
  )
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  assert_eq(filled, "1/2=s1;2/2=s2;")
}

///|
test "ooxml fills a list of values with a dot" {
  let values = Json::object({
    "tags": Json::array([Json::string("a"), Json::string("b")]),
  })
  let (filled, warnings) = fill_part(
    "{{#tags}}[{{.}}{{^_last}},{{/_last}}]{{/tags}}",
    values,
    false,
    0,
    true,
  )
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  assert_eq(filled, "[a,][b]")
}

///|
test "ooxml removes comment tags" {
  let (filled, warnings) = fill_part(
    "<a>A{{! a note}}B</a><b>{{!}}</b>",
    Json::object({}),
    false,
    0,
    true,
  )
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  assert_eq(filled, "<a>AB</a><b></b>")
}

///|
test "ooxml escapes the values it writes" {
  let values = Json::object({ "name": Json::string("A & B <c> \"d\"") })
  let (filled, warnings) = fill_part(
    "<t>{{name}}</t>",
    values,
    false,
    0,
    true,
  )
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  assert_eq(filled, "<t>A &amp; B &lt;c&gt; &quot;d&quot;</t>")
}

///|
test "ooxml fills nested sections" {
  let values = Json::object({
    "groups": Json::array([
      Json::object({
        "name": Json::string("g1"),
        "items": Json::array([
          Json::object({ "name": Json::string("a") }),
          Json::object({ "name": Json::string("b") }),
        ]),
      }),
      Json::object({
        "name": Json::string("g2"),
        "items": Json::array([Json::object({ "name": Json::string("c") })]),
      }),
    ]),
  })
  let (filled, warnings) = fill_part(
    "{{#groups}}<g>{{name}}{{#items}}<i>{{name}}</i>{{/items}}</g>{{/groups}}",
    values,
    false,
    0,
    true,
  )
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  assert_eq(filled, "<g>g1<i>a</i><i>b</i></g><g>g2<i>c</i></g>")
}

///|
test "ooxml leaves an inactive section without its names" {
  let values = Json::object({ "items": Json::array([]) })
  let (filled, warnings) = fill_part(
    "A{{#items}}{{missing}}{{/items}}B",
    values,
    true,
    0,
    true,
  )
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  assert_eq(filled, "AB")
}

///|
test "ooxml reports a name that strict mode needs" {
  let values = Json::object({ "items": Json::array([]) })
  let message = try {
    ignore(fill_part("A{{missing}}B", values, true, 0, true))
    ""
  } catch {
    OoxmlError(message) => message
  }
  assert_eq(message, "the data has no \"missing\"")
  let (filled, warnings) = fill_part("A{{missing}}B", values, false, 0, true)
  assert_eq(filled, "AB")
  assert_eq(warnings.length(), 1)
  assert_eq(warnings[0], "the data has no \"missing\"; it is left empty")
}

///|
test "ooxml refuses a section that is not closed" {
  let message = try {
    ignore(fill_part("A{{#items}}B", Json::object({}), false, 0, true))
    ""
  } catch {
    OoxmlError(message) => message
  }
  assert_eq(message, "the section {{#items}} is not closed with {{/items}}")
}

///|
test "ooxml refuses a close tag that closes no section" {
  let message = try {
    ignore(fill_part("A{{/items}}B", Json::object({}), false, 0, true))
    ""
  } catch {
    OoxmlError(message) => message
  }
  assert_eq(message, "{{/items}} closes no section")
}

///|
test "ooxml refuses a close tag of another section" {
  let message = try {
    ignore(fill_part("{{#a}}{{/b}}", Json::object({}), false, 0, true))
    ""
  } catch {
    OoxmlError(message) => message
  }
  assert_eq(message, "{{/b}} closes the section {{#a}}")
}

///|
test "ooxml refuses a section that leaves its parent" {
  let sheet = ooxml_test_sheet([
    ooxml_test_row(1, "{{#a}}{{#b}}"),
    ooxml_test_row(2, "{{/b}}"),
    ooxml_test_row(3, "{{/a}}"),
  ])
  let message = try {
    ignore(fill_part(sheet, Json::object({}), false, 1, true))
    ""
  } catch {
    OoxmlError(message) => message
  }
  assert_eq(message, "the section {{#b}} is not inside {{#a}}")
}

///|
test "ooxml refuses a section of slots" {
  let message = try {
    ignore(fill_part("{{#items | slots}}{{name}}{{/items}}", Json::object({}), false, 1, true))
    ""
  } catch {
    OoxmlError(message) => message
  }
  assert_eq(
    message,
    "the section {{#items | slots}} is not supported; write {{#items | rows}} to repeat the rows",
  )
}

///|
test "ooxml refuses a tag that is not closed" {
  let message = try {
    ignore(fill_part("A{{name", Json::object({}), false, 0, true))
    ""
  } catch {
    OoxmlError(message) => message
  }
  assert_eq(message, "ooxml: a tag has no closing braces")
}

///|
test "ooxml reports an image tag it cannot inline" {
  let (filled, warnings) = fill_part(
    "<t>{{%photo}}</t>",
    Json::object({ "photo": Json::string("stamp.png") }),
    false,
    0,
    true,
  )
  assert_eq(filled, "<t></t>")
  assert_eq(warnings.length(), 1)
  assert_true(warnings[0].contains("is not filled"), msg=warnings[0])
}

///|
test "ooxml numbers the rows of a worksheet" {
  let sheet = ooxml_test_sheet([
    ooxml_test_row(1, "{{#items}}"),
    ooxml_test_row(2, "{{name}}"),
    ooxml_test_row(3, "{{/items}}"),
    ooxml_test_row(4, "end"),
  ])
  let (filled, _) = fill_part(sheet, ooxml_test_items(), false, 1, true)
  let (numbered, _) = ooxml_renumber_rows(sheet, filled)
  assert_true(numbered.contains("<row r=\"2\">"), msg=numbered)
  assert_true(numbered.contains("<row r=\"3\">"), msg=numbered)
  assert_true(numbered.contains("<row r=\"4\">"), msg=numbered)
  assert_true(numbered.contains("r=\"A2\""), msg=numbered)
  assert_true(numbered.contains("r=\"A3\""), msg=numbered)
  assert_true(numbered.contains("r=\"A4\""), msg=numbered)
  assert_eq(ooxml_test_count(numbered, "<row"), 3, msg=numbered)
}
