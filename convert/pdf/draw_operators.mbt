///|
fn pdf_draw_number(args : Array[ContentValue], index : Int32) -> Double {
  if index < 0 || index >= args.length() {
    return 0.0
  }
  match args[index] {
    Integer(value) => value.to_double()
    Real(value) => value
    _ => 0.0
  }
}

///|
// Consume the path-construction operators; painting and clipping operators
// are handled by the graphics interpreter when it emits the accumulated path.
fn PdfDrawPath::execute(
  self : PdfDrawPath,
  operator : Bytes,
  args : Array[ContentValue],
) -> Bool {
  let n = args.length()
  match operator {
    b"m" =>
      if n >= 2 {
        self.move(pdf_draw_number(args, n - 2), pdf_draw_number(args, n - 1))
      }
    b"l" =>
      if n >= 2 {
        self.line(pdf_draw_number(args, n - 2), pdf_draw_number(args, n - 1))
      }
    b"c" =>
      if n >= 6 {
        self.curve(
          pdf_draw_number(args, n - 6),
          pdf_draw_number(args, n - 5),
          pdf_draw_number(args, n - 4),
          pdf_draw_number(args, n - 3),
          pdf_draw_number(args, n - 2),
          pdf_draw_number(args, n - 1),
        )
      }
    b"v" =>
      if n >= 4 {
        self.curve(
          self.current_x,
          self.current_y,
          pdf_draw_number(args, n - 4),
          pdf_draw_number(args, n - 3),
          pdf_draw_number(args, n - 2),
          pdf_draw_number(args, n - 1),
        )
      }
    b"y" =>
      if n >= 4 {
        self.curve(
          pdf_draw_number(args, n - 4),
          pdf_draw_number(args, n - 3),
          pdf_draw_number(args, n - 2),
          pdf_draw_number(args, n - 1),
          pdf_draw_number(args, n - 2),
          pdf_draw_number(args, n - 1),
        )
      }
    b"h" => self.close()
    b"re" =>
      if n >= 4 {
        self.rectangle(
          pdf_draw_number(args, n - 4),
          pdf_draw_number(args, n - 3),
          pdf_draw_number(args, n - 2),
          pdf_draw_number(args, n - 1),
        )
      }
    _ => return false
  }
  true
}
