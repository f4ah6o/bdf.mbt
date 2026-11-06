///|
test "textform fill options" {
  let strict : TextTemplateData = {
    data: Map([]),
    strict: true,
    format: None,
  }
  let missing = try {
    ignore(fill_result_with(strict, "{{name}}\n"))
    false
  } catch {
    TextFormError(message) => message.contains("the data has no name")
  }
  assert_true(missing, msg="strict data")
  let formatted : TextTemplateData = {
    data: { "n": Json::number(12.0) },
    strict: false,
    format: Some(fn(_, format) { "[" + format + "]" }),
  }
  let result = fill_result_with(formatted, "{{n | fmt:\"0.00\"}}\n")
  assert_eq(result.image.pages[0].lines[0].text, "[0.00]")
}
