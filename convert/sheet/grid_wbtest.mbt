///|
test "grid widths use header style and filter button metrics" {
  let rows = [
    [{ text: "abcdefgh", number: false, }],
    [{ text: "abcdefgh", number: false, }],
  ]
  let advance = (_ : Char, bold : Bool) => if bold { 12.0 } else { 6.0 }
  assert_eq(fit_columns(rows, header_rows=1, advance~), [101.25F])
  assert_eq(fit_columns(rows, header_rows=1, filter_buttons=true, advance~), [
    113.25F,
  ])
  assert_eq(fit_columns(rows, header_rows=1, subheader=true, advance~), [53.25F])
}

///|
test "long text is capped but numbers are not" {
  let rows = [
    [
      { text: "x".repeat(200), number: false, },
      { text: "1".repeat(200), number: true, },
    ],
  ]
  let widths = fit_columns(rows)
  assert_eq(widths[0], 266.25F)
  assert_true(widths[1] > 266.25F)
}
