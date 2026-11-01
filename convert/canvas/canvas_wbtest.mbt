///|
test "matrix composes in canvas order" {
  let matrix = Matrix::translate(10.0, 20.0).mul(Matrix::scale(2.0, 3.0))
  assert_eq(matrix.apply(1.0, 1.0), (12.0, 23.0))
  let rotated = Matrix::rotate(90.0)
  let (x, y) = rotated.apply(1.0, 0.0)
  assert_true((x - 0.0).abs() < 1.0e-12)
  assert_true((y - 1.0).abs() < 1.0e-12)
}

///|
test "canvas encodes a filled rectangle" {
  let canvas = Canvas::new()
  canvas.object().fill_color(0xff0000ffU)
  canvas.object().fill_rect(0.0F, 0.0F, 10.0F, 20.0F)
  canvas.set_drawn()
  let writer = @core.DocumentWriter::new()
  let fonts = Fonts::new(None)
  let warnings : Array[String] = []
  let hash = canvas.encode(writer, fonts, warnings) catch {
    _ => fail("canvas did not encode")
  }
  assert_eq(hash.length(), 32)
  assert_true(canvas.drawn())
}
