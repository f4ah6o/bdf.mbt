///|
fn arc_near(actual : Double, expected : Double) -> Unit raise {
  assert_true((actual - expected).abs() < 0.000001,
    msg="arc coordinate: \{actual} != \{expected}")
}

///|
test "stencil arc quarter circle uses angles not cosines" {
  let k = 4.0 / 3.0 * @math.tan(3.141592653589793 / 8.0)
  let a = drawio_arc_to_curves(1.0, 0.0, 1.0, 1.0, 0.0, false, true, 0.0, 1.0)
  assert_eq(a.length(), 6)
  for (actual, expected) in a.zip([1.0, k, k, 1.0, 0.0, 1.0]) {
    arc_near(actual, expected)
  }
  let b = drawio_arc_to_curves(0.0, 1.0, 1.0, 1.0, 0.0, false, false, 1.0, 0.0)
  assert_eq(b.length(), 6)
  for (actual, expected) in b.zip([k, 1.0, 1.0, k, 1.0, 0.0]) {
    arc_near(actual, expected)
  }
}

///|
test "stencil arcs retain endpoints for rotation large arcs and corrected radii" {
  for (rx, ry, angle, large, sweep, x, y) in [
    (1.0, 1.0, 0.0, false, true, -1.0, 0.0),
    (1.0, 1.0, 0.0, true, false, 0.0, 1.0),
    (2.0, 1.0, 35.0, false, true, 3.0, 2.0),
    (0.1, 0.2, 20.0, false, false, 5.0, 7.0),
  ] {
    let a = drawio_arc_to_curves(1.0, 0.0, rx, ry, angle, large, sweep, x, y)
    assert_true(a.length() >= 6 && a.length() % 6 == 0)
    for n in a { assert_false(n.is_nan() || n.is_inf()) }
    arc_near(a[a.length() - 2], x)
    arc_near(a[a.length() - 1], y)
  }
}

///|
test "stencil AWS cloud first small arc keeps endpoint" {
  // Public upstream aws4.xml.gz: group aws cloud alt, first SVG A command.
  let a = drawio_arc_to_curves(8.53, 10.06, 3.37, 3.37, 0.0, false, false, 8.19, 10.07)
  assert_eq(a.length(), 6)
  arc_near(a[4], 8.19)
  arc_near(a[5], 10.07)
  // This short arc cannot escape the icon's 35-by-35 local box.
  for n in a { assert_true(n >= 0.0 && n <= 35.0) }
}
