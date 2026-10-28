///|
test "spread places two pages side by side" {
  let view : @core.View = {
    id: "slides",
    kind: "fixed",
    title: "",
    pages: [
      { width: 100.0, height: 200.0, layers: [] },
      { width: 80.0, height: 100.0, layers: [] },
      { width: 50.0, height: 100.0, layers: [] },
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
  try {
    viewer.set_zoom(0.0)
  } catch {
    _ => rejected = true
  }
  assert_eq(rejected, true)
  assert_eq(viewer.zoom, 1.0)
}
