///|
fn field_error(value : String) -> String {
  try {
    ignore(fields(parse(value)))
    ""
  } catch {
    TagError(message, _) => message
  }
}

///|
test "form fields follow sections" {
  let flat = fields(parse("{{#items}}{{name}}{{/items}}"))
  assert_eq(flat.length(), 2)
  assert_eq(flat[0].name, "items")
  assert_eq(flat[0].kind, FIELD_SECTION)
  assert_eq(flat[0].mode, "")
  assert_eq(flat[1].name, "name")
  assert_eq(flat[1].kind, FIELD_VALUE)
  assert_eq(flat[1].in_sections, ["items"])
  let nested = fields(parse("{{#a}}{{#b}}{{x}}{{/b}}{{/a}}"))
  assert_eq(nested.length(), 3)
  assert_eq(nested[1].in_sections, ["a"])
  assert_eq(nested[2].in_sections, ["a", "b"])
  let empty_close = fields(parse("{{#a}}x{{/}}"))
  assert_eq(empty_close.length(), 1)
  let inverted = fields(parse("{{^paid}}{{x}}{{/paid}}"))
  assert_eq(inverted[0].kind, FIELD_SECTION)
  assert_true(inverted[0].inverted, msg="inverted section")
}

///|
test "form fields merge tags of one name" {
  let flat = fields(parse("{{total | fmt:\"#,##0\"}}{{total | fmt:\"0.00\"}}"))
  assert_eq(flat.length(), 1)
  assert_eq(flat[0].format, "#,##0")
  let image = fields(parse("{{%url | qr:h}}"))[0]
  assert_eq(image.kind, FIELD_IMAGE)
  assert_eq(image.code, "qr")
  let signature = fields(parse("{{%sign | signature}}"))[0]
  assert_eq(signature.input, INPUT_SIGNATURE)
}

///|
test "form fields check section nesting" {
  assert_true(
    field_error("{{/a}}").contains("not open"),
    msg="a close without a section",
  )
  assert_true(
    field_error("{{#a}}{{#b}}{{/a}}").contains("inside b"),
    msg="a close of an outer section",
  )
  assert_true(
    field_error("{{#a}}").contains("not closed"),
    msg="an open section",
  )
}
