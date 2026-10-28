///|
test "sheet manifest keeps geometry and validates run lengths" {
  let doc = @core.parse_manifest(
    "{\"bdf\":1,\"parts\":[],\"views\":[{\"id\":\"s\",\"kind\":\"sheet\",\"cols\":[[2,40],[1,0],[2,80]],\"rows\":[[3,25]],\"freeze\":{\"cols\":1,\"rows\":2},\"gridlines\":true}]}",
  )
  let view = doc.views[0]
  assert_eq(view.cols.map(fn(r) { (r.count, r.size) }), [
    (2, 40.0),
    (1, 0.0),
    (2, 80.0),
  ])
  assert_eq(view.rows.map(fn(r) { (r.count, r.size) }), [(3, 25.0)])
  assert_eq((view.frozen_cols, view.frozen_rows, view.gridlines), (1, 2, true))
  for
    fields in [
      "\"cols\":[[1.5,20]]", "\"cols\":[[-1,20]]", "\"cols\":[[16777216,1],[1,1]]",
      "\"rows\":[[1,0.001]]", "\"rows\":[[1,16777217]]", "\"rows\":[[1]]", "\"freeze\":{\"cols\":-1}",
      "\"freeze\":[]", "\"gridlines\":\"yes\"",
    ] {
    let mut rejected = false
    let source = "{\"bdf\":1,\"parts\":[],\"views\":[{\"id\":\"s\",\"kind\":\"sheet\"," +
      fields +
      "}]}"
    ignore(@core.parse_manifest(source)) catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
}
