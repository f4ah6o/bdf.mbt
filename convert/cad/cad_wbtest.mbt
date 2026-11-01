///|
test "cad paths transform and flatten" {
  let path = CadPath::new()
  path.move_to(0.0, 0.0)
  path.cubic_to(
    { x: 1.0, y: 2.0 },
    { x: 3.0, y: 2.0 },
    { x: 4.0, y: 0.0 },
  )
  path.close()
  let moved = path.transform(@canvas.Matrix::translate(10.0, 0.0))
  let bounds = moved.bounds()
  assert_eq((bounds.min.x, bounds.max.x), (10.0, 14.0))
  let points = flatten(moved, 4)
  assert_eq(points.length(), 5)
}

///|
test "cad arcs and bulges produce finite bounds" {
  let path = CadPath::new()
  path.arc({ x: 0.0, y: 0.0 }, 10.0, 0.0, 3.141592653589793)
  let bounds = path.bounds()
  assert_true(bounds.min.x >= -10.0 && bounds.max.x <= 10.0)
  let bulge = CadPath::new()
  bulge.move_to(0.0, 0.0)
  bulge.bulge_to({ x: 10.0, y: 0.0 }, 1.0)
  assert_true(!bulge.is_empty())
}

///|
test "cad dash patterns alternate dashes and gaps" {
  let (dash, offset) = dash_pattern(Some([4.0, -2.0, 1.0, -1.0]))
  assert_eq(offset, 0.0)
  assert_true(dash is Some(_))
  match dash {
    Some(values) => {
      assert_eq(values.length(), 4)
      assert_eq(values[0], 4.0)
      assert_eq(values[1], 2.0)
    }
    None => fail("dash pattern missing")
  }
}

///|
test "cad drawing groups and text accessors" {
  let drawing = Drawing::new()
  let path = CadPath::new()
  path.move_to(0.0, 0.0)
  path.line_to(10.0, 10.0)
  drawing.begin(Some(path))
  drawing.stroke(path, Pen::new())
  drawing.text(CadText::new("hello", @canvas.Matrix::identity()))
  drawing.end()
  assert_eq(rings(drawing), 1)
  assert_eq(drawing.texts().length(), 1)
}

///|
fn rings(drawing : Drawing) -> Int {
  if drawing.is_empty() { 0 } else { 1 }
}
