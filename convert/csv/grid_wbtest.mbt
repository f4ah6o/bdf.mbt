///|
test "CSV grid aligns digit-only code columns as text" {
  let parsed = parse(
    @utf8.encode("Code,N,Mixed\n0012,12,0012\n1003,1003,abc\n,7,1003"),
    header=HeaderYes,
  )
  let grid = prepare_grid(parsed)
  assert_eq(grid.header_rows, 1)
  assert_false(grid.rows[2][0].number)
  assert_true(grid.rows[2][1].number)
  assert_true(grid.rows[3][2].number)
  assert_eq(grid.rows[2][0].text, "1003")
}

///|
test "CSV grid considers the first row when it is data" {
  let parsed = parse(@utf8.encode("0012,1\n1003,2\n1004,3"), header=HeaderNo)
  let grid = prepare_grid(parsed)
  assert_eq(grid.header_rows, 0)
  assert_false(grid.rows[1][0].number)
  assert_true(grid.rows[1][1].number)
}
