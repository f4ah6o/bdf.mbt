///|
/// Open-arrow parity with official draw.io (upstream converter/drawio
/// createOpenArrow) and /tmp/bdf-official-compare/current-edges.json:
/// the Current e2 route (240,160)->(320,160) with endSize=10, sw=1 gets
/// the line end (317.764,160) and the marker V
/// (307.882,165.5) - notch (318.882,160) - (307.882,154.5).
fn arrow_point_close(
  a : @cad.Point,
  x : Double,
  y : Double,
  msg : String,
) -> Unit raise {
  assert_true(
    (a.x - x).abs() < 0.000001 && (a.y - y).abs() < 0.000001,
    msg=msg,
  )
}

///|
test "drawio open end arrow: notch, wings and shortened line (current e2)" {
  // tip (320,160), toward (240,160), endSize 10, strokeWidth 1.
  let path = drawio_open_arrow_path((320.0, 160.0), (240.0, 160.0), 10.0, 1.0)
  assert_eq(path.verbs.length(), 3)
  arrow_point_close(path.points[0], 307.882, 165.5, "open wing 1")
  arrow_point_close(path.points[1], 318.882, 160.0, "open notch")
  arrow_point_close(path.points[2], 307.882, 154.5, "open wing 2")
  let end = drawio_edge_open_end(
    (320.0, 160.0),
    (240.0, 160.0),
    "endArrow=open;endSize=10",
    "endArrow",
    1.0,
  )
  arrow_point_close({ x: end.0, y: end.1 }, 317.764, 160.0, "line endpoint")
}

///|
test "drawio open start arrow on a reversed route" {
  // tip (240,160) (route start), toward (320,160): the V points right.
  let path = drawio_open_arrow_path((240.0, 160.0), (320.0, 160.0), 10.0, 1.0)
  arrow_point_close(path.points[1], 241.118, 160.0, "start notch")
  assert_true(
    (path.points[0].x - 252.118).abs() < 0.000001,
    msg="start wing x",
  )
  assert_true(
    (path.points[0].y - 154.5).abs() < 0.000001,
    msg="start wing 1 y",
  )
  assert_true(
    (path.points[2].y - 165.5).abs() < 0.000001,
    msg="start wing 2 y",
  )
  let start = drawio_edge_open_end(
    (240.0, 160.0),
    (320.0, 160.0),
    "startArrow=open;startSize=10",
    "startArrow",
    1.0,
  )
  arrow_point_close({ x: start.0, y: start.1 }, 242.236, 160.0, "line start")
}

///|
test "drawio open arrow on a vertical route" {
  // tip (160,320), toward (160,240): the V points up.
  let path = drawio_open_arrow_path((160.0, 320.0), (160.0, 240.0), 10.0, 1.0)
  arrow_point_close(path.points[0], 154.5, 307.882, "vertical wing 1")
  arrow_point_close(path.points[1], 160.0, 318.882, "vertical notch")
  arrow_point_close(path.points[2], 165.5, 307.882, "vertical wing 2")
  let end = drawio_edge_open_end(
    (160.0, 320.0),
    (160.0, 240.0),
    "endArrow=open;endSize=10",
    "endArrow",
    1.0,
  )
  arrow_point_close({ x: end.0, y: end.1 }, 160.0, 317.764, "vertical line end")
}

///|
test "drawio open arrow respects strokeWidth" {
  // endSize 10, strokeWidth 2: the notch sits 2*1.118 inside the tip, the
  // 12-long wings spread 6 to each side, the line end 2*2.236 short.
  let path = drawio_open_arrow_path((320.0, 160.0), (240.0, 160.0), 10.0, 2.0)
  arrow_point_close(path.points[1], 317.764, 160.0, "sw2 notch")
  arrow_point_close(path.points[0], 305.764, 166.0, "sw2 wing 1")
  arrow_point_close(path.points[2], 305.764, 154.0, "sw2 wing 2")
  let end = drawio_edge_open_end(
    (320.0, 160.0),
    (240.0, 160.0),
    "endArrow=open;endSize=10;strokeWidth=2",
    "endArrow",
    2.0,
  )
  arrow_point_close({ x: end.0, y: end.1 }, 315.528, 160.0, "sw2 line end")
}

///|
test "drawio open arrow ignores zero-length segments" {
  let path = drawio_open_arrow_path((320.0, 160.0), (320.0, 160.0), 10.0, 1.0)
  assert_true(path.is_empty(), msg="zero-length marker path must be empty")
  assert_true(
    path.points.length() == 0,
    msg="zero-length marker path has no points",
  )
  let end = drawio_edge_open_end(
    (320.0, 160.0),
    (320.0, 160.0),
    "endArrow=open",
    "endArrow",
    1.0,
  )
  assert_true(end.0 == 320.0 && end.1 == 160.0, msg="zero-length keeps tip")
}

///|
test "drawio open arrow leaves non-open marker endpoint unchanged" {
  for (key, style) in [
      ("endArrow", "endArrow=classic;endSize=10"),
      ("startArrow", "startArrow=block"),
      ("endArrow", ""),
      ("endArrow", "endArrow=none"),
    ] {
    let end = drawio_edge_open_end(
      (320.0, 160.0),
      (240.0, 160.0),
      style,
      key,
      1.0,
    )
    assert_true(
      end.0 == 320.0 && end.1 == 160.0,
      msg="non-open marker keeps the tip for " + key + " " + style,
    )
  }
}
