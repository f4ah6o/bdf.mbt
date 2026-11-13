///|
test "rounded connector quadratic equivalents and style controls" {
  let points = [(0.0, 0.0), (40.0, 0.0), (40.0, 40.0), (80.0, 40.0)]
  let path = drawio_connector_path(points, "")
  assert_eq(path.verbs.length(), 6)
  arrow_point_close(path.points[1], 30, 0, "first entry")
  arrow_point_close(path.points[2], 36.666666666666664, 0, "Q cubic control 1")
  arrow_point_close(path.points[3], 40, 3.3333333333333335, "Q cubic control 2")
  arrow_point_close(path.points[4], 40, 10, "first exit")
  arrow_point_close(path.points[5], 40, 30, "second entry")
  arrow_point_close(path.points[path.points.length()-1], 80, 40, "endpoint")
  let sharp = drawio_connector_path(points, "rounded=0;")
  assert_eq(sharp.points.length(), 4)
  assert_eq(drawio_connector_path(points, "arcSize=0;").points.length(), 4)
  assert_eq(drawio_connector_path(points, "rounded=2;").points.length(), 4)
  let small = drawio_connector_path(points, "arcSize=8;")
  arrow_point_close(small.points[1], 36, 0, "arcSize halved")
  let curved = drawio_connector_path(points, "curved=1;rounded=1;arcSize=8;")
  let original = drawio_edge_path(points, true)
  assert_eq(curved.verbs, original.verbs)
  assert_eq(curved.points.length(), original.points.length())
  for i in 0..<curved.points.length() {
    arrow_point_close(curved.points[i], original.points[i].x, original.points[i].y, "curved unchanged")
  }
  assert_eq(points, [(0, 0), (40, 0), (40, 40), (80, 40)])
}

///|
test "rounded connector short and duplicate segments stay finite" {
  let points = [(0.0, 0.0), (4.0, 0.0), (4.0, 0.0), (4.0, 4.0)]
  let path = drawio_connector_path(points, "rounded=1;")
  arrow_point_close(path.points[1], 2, 0, "short incoming half")
  arrow_point_close(path.points[4], 4, 2, "short outgoing half")
  for point in path.points {
    assert_true(point.x >= 0 && point.x <= 4 && point.y >= 0 && point.y <= 4)
  }
  let duplicate = drawio_connector_path([(1, 1), (1, 1), (1, 1)], "")
  for point in duplicate.points {
    arrow_point_close(point, 1, 1, "coincident points")
  }
  assert_eq(drawio_connector_path([], "").points.length(), 0)
}
