///|
test "sheet geometry finds visible tiles and emits gridlines" {
  let view = @core.parse_manifest(
      "{\"bdf\":1,\"parts\":[],\"views\":[{\"id\":\"s\",\"kind\":\"sheet\",\"cols\":[[2,40],[1,0],[2,80]],\"rows\":[[3,25]]}]}",
    ).views[0]
  assert_eq(@render.sheet_size(view), (240.0, 75.0))
  let viewport : @render.SheetViewport = {
    x: 0.0,
    y: 0.0,
    width: 200.0,
    height: 75.0,
  }
  let grid : Array[(Double, Double, Double, Double)] = []
  @render.sheet_grid_lines(view, viewport, 1.0, fn(x0, y0, x1, y1) {
    grid.push((x0, y0, x1, y1))
  })
  assert_eq(grid, [
    (40.5, 0.0, 40.5, 75.0),
    (80.5, 0.0, 80.5, 75.0),
    (80.5, 0.0, 80.5, 75.0),
    (160.5, 0.0, 160.5, 75.0),
    (0.0, 25.5, 200.0, 25.5),
    (0.0, 50.5, 200.0, 50.5),
    (0.0, 75.5, 200.0, 75.5),
  ])
  let tiles : Array[@core.Tile] = [
    { x: 5, y: 7, object: "d", },
    { x: 0, y: 1, object: "c", },
    { x: 1, y: 0, object: "b", },
    { x: 0, y: 0, object: "a", },
  ]
  let range = @render.sheet_tile_range(
    { x: 0.0, y: 0.0, width: 200.0, height: 200.0, },
    100.0,
  )
  assert_eq((range.x0, range.y0, range.x1, range.y1), (0.0, 0.0, 1.0, 1.0))
  assert_eq(
    @render.sheet_tiles_in(tiles, [range, range]).map(fn(t) { t.object }),
    ["a", "b", "c"],
  )
  assert_eq(
    @render.sheet_tiles_in(tiles, [
      { x0: 0.0, y0: 0.0, x1: 1.0e15, y1: 1.0e15, },
    ]).map(fn(t) { t.object }),
    ["a", "b", "c", "d"],
  )
}

///|
test "sheet grid skips distant runs without expanding them" {
  let view = @core.parse_manifest(
      "{\"bdf\":1,\"parts\":[],\"views\":[{\"id\":\"s\",\"kind\":\"sheet\",\"cols\":[[16777216,1]],\"rows\":[[2,20]]}]}",
    ).views[0]
  let lines : Array[Double] = []
  @render.sheet_grid_lines(
    view,
    { x: 16777210.0, y: 0.0, width: 10.0, height: 40.0, },
    1.0,
    fn(x, _, x1, _) { if x == x1 { lines.push(x) } },
  )
  assert_eq(lines, [
    16777210.5, 16777211.5, 16777212.5, 16777213.5, 16777214.5, 16777215.5, 16777216.5,
  ])
}

///|
test "fractional grid positions follow upstream addition order" {
  let view = @core.parse_manifest(
      "{\"bdf\":1,\"parts\":[],\"views\":[{\"id\":\"s\",\"kind\":\"sheet\",\"cols\":[[1100,0.1]],\"rows\":[[1,1]]}]}",
    ).views[0]
  let xs : Array[Double] = []
  @render.sheet_grid_lines(
    view,
    { x: 100.0, y: 0.0, width: 2.0, height: 1.0, },
    1.0,
    fn(x0, _, x1, _) { if x0 == x1 { xs.push(x0) } },
  )
  assert_eq(xs.length(), 20)
  assert_eq(xs[0], 100.5)
  assert_eq(xs[19], 102.5)
}
