///|
test "numeric classification matches upstream CSV cases" {
  for
    value in [
      "0", "42", "-7", "+3", " 12 ", "3.14", ".5", "3.", "1,5", "1,234", "1,234,567.89",
      "1.234.567,89", "1 234 567", "1'234'567", "1e10", "6.02E+23", "12%", "-12.5 %",
      "$5", "-$5", "$-5", "$1,234.50", "¥1,000", "€ 3,50", "(123)", "(1,234.50)",
    ] {
    assert_true(looks_numeric(value), msg=value)
  }
  for
    value in [
      "007", "0012", "01.5", "1.2.3", "192.168.1.1", "1,23,456", "abc", "12abc",
      "1-2", "$", "%", "-", "e5", "3 apples",
    ] {
    assert_false(looks_numeric(value), msg=value)
  }
}
