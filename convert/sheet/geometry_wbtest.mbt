///|
fn geometry_count(runs : Array[Run]) -> Int32 {
  let mut total = 0
  for run in runs {
    total += run.count
  }
  total
}

///|
test "sheet extent expands for overflowing text and stops at the next cell" {
  let text = "x".repeat(1024)
  let open = grid_geometry([[{ text, number: false, }]], header_rows=1)
  assert_true(geometry_count(open.columns) > 12)
  assert_eq(geometry_count(open.rows), 30)
  assert_eq(open.frozen_rows, 1)
  let blocked = grid_geometry([
    [
      { text, number: false, },
      { text: "", number: false, },
      { text: "stop", number: false, },
    ],
  ])
  assert_eq(geometry_count(blocked.columns), 12)
}

///|
test "frozen headers are capped by the record count" {
  let geometry = grid_geometry(
    [[{ text: "header", number: false, }], [], []],
    header_rows=40,
  )
  assert_eq(geometry.frozen_rows, 3)
  assert_eq(geometry_count(geometry.rows), 30)
}
