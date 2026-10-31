///|
fn check_pdf_draw_operators(
  operations : Array[(Bytes, Array[ContentValue])],
  verbs : Bytes,
  coordinates : Array[Double],
  bounds : (Double, Double, Double, Double)?,
  current : (Double, Double),
  start : (Double, Double),
) -> Unit raise {
  let path = PdfDrawPath::new()
  for (operator, args) in operations {
    assert_true(path.execute(operator, args))
  }
  assert_eq(Bytes::from_array(path.verbs), verbs)
  assert_eq(path.coordinates, coordinates)
  assert_eq(path.bounds, bounds)
  assert_eq((path.current_x, path.current_y), current)
  assert_eq((path.start_x, path.start_y), start)
}

///|
test "unrelated PDF operators leave the current path alone" {
  let path = PdfDrawPath::new()
  assert_false(path.execute(b"BT", []))
  assert_eq(path.verbs.length(), 0)
}
