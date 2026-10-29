///|
test "font example limits follow the converter parameter" {
  assert_eq(parse_example_limit(""), 200)
  assert_eq(parse_example_limit("all"), 0)
  assert_eq(parse_example_limit("+0"), 0)
  assert_eq(parse_example_limit("123"), 123)
  assert_eq(parse_example_limit("2147483648"), 2147483647)
  for value in ["-1", " 2", "abc", "9223372036854775808"] {
    let error = try {
      ignore(parse_example_limit(value))
      ""
    } catch {
      InvalidFontInput(message) => message
      _ => "unexpected error"
    }
    assert_eq(
      error,
      "font: parameter examples: " +
      font_quote(value) +
      " is not a number or all",
    )
  }
}
