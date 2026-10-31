///|
fn pdf_color_component(value : Double) -> UInt32 {
  (Double::min(1.0, Double::max(0.0, value)) * 255.0).round().to_uint()
}

///|
fn pdf_color(red : Double, green : Double, blue : Double) -> UInt32 {
  (pdf_color_component(red) << 24) |
  (pdf_color_component(green) << 16) |
  (pdf_color_component(blue) << 8) |
  255U
}

///|
fn PdfGraphics::end_path(
  self : PdfGraphics,
  fill : Bool,
  rule : Byte,
  stroke : Bool,
) -> Unit raise {
  if self.path.bounds is Some(_) {
    if fill || stroke || self.clip >= 0 {
      let entry : @core.Path = {
        verbs: Bytes::from_array(self.path.verbs),
        coordinates: self.path.coordinates.copy(),
      }
      let index = self.object.add_path(@core.Inline(entry))
      if fill {
        self.sync_fill()
        self.object.fill_path(index, rule)
      }
      if stroke {
        self.sync_stroke()
        self.object.stroke_path(index)
      }
      if self.clip >= 0 {
        self.object.clip_path(index, self.clip.to_byte())
      }
    }
  } else if self.clip >= 0 {
    self.object.clip_rect(0.0F, 0.0F, 0.0F, 0.0F)
  }
  let old = self.path
  self.path = PdfDrawPath::new()
  self.path.current_x = old.current_x
  self.path.current_y = old.current_y
  self.path.start_x = old.start_x
  self.path.start_y = old.start_y
  self.clip = -1
}

///|
fn PdfGraphics::execute(
  self : PdfGraphics,
  operator : Bytes,
  args : Array[ContentValue],
) -> Unit raise PdfStreamError {
  if self.path.execute(operator, args) {
    return
  }
  let n = args.length()
  match operator {
    b"q" => self.save()
    b"Q" => self.restore()
    b"cm" =>
      if n >= 6 {
        self.transform(
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
    b"w" => self.state.width = pdf_draw_number(args, n - 1)
    b"J" =>
      self.state.cap = Double::min(
          2.0,
          Double::max(0.0, pdf_draw_number(args, n - 1)),
        )
        .to_int()
        .to_byte()
    b"j" =>
      self.state.join = Double::min(
          2.0,
          Double::max(0.0, pdf_draw_number(args, n - 1)),
        )
        .to_int()
        .to_byte()
    b"M" => self.state.miter = pdf_draw_number(args, n - 1)
    b"g" | b"G" => {
      let value = pdf_draw_number(args, n - 1)
      let color = pdf_color(value, value, value)
      if operator == b"G" {
        self.state.stroke = color
      } else {
        self.state.fill = color
      }
    }
    b"rg" | b"RG" =>
      if n >= 3 {
        let color = pdf_color(
          pdf_draw_number(args, n - 3),
          pdf_draw_number(args, n - 2),
          pdf_draw_number(args, n - 1),
        )
        if operator == b"RG" {
          self.state.stroke = color
        } else {
          self.state.fill = color
        }
      }
    b"k" | b"K" =>
      if n >= 4 {
        let c = Double::min(1.0, Double::max(0.0, pdf_draw_number(args, n - 4)))
        let m = Double::min(1.0, Double::max(0.0, pdf_draw_number(args, n - 3)))
        let y = Double::min(1.0, Double::max(0.0, pdf_draw_number(args, n - 2)))
        let k = Double::min(1.0, Double::max(0.0, pdf_draw_number(args, n - 1)))
        let color = pdf_color(
          (1.0 - c) * (1.0 - k),
          (1.0 - m) * (1.0 - k),
          (1.0 - y) * (1.0 - k),
        )
        if operator == b"K" {
          self.state.stroke = color
        } else {
          self.state.fill = color
        }
      }
    b"W" => self.clip = 0
    b"W*" => self.clip = 1
    b"S" =>
      self.end_path(false, 0, true) catch {
        _ => raise InvalidStream("PDF path output failed")
      }
    b"s" => {
      self.path.close()
      self.end_path(false, 0, true) catch {
        _ => raise InvalidStream("PDF path output failed")
      }
    }
    b"f" | b"F" =>
      self.end_path(true, 0, false) catch {
        _ => raise InvalidStream("PDF path output failed")
      }
    b"f*" =>
      self.end_path(true, 1, false) catch {
        _ => raise InvalidStream("PDF path output failed")
      }
    b"B" =>
      self.end_path(true, 0, true) catch {
        _ => raise InvalidStream("PDF path output failed")
      }
    b"B*" =>
      self.end_path(true, 1, true) catch {
        _ => raise InvalidStream("PDF path output failed")
      }
    b"b" => {
      self.path.close()
      self.end_path(true, 0, true) catch {
        _ => raise InvalidStream("PDF path output failed")
      }
    }
    b"b*" => {
      self.path.close()
      self.end_path(true, 1, true) catch {
        _ => raise InvalidStream("PDF path output failed")
      }
    }
    b"n" =>
      self.end_path(false, 0, false) catch {
        _ => raise InvalidStream("PDF path output failed")
      }
    b"ri" | b"i" => ()
    _ => raise InvalidStream("unsupported PDF graphics operator")
  }
}

///|
fn PdfGraphics::run(
  self : PdfGraphics,
  content : Bytes,
) -> Unit raise PdfStreamError {
  let lexer : ContentLexer = { data: content, pos: 0, }
  let args : Array[ContentValue] = []
  while true {
    match lexer.next(0) {
      End => break
      Operand(value) => {
        args.push(value)
        if args.length() > 64 {
          ignore(args.remove(0))
        }
      }
      Operator(op) => {
        self.execute(op, args)
        args.clear()
      }
    }
  }
  while !self.stack.is_empty() {
    self.restore()
  }
}

///|
// Render a page made solely from the supported graphics operators. Text,
// images and other operators deliberately fail until their renderers exist.
fn PdfFile::graphics_page(
  self : PdfFile,
  page : PdfPageLeaf,
  which : String,
) -> (PdfPageGeometry, Bytes) raise PdfStreamError {
  match page.error {
    Some(message) => raise InvalidStream(message)
    None => ()
  }
  let geometry = self.page_geometry(page, which)
  let content = self.page_content(page.dict)
  let graphics = PdfGraphics::new(
    geometry.width,
    geometry.height,
    geometry.matrix,
  )
  graphics.run(content)
  let encoded = graphics.object.encode() catch {
    _ => raise InvalidStream("PDF graphics output failed")
  }
  (geometry, encoded)
}
