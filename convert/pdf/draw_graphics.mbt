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
        self.sync_alpha(false)
        self.object.fill_path(index, rule)
      }
      if stroke {
        self.sync_stroke()
        self.sync_alpha(true)
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
fn PdfGraphics::store_image(
  self : PdfGraphics,
  data : Bytes,
) -> Int32 raise PdfStreamError {
  let hash = self.child_writer.add_part("img", data) catch {
    _ => raise InvalidStream("PDF image output failed")
  }
  if !self.image_hashes.contains(hash) {
    self.image_hashes[hash] = true
    self.images.push(data)
  }
  self.object.add_image(hash)
}

///|
// Image XObjects keep JPEG bytes as they are and encode 8-bit samples as PNG.
// Masks and other codecs need decoders that are not ported yet, so they fail
// closed.
fn PdfGraphics::draw_image_xobject(
  self : PdfGraphics,
  file : PdfFile,
  dict : PdfObject,
  raw : Bytes,
) -> Unit raise PdfStreamError {
  match pdf_dict_get(dict, b"ImageMask") {
    Some(PdfBool(true)) =>
      raise InvalidStream("PDF image masks are not supported yet")
    _ => ()
  }
  for key in [b"SMask", b"Mask"] {
    match pdf_dict_get(dict, key) {
      Some(PdfNull) | None => ()
      Some(_) => raise InvalidStream("PDF image masks are not supported yet")
    }
  }
  match pdf_dict_get(dict, b"Decode") {
    Some(PdfArray(values)) if !values.is_empty() =>
      raise InvalidStream("PDF image Decode arrays are not supported yet")
    _ => ()
  }
  let (data, codec) = pdf_decode_stream(
    raw,
    file.resolved_stream_filters(dict),
    1073741824L,
    false,
    1073741824L,
  )
  match codec {
    Some(b"DCTDecode") => {
      if data.length() < 2 || data[0] != b'\xff' || data[1] != b'\xd8' {
        raise InvalidStream("invalid PDF JPEG image")
      }
      let index = self.store_image(data)
      self.object.image(index, 0.0F, 0.0F, 1.0F, 1.0F) catch {
        _ => raise InvalidStream("PDF image placement failed")
      }
    }
    Some(_) => raise InvalidStream("unsupported PDF image filter")
    None => {
      let (width, height, rgb) = pdf_image_rgb_samples(file, dict, data)
      let png = pdf_png_encode_rgb(width, height, rgb)
      let index = self.store_image(png)
      self.object.image(index, 0.0F, 0.0F, 1.0F, 1.0F) catch {
        _ => raise InvalidStream("PDF image placement failed")
      }
    }
  }
}

///|
fn PdfGraphics::draw_xobject(
  self : PdfGraphics,
  name : Bytes,
) -> Unit raise PdfStreamError {
  let file = match self.file {
    Some(value) => value
    None => raise InvalidStream("PDF XObject resource missing")
  }
  let resources = match self.resources {
    Some(value) => value
    None => raise InvalidStream("PDF XObject resource missing")
  }
  let xobjects = file.page_deref(pdf_dict_get(resources, b"XObject"))
  let reference = match pdf_dict_get(xobjects, name) {
    Some(value) => value
    None => raise InvalidStream("PDF XObject is missing")
  }
  let loaded = match reference {
    PdfRef(number, _) => file.load(number, 0)
    _ => { value: reference, stream: None, }
  }
  match file.page_deref(pdf_dict_get(loaded.value, b"Subtype")) {
    PdfName(b"Image") => {
      let raw = match loaded.stream {
        Some(value) => value
        None => raise InvalidStream("PDF image stream is missing")
      }
      self.draw_image_xobject(file, loaded.value, raw)
    }
    PdfName(b"Form") =>
      raise InvalidStream("PDF form XObjects are not supported yet")
    _ => raise InvalidStream("unsupported PDF XObject")
  }
}

///|
fn PdfGraphics::execute(
  self : PdfGraphics,
  operator : Bytes,
  args : Array[ContentValue],
) -> Unit raise PdfStreamError {
  if self.text_operator(operator, args) {
    return
  }
  if self.text.state.in_text {
    match operator {
      b"gs"
      | b"Do"
      | b"SC"
      | b"SCN"
      | b"sc"
      | b"scn"
      | b"g"
      | b"G"
      | b"rg"
      | b"RG"
      | b"k"
      | b"K" => self.flush_text()
      b"CS" | b"cs" | b"w" | b"J" | b"j" | b"M" | b"d" | b"ri" | b"i" => ()
      _ => raise InvalidStream("unsupported operator in PDF text object")
    }
  }
  if self.path.execute(operator, args) {
    return
  }
  let n = args.length()
  match operator {
    b"gs" =>
      if n >= 1 {
        match args[n - 1] {
          Name(name) => self.apply_ext_state(name)
          _ => ()
        }
      }
    b"Do" =>
      if n >= 1 {
        match args[n - 1] {
          Name(name) => self.draw_xobject(name)
          _ => ()
        }
      }
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
    b"d" =>
      if n >= 2 {
        self.state.dash = match args[n - 2] {
          ArrayValue(values) =>
            values.map(fn(value) { pdf_draw_number([value], 0) })
          _ => []
        }
        self.state.phase = pdf_draw_number(args, n - 1)
      }
    b"g" | b"G" => {
      let value = pdf_draw_number(args, n - 1)
      let color = pdf_color(value, value, value)
      if operator == b"G" {
        self.state.stroke = color
        self.state.stroke_space = PdfGray
      } else {
        self.state.fill = color
        self.state.fill_space = PdfGray
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
          self.state.stroke_space = PdfRGB
        } else {
          self.state.fill = color
          self.state.fill_space = PdfRGB
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
          self.state.stroke_space = PdfCMYK
        } else {
          self.state.fill = color
          self.state.fill_space = PdfCMYK
        }
      }
    b"CS" | b"cs" =>
      if n >= 1 {
        let space = self.resolve_color_space(args[n - 1])
        if operator == b"CS" {
          self.state.stroke_space = space
          self.state.stroke = 0x000000ffU
        } else {
          self.state.fill_space = space
          self.state.fill = 0x000000ffU
        }
      }
    b"SC" | b"SCN" | b"sc" | b"scn" => {
      let stroke = operator == b"SC" || operator == b"SCN"
      let space = if stroke {
        self.state.stroke_space
      } else {
        self.state.fill_space
      }
      let values : Array[Double] = []
      for arg in args {
        match arg {
          Integer(value) => values.push(value.to_double())
          Real(value) => values.push(value)
          _ => ()
        }
      }
      let color = pdf_device_color(space, values)
      if stroke {
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
  self.finish_text()
  while !self.stack.is_empty() {
    self.restore()
  }
}

///|
// Render supported page graphics and text, including child objects.
// Unsupported operators still fail rather than producing incomplete output.
fn PdfFile::graphics_page_parts(
  self : PdfFile,
  page : PdfPageLeaf,
  which : String,
) -> (PdfPageGeometry, Bytes, Array[Bytes], Array[String], Array[Bytes]) raise PdfStreamError {
  match page.error {
    Some(message) => raise InvalidStream(message)
    None => ()
  }
  match self.page_deref(pdf_dict_get(page.dict, b"Annots")) {
    PdfArray(values) if !values.is_empty() =>
      raise InvalidStream("PDF annotations are not supported yet")
    _ => ()
  }
  let geometry = self.page_geometry(page, which)
  let content = self.page_content(page.dict)
  let graphics = PdfGraphics::new(
    geometry.width,
    geometry.height,
    geometry.matrix,
    file=Some(self),
    resources=page.attrs.resources,
  )
  graphics.run(content)
  let encoded = graphics.object.encode() catch {
    _ => raise InvalidStream("PDF graphics output failed")
  }
  let identities : Array[String] = Array::make(graphics.font_refs.length(), "")
  for key, index in graphics.font_refs {
    if index < 0 || index >= identities.length() {
      raise InvalidStream("invalid PDF font identity table")
    }
    let mut identity = if key == 0 { "default" } else { "local:\{key}" }
    for reference, cached in graphics.fonts {
      let (number, generation) = reference
      let (_, local_key) = cached
      if local_key == key {
        identity = "ref:\{number}:\{generation}"
      }
    }
    identities[index] = identity
  }
  (geometry, encoded, graphics.children, identities, graphics.images)
}

///|
fn PdfFile::graphics_page(
  self : PdfFile,
  page : PdfPageLeaf,
  which : String,
) -> (PdfPageGeometry, Bytes) raise PdfStreamError {
  let (geometry, encoded, children, _, images) = self.graphics_page_parts(
    page, which,
  )
  if !children.is_empty() || !images.is_empty() {
    raise InvalidStream(
      "PDF page contains child objects and requires document context",
    )
  }
  (geometry, encoded)
}
