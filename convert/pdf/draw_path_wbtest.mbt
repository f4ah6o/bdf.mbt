///|
fn check_pdf_draw_path(
  operations : Array[(Int32, Array[Double])],
  verbs : Bytes,
  coordinates : Array[Double],
  bounds : (Double, Double, Double, Double),
  current : (Double, Double),
  start : (Double, Double),
) -> Unit raise {
  let path = PdfDrawPath::new()
  for (op, v) in operations {
    match op {
      0 => path.move(v[0], v[1])
      1 => path.line(v[0], v[1])
      2 => path.curve(v[0], v[1], v[2], v[3], v[4], v[5])
      3 => path.close()
      4 => path.rectangle(v[0], v[1], v[2], v[3])
      _ => fail("unexpected path operation")
    }
  }
  assert_eq(Bytes::from_array(path.verbs), verbs)
  assert_eq(path.coordinates, coordinates)
  assert_eq(path.bounds, Some(bounds))
  assert_eq((path.current_x, path.current_y), current)
  assert_eq((path.start_x, path.start_y), start)
}

///|
test "PDF path close and line on empty path" {
  let path = PdfDrawPath::new()
  path.close()
  assert_eq(path.verbs.length(), 0)
  path.line(2.0, 3.0)
  assert_eq(Bytes::from_array(path.verbs), b"\x00")
}
