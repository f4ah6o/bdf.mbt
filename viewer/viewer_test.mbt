///|
test "spread places two pages side by side" {
  let view : @core.View = {
    id: "slides",
    kind: "fixed",
    title: "",
    direction: "ltr",
    continuous_gap: None,
    text_index: None,
    tile_size: 2048.0,
    tiles: [],
    tiles_ref: None,
    cols: [],
    rows: [],
    frozen_cols: 0,
    frozen_rows: 0,
    gridlines: false,
    pages: [
      { width: 100.0, height: 200.0, body: None, layers: [], },
      { width: 80.0, height: 100.0, body: None, layers: [], },
      { width: 50.0, height: 100.0, body: None, layers: [], },
    ],
  }
  let viewer = Viewer::new()
  viewer.set_layout(Spread)
  let p = viewer.placements(view)
  assert_eq(p.length(), 3)
  assert_eq(p[0].y, p[1].y)
  assert_eq(p[1].x, 116.0)
  assert_eq(p[2].y, 216.0)
}

///|
test "zoom reject zero and NaN" {
  let viewer = Viewer::new()
  let mut rejected = false
  viewer.set_zoom(0.0) catch {
    _ => rejected = true
  }
  assert_eq(rejected, true)
  assert_eq(viewer.zoom, 1.0)
  viewer.set_zoom(0.05)
  assert_eq(viewer.zoom, 0.05)
}

///|
test "scroll strips ignore spread and stack without gaps" {
  let view = @core.parse_manifest(
      "{\"bdf\":1,\"parts\":[],\"views\":[{\"id\":\"s\",\"kind\":\"scroll\",\"pages\":[{\"w\":100,\"h\":80,\"layers\":[]},{\"w\":100,\"h\":60,\"layers\":[]},{\"w\":100,\"h\":30,\"layers\":[]}]}]}",
    ).views[0]
  let viewer = @viewer.Viewer::new()
  viewer.set_layout(@viewer.Spread)
  let positions = viewer.placements(view)
  assert_eq(positions.map(p => (p.x, p.y)), [
    (0.0, 0.0),
    (0.0, 80.0),
    (0.0, 140.0),
  ])
  viewer.set_zoom(0.5)
  assert_eq(viewer.placements(view).map(p => p.y), [0.0, 40.0, 70.0])
}

///|
test "RTL spread reverses page positions and continuous mode has no gap" {
  let view = @core.parse_manifest(
      "{\"bdf\":1,\"parts\":[],\"views\":[{\"id\":\"v\",\"kind\":\"fixed\",\"direction\":\"rtl\",\"pages\":[{\"w\":100,\"h\":80,\"layers\":[]},{\"w\":70,\"h\":60,\"layers\":[]},{\"w\":90,\"h\":30,\"layers\":[]}]}]}",
    ).views[0]
  let viewer = @viewer.Viewer::new()
  viewer.set_layout(@viewer.Spread)
  let positions = viewer.placements(view)
  assert_eq(positions.map(p => (p.x, p.y)), [
    (86.0, 0.0),
    (0.0, 0.0),
    (0.0, 96.0),
  ])
  viewer.set_layout(@viewer.Continuous)
  assert_eq(viewer.placements(view).map(p => (p.x, p.y)), [
    (0.0, 0.0),
    (0.0, 80.0),
    (0.0, 140.0),
  ])
}
