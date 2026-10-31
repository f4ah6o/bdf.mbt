///|
// PDF text positioning is kept separate from the graphics transform. Glyph
// decoding and BDF text emission are added by the text renderer.
priv struct PdfTextState {
  mut in_text : Bool
  mut matrix : (Double, Double, Double, Double, Double, Double)
  mut line_matrix : (Double, Double, Double, Double, Double, Double)
  mut base : (Double, Double, Double, Double, Double, Double)
  mut x : Double
  mut y : Double
  mut char_spacing : Double
  mut word_spacing : Double
  mut horizontal_scale : Double
  mut leading : Double
  mut rise : Double
  mut rendering_mode : Int32
}

///|
fn PdfTextState::new() -> PdfTextState {
  let zero = (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
  {
    in_text: false,
    matrix: zero,
    line_matrix: zero,
    base: zero,
    x: 0.0,
    y: 0.0,
    char_spacing: 0.0,
    word_spacing: 0.0,
    horizontal_scale: 1.0,
    leading: 0.0,
    rise: 0.0,
    rendering_mode: 0,
  }
}

///|
fn PdfTextState::set_line(
  self : PdfTextState,
  matrix : (Double, Double, Double, Double, Double, Double),
) -> Unit {
  self.matrix = matrix
  self.line_matrix = matrix
  self.base = matrix
  self.x = 0.0
  self.y = 0.0
}

///|
fn PdfTextState::execute(
  self : PdfTextState,
  op : Bytes,
  args : Array[ContentValue],
) -> Bool {
  let n = args.length()
  match op {
    b"BT" => {
      let identity = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
      self.in_text = true
      self.set_line(identity)
    }
    b"ET" => self.in_text = false
    b"Tc" => self.char_spacing = pdf_draw_number(args, n - 1)
    b"Tw" => self.word_spacing = pdf_draw_number(args, n - 1)
    b"Tz" => self.horizontal_scale = pdf_draw_number(args, n - 1) / 100.0
    b"TL" => self.leading = pdf_draw_number(args, n - 1)
    b"Ts" => self.rise = pdf_draw_number(args, n - 1)
    b"Tr" => self.rendering_mode = pdf_draw_number(args, n - 1).to_int()
    b"Td" | b"TD" =>
      if n >= 2 {
        let x = pdf_draw_number(args, n - 2)
        let y = pdf_draw_number(args, n - 1)
        if op == b"TD" {
          self.leading = -y
        }
        self.set_line(
          pdf_matrix_mul((1.0, 0.0, 0.0, 1.0, x, y), self.line_matrix),
        )
      }
    b"Tm" =>
      if n >= 6 {
        self.set_line(
          (
            pdf_draw_number(args, n - 6),
            pdf_draw_number(args, n - 5),
            pdf_draw_number(args, n - 4),
            pdf_draw_number(args, n - 3),
            pdf_draw_number(args, n - 2),
            pdf_draw_number(args, n - 1),
          ),
        )
      }
    b"T*" =>
      self.set_line(
        pdf_matrix_mul(
          (1.0, 0.0, 0.0, 1.0, 0.0, -self.leading),
          self.line_matrix,
        ),
      )
    _ => return false
  }
  true
}
