///|
test "scientific and fractional displays" {
  let scientific = xlsx_parse_number_format("##0.0E+0", xlsx_default_palette())
  let (parts, _) = xlsx_format_numeric(scientific[0], 1000000000000000.0)
  assert_eq(parts.length(), 1)
  assert_eq(parts[0].text, "1000.0E+12")
  let fractional = xlsx_parse_number_format("# ?/?", xlsx_default_palette())
  let (parts, _) = xlsx_format_numeric(fractional[0], 1.5)
  let output = StringBuilder()
  for part in parts {
    if part.kind == 0 {
      output.write_string(part.text)
    }
  }
  assert_eq(output.to_string(), "1 1/2")
}

///|
test "general formatting guards recursive rounding" {
  assert_eq(
    xlsx_format_general(0x75154fdd7f73bf3fUL.reinterpret_as_double(), 6),
    "",
  )
  assert_eq(xlsx_format_general(1.2345678901234567, 11), "1.23456789")
}
