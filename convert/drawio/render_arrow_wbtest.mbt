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
test "drawio open arrow leaves unrelated marker endpoint unchanged" {
  for (key, style) in [
      ("endArrow", "endArrow=oval;endSize=10"),
      ("startArrow", "startArrow=diamond"),
      ("endArrow", "endArrow=ERmandOne"),
      ("endArrow", "endArrow="),
      ("endArrow", "endArrow=none"),
    ] {
    let end = drawio_edge_marker_end(
      (320.0, 160.0),
      (240.0, 160.0),
      style,
      key,
      1.0,
    )
    assert_true(
      end.0 == 320.0 && end.1 == 160.0,
      msg="unrelated marker keeps the tip for " + key + " " + style,
    )
  }
}

///|
/// Block-arrow parity with official draw.io (upstream converter/drawio
/// createArrow(2)) and /tmp/bdf-official-compare/legacy-edges.json: the
/// Legacy e2 route (86,331.5)->(187,331.5), no endSize (default 6) and
/// sw=1 in the fixture gets the line end (178.882,331.5) and the marker
/// triangle apex (185.882,331.5) - wing (178.882,335) - wing
/// (178.882,328), exactly the official capture's marker.
test "drawio block end arrow: default size 6, wings and shortened line (legacy e2)" {
  let path = drawio_block_arrow_path(
    (187.0, 331.5),
    (86.0, 331.5),
    6.0,
    1.0,
    2.0,
    false,
  )
  assert_eq(path.verbs.length(), 4)
  arrow_point_close(path.points[0], 185.882, 331.5, "block apex")
  arrow_point_close(path.points[1], 178.882, 335.0, "block wing 1")
  arrow_point_close(path.points[2], 178.882, 328.0, "block wing 2")
  // No explicit endSize: the dispatcher defaults to upstream's 6.
  let end = drawio_edge_marker_end(
    (187.0, 331.5),
    (86.0, 331.5),
    "endArrow=block;endFill=1",
    "endArrow",
    1.0,
  )
  arrow_point_close({ x: end.0, y: end.1 }, 178.882, 331.5, "block line end")
}

///|
test "drawio block start arrow on a vertical route" {
  // Route start (225.25,378) as tip drawn downward toward (225.25,480):
  // the marker points up, mirroring official legacy e2 (apex 478.882 and
  // wings at 471.882 when the end marker sits at (225.25,480)).
  let path = drawio_block_arrow_path(
    (225.25, 378.0),
    (225.25, 480.0),
    6.0,
    1.0,
    2.0,
    false,
  )
  arrow_point_close(path.points[0], 225.25, 379.118, "start apex")
  arrow_point_close(path.points[1], 228.75, 386.118, "start wing 1")
  arrow_point_close(path.points[2], 221.75, 386.118, "start wing 2")
  let start = drawio_edge_marker_end(
    (225.25, 378.0),
    (225.25, 480.0),
    "startArrow=block;startFill=1",
    "startArrow",
    1.0,
  )
  arrow_point_close({ x: start.0, y: start.1 }, 225.25, 386.118, "start line end")
}

///|
test "drawio classic arrow: notch and three-quarter shortened line" {
  // tip (187,331.5), toward (86,331.5), default size 6, sw 1: the notch
  // sits at 5.25 back from the apex and the line stops at the notch.
  let path = drawio_block_arrow_path(
    (187.0, 331.5),
    (86.0, 331.5),
    6.0,
    1.0,
    2.0,
    true,
  )
  assert_eq(path.verbs.length(), 5)
  arrow_point_close(path.points[2], 180.632, 331.5, "classic notch")
  let end = drawio_edge_marker_end(
    (187.0, 331.5),
    (86.0, 331.5),
    "endArrow=classic",
    "endArrow",
    1.0,
  )
  arrow_point_close({ x: end.0, y: end.1 }, 180.632, 331.5, "classic line end")
}

///|
test "drawio block arrow respects strokeWidth and thin wings" {
  // sw 2: the half-gap is 2.236, the marker length size+sw is 8 and the
  // line end pulls back 8+2.236. The thin variants spread 8/3, not 8/2.
  let path = drawio_block_arrow_path(
    (187.0, 331.5),
    (86.0, 331.5),
    6.0,
    2.0,
    2.0,
    false,
  )
  arrow_point_close(path.points[0], 184.764, 331.5, "sw2 apex")
  arrow_point_close(path.points[1], 176.764, 335.5, "sw2 wing 1")
  arrow_point_close(path.points[2], 176.764, 327.5, "sw2 wing 2")
  let thin = drawio_block_arrow_path(
    (187.0, 331.5),
    (86.0, 331.5),
    6.0,
    2.0,
    3.0,
    false,
  )
  arrow_point_close(thin.points[1], 176.764, 331.5 + 8.0 / 3.0, "thin wing 1")
  arrow_point_close(thin.points[2], 176.764, 331.5 - 8.0 / 3.0, "thin wing 2")
  let end = drawio_edge_marker_end(
    (187.0, 331.5),
    (86.0, 331.5),
    "endArrow=block;endSize=6;strokeWidth=2",
    "endArrow",
    2.0,
  )
  arrow_point_close({ x: end.0, y: end.1 }, 176.764, 331.5, "sw2 line end")
}

///|
test "drawio block arrow ignores zero-length segments" {
  let path = drawio_block_arrow_path(
    (187.0, 331.5),
    (187.0, 331.5),
    6.0,
    1.0,
    2.0,
    false,
  )
  assert_true(path.is_empty(), msg="zero-length marker path must be empty")
  let end = drawio_edge_marker_end(
    (187.0, 331.5),
    (187.0, 331.5),
    "endArrow=block",
    "endArrow",
    1.0,
  )
  assert_true(
    end.0 == 187.0 && end.1 == 331.5,
    msg="zero-length keeps tip",
  )
}
