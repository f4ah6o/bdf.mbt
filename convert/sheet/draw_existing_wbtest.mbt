///|
test "solid fill ignores a row index beyond the sheet extent" {
  let geometry : GridGeometry = {
    columns: [{ count: 1, size: 10.0F, }],
    rows: [{ count: 1, size: 10.0F, }],
    frozen_rows: 0,
  }
  let fills : Map[Int32, Map[Int32, GridSolidFill]] = Map([
    (2147483647, Map([(0, { key: "red", color: 0xff0000ffU, })])),
  ])
  let result = draw_sized_grid_no_fonts(
    [{ index: 2147483647, cells: [], }],
    geometry,
    [{ count: 16384, size: 10.0F, }],
    "",
    "",
    fills~,
  )
  assert_eq(result.tiles.length(), 0)
}
