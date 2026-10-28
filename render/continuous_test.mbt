///|
test "continuous bands use bodies, viewport intersections and signed gaps" {
  let doc = @core.parse_manifest(
    "{\"bdf\":1,\"parts\":[],\"views\":[{\"id\":\"v\",\"kind\":\"flow\",\"continuous\":{\"gap\":-10},\"pages\":[{\"w\":100,\"h\":80,\"body\":{\"x\":10,\"y\":5,\"w\":60,\"h\":40},\"layers\":[]},{\"w\":90,\"h\":50,\"layers\":[]}]}]}",
  )
  let view = doc.views[0]
  let layout = @render.continuous_layout(view)
  assert_eq(layout.offsets, [0.0, 30.0])
  assert_eq((layout.width, layout.height), (90.0, 80.0))
  let bands = @render.continuous_bands(view, {
    x: 0.0,
    y: 35.0,
    width: 30.0,
    height: 1.0,
  })
  assert_eq(bands.map(band => band.index), [0, 1])
  assert_eq((bands[0].body.x, bands[0].body.y), (10.0, 5.0))
  let edge = @render.continuous_bands(view, {
    x: 0.0,
    y: 80.0,
    width: 30.0,
    height: 1.0,
  })
  assert_true(edge.is_empty())
  let strip = { ..view, kind: "scroll", }
  let strip_layout = @render.continuous_layout(strip)
  assert_eq(strip_layout.offsets, [0.0, 40.0])
  assert_eq(strip_layout.height, 90.0)
  let empty = { ..view, pages: [], }
  assert_eq(@render.continuous_layout(empty).height, 10.0)
}
