///|
fn check_pdf_text_state(
  operations : Array[(Bytes, Array[ContentValue])],
  in_text : Bool,
  matrix : (Double, Double, Double, Double, Double, Double),
  line_matrix : (Double, Double, Double, Double, Double, Double),
  base : (Double, Double, Double, Double, Double, Double),
  position : (Double, Double),
  params : (Double, Double, Double, Double, Double, Int32),
) -> Unit raise {
  let state = PdfTextState::new()
  for (op, args) in operations {
    assert_true(state.execute(op, args))
  }
  assert_eq(state.in_text, in_text)
  assert_eq(state.matrix, matrix)
  assert_eq(state.line_matrix, line_matrix)
  assert_eq(state.base, base)
  assert_eq((state.x, state.y), position)
  assert_eq(
    (
      state.char_spacing,
      state.word_spacing,
      state.horizontal_scale,
      state.leading,
      state.rise,
      state.rendering_mode,
    ),
    params,
  )
}
