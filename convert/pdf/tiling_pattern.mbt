///|
fn pdf_tiling_pattern_stream(
  file : PdfFile,
  object : PdfObject,
) -> (PdfObject, Bytes) raise PdfStreamError {
  match object {
    PdfRef(number, _) => {
      let loaded = file.load(number, 0)
      match loaded.stream {
        Some(raw) => (loaded.value, raw)
        None => raise InvalidStream("PDF tiling pattern is not a stream")
      }
    }
    _ => raise InvalidStream("PDF tiling pattern is not a stream")
  }
}

///|
// Paint a PatternType 1 cell at every tile position intersecting the filled
// path. Each tile is a clipped copy of the cell content, which keeps the
// converter independent of any rasterizer.
fn PdfGraphics::tiling_pattern_fill(
  self : PdfGraphics,
  path_index : Int32,
  rule : Byte,
  object : PdfObject,
  bounds : (Double, Double, Double, Double),
) -> Unit raise PdfStreamError {
  let file = match self.file {
    Some(value) => value
    None => raise InvalidStream("PDF tiling pattern resource missing")
  }
  if self.form_depth >= 16 {
    raise InvalidStream("PDF tiling pattern nesting limit")
  }
  let (dict, raw) = pdf_tiling_pattern_stream(file, object)
  let bbox = match pdf_form_numbers(file, dict, b"BBox", 4) {
    Some(values) => values
    None => raise InvalidStream("PDF tiling pattern BBox is missing")
  }
  let bbox_x0 = bbox[0]
  let bbox_y0 = bbox[1]
  let bbox_x1 = bbox[2]
  let bbox_y1 = bbox[3]
  if bbox_x1 <= bbox_x0 || bbox_y1 <= bbox_y0 {
    raise InvalidStream("PDF tiling pattern BBox is invalid")
  }
  let x_step = match file.page_num(pdf_dict_get(dict, b"XStep")) {
    Some(value) if value != 0.0 => value.abs()
    _ => raise InvalidStream("PDF tiling pattern XStep is invalid")
  }
  let y_step = match file.page_num(pdf_dict_get(dict, b"YStep")) {
    Some(value) if value != 0.0 => value.abs()
    _ => raise InvalidStream("PDF tiling pattern YStep is invalid")
  }
  let matrix = match pdf_form_numbers(file, dict, b"Matrix", 6) {
    Some(values) =>
      (values[0], values[1], values[2], values[3], values[4], values[5])
    None => (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
  }
  let paint_type = match file.page_num(pdf_dict_get(dict, b"PaintType")) {
    Some(value) => value.to_int()
    None => 1
  }
  let resources_object = file.page_deref(pdf_dict_get(dict, b"Resources"))
  let pattern_resources : PdfObject? = match resources_object {
    PdfDict(_) => Some(resources_object)
    _ => None
  }
  let (content, codec) = pdf_decode_stream(
    raw,
    file.resolved_stream_filters(dict),
    268435456L,
    false,
    268435456L,
  )
  if codec is Some(_) {
    raise InvalidStream("PDF tiling pattern content is encoded as an image")
  }
  let inverse = match pdf_matrix_inverse(matrix) {
    Some(value) => value
    None => raise InvalidStream("PDF tiling pattern matrix is singular")
  }
  let pattern_rect = pdf_transform_rect(inverse, bounds)
  let tx = (Double::floor((pattern_rect.0 - bbox_x1) / x_step) + 1.0) *
    x_step
  let mut ty = (Double::floor((pattern_rect.1 - bbox_y1) / y_step) + 1.0) *
    y_step
  let mut count = 0
  self.form_depth += 1
  let depth = self.stack.length()
  self.save()
  self.object.clip_path(path_index, rule) catch {
    _ => raise InvalidStream("PDF tiling pattern clip output failed")
  }
  while ty + bbox_y0 < pattern_rect.3 {
    let mut x = tx
    while x + bbox_x0 < pattern_rect.2 {
      count += 1
      if count > 10000 {
        raise InvalidStream("PDF tiling pattern has too many tiles")
      }
      let tile_depth = self.stack.length()
      self.save()
      self.transform(matrix)
      self.transform((1.0, 0.0, 0.0, 1.0, x, ty))
      self.object.clip_rect(
        Float::from_double(bbox_x0),
        Float::from_double(bbox_y0),
        Float::from_double(bbox_x1 - bbox_x0),
        Float::from_double(bbox_y1 - bbox_y0),
      )
      self.state.fill_pattern = None
      self.state.stroke_pattern = None
      if paint_type == 2 {
        self.state.fill_space = PdfRGB
        self.emitted.fill = None
      }
      let old_resources = self.resources
      match pattern_resources {
        Some(value) => self.resources = Some(value)
        None => ()
      }
      self.run_ops(content)
      self.finish_text()
      if self.mask_group_active && self.mask_group_level > tile_depth {
        self.close_mask_group()
      }
      self.resources = old_resources
      while self.stack.length() > tile_depth + 1 {
        self.restore()
      }
      self.restore()
      x += x_step
    }
    ty += y_step
  }
  while self.stack.length() > depth + 1 {
    self.restore()
  }
  self.restore()
  self.form_depth -= 1
}
