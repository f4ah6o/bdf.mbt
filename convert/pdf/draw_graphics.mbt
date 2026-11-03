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
  match self.path.bounds {
    Some((x0, y0, x1, y1)) =>
      if fill || stroke || self.clip >= 0 {
        let entry : @core.Path = {
          verbs: Bytes::from_array(self.path.verbs),
          coordinates: self.path.coordinates.copy(),
        }
        let index = self.object.add_path(@core.Inline(entry))
        if fill {
          match self.state.fill_pattern {
            Some(name) => {
              self.pattern_fill(index, rule, name, (x0, y0, x1, y1))
              self.emitted.fill = None
            }
            None => {
              self.sync_fill()
              self.sync_alpha(false)
              self.object.fill_path(index, rule)
            }
          }
        }
        if stroke {
          match self.state.stroke_pattern {
            Some(_) =>
              raise InvalidStream("PDF stroke patterns are not supported yet")
            None => ()
          }
          self.sync_stroke()
          self.sync_alpha(true)
          self.object.stroke_path(index)
        }
        if self.clip >= 0 {
          self.object.clip_path(index, self.clip.to_byte()) catch {
            _ => raise InvalidStream("PDF clip output failed")
          }
        }
      }
    None => if self.clip >= 0 { self.object.clip_rect(0.0F, 0.0F, 0.0F, 0.0F) }
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
fn PdfGraphics::store_font(
  self : PdfGraphics,
  data : Bytes,
) -> String raise PdfStreamError {
  let hash = self.child_writer.add_part("font", data) catch {
    _ => raise InvalidStream("PDF font output failed")
  }
  if !self.font_hashes.contains(hash) {
    self.font_hashes[hash] = true
    self.font_parts.push(data)
  }
  hash
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
fn pdf_image_dimension(
  file : PdfFile,
  dict : PdfObject,
  key : Bytes,
  label : String,
) -> Int32 raise PdfStreamError {
  match file.page_num(pdf_dict_get(dict, key)) {
    Some(value) if value > 0.0 && value <= 65535.0 => value.to_int()
    _ => raise InvalidStream("PDF image " + label + " is missing")
  }
}

///|
fn pdf_image_flip_matrix() -> (Double, Double, Double, Double, Double, Double) {
  (1.0, 0.0, 0.0, -1.0, 0.0, 1.0)
}

///|
fn PdfGraphics::emit_image(
  self : PdfGraphics,
  data : Bytes,
) -> Unit raise PdfStreamError {
  let index = self.store_image(data)
  // The page transform flips Y for page space. PDF image samples start at the
  // top row, so flip the unit image square locally to keep row 0 at the top.
  let unsaved = self.unsaved
  self.save()
  defer self.restore()
  // save() is suppressed at the 1024-state limit, so restore() cannot pop the
  // local flip. Re-apply the self-inverse flip to keep the caller's CTM.
  let suppressed = self.unsaved > unsaved
  let flip = pdf_image_flip_matrix()
  self.transform(flip)
  self.object.image(index, 0.0F, 0.0F, 1.0F, 1.0F) catch {
    _ => {
      if suppressed {
        self.transform(flip)
      }
      raise InvalidStream("PDF image placement failed")
    }
  }
  if suppressed {
    self.transform(flip)
  }
}

///|
// Image data keeps JPEG bytes as they are, decodes CCITT fax data, encodes
// 8-bit samples as PNG and turns 1-bit stencil masks into RGBA PNGs. Other
// codecs and sample formats need decoders that are not ported yet.
fn PdfGraphics::draw_image_data(
  self : PdfGraphics,
  width : Int32,
  height : Int32,
  bpc : Int32,
  space : PdfDeviceColorSpace?,
  is_mask : Bool,
  invert : Bool,
  data : Bytes,
  codec : Bytes?,
  ccitt : PdfCcittParams?,
) -> Unit raise PdfStreamError {
  match codec {
    Some(b"DCTDecode") => {
      if is_mask {
        raise InvalidStream("PDF image masks cannot use JPEG data")
      }
      if data.length() < 2 || data[0] != b'\xff' || data[1] != b'\xd8' {
        raise InvalidStream("invalid PDF JPEG image")
      }
      self.emit_image(data)
    }
    Some(b"CCITTFaxDecode") => {
      if bpc != 1 {
        raise InvalidStream("PDF CCITT images must have one bit per component")
      }
      let params = match ccitt {
        Some(value) => value
        None => pdf_ccitt_default_params()
      }
      let bits = pdf_decode_ccitt(params, width, height, data)
      if is_mask {
        let rgba = pdf_ccitt_mask_rgba(
          width,
          height,
          bits,
          params.black_is1,
          invert,
          self.state.fill,
        )
        self.emit_image(pdf_png_encode_rgba(width, height, rgba))
      } else {
        match space {
          Some(PdfGray) => ()
          Some(_) =>
            raise InvalidStream("PDF CCITT images require a gray colour space")
          None => raise InvalidStream("PDF image color space is missing")
        }
        let rgb = pdf_ccitt_rgb(
          width,
          height,
          bits,
          params.black_is1,
          invert,
        )
        self.emit_image(pdf_png_encode_rgb(width, height, rgb))
      }
    }
    Some(b"JPXDecode") => {
      if is_mask {
        raise InvalidStream("PDF image masks cannot use JPEG 2000 data")
      }
      let (jpx_width, jpx_height, jpx_rgb) = pdf_jpx_rgb(data, space, invert)
      self.emit_image(pdf_png_encode_rgb(jpx_width, jpx_height, jpx_rgb))
    }
    Some(b"JBIG2Decode") => {
      if is_mask {
        let (jbig2_width, jbig2_height, jbig2_bits) = pdf_jbig2_decode(data)
        let rgba = pdf_image_mask_rgba(
          jbig2_width,
          jbig2_height,
          !invert,
          self.state.fill,
          jbig2_bits,
        )
        self.emit_image(
          pdf_png_encode_rgba(jbig2_width, jbig2_height, rgba),
        )
      } else {
        let (jbig2_width, jbig2_height, jbig2_rgb) = pdf_jbig2_rgb(data, invert)
        self.emit_image(
          pdf_png_encode_rgb(jbig2_width, jbig2_height, jbig2_rgb),
        )
      }
    }
    Some(_) => raise InvalidStream("unsupported PDF image filter")
    None =>
      if is_mask {
        if bpc != 1 {
          raise InvalidStream("PDF image masks must have one bit per pixel")
        }
        let rgba = pdf_image_mask_rgba(
          width,
          height,
          invert,
          self.state.fill,
          data,
        )
        self.emit_image(pdf_png_encode_rgba(width, height, rgba))
      } else {
        if bpc != 8 {
          raise InvalidStream(
            "PDF image bit depths other than 8 are not supported yet",
          )
        }
        let space = match space {
          Some(value) => value
          None => raise InvalidStream("PDF image color space is missing")
        }
        let rgb = pdf_image_rgb_samples(width, height, space, data)
        self.emit_image(pdf_png_encode_rgb(width, height, rgb))
      }
  }
}

///|
// Attach an encoded image and its mask through BDF group and mask commands,
// so JPEG data stays compressed instead of being decoded for compositing.
fn PdfGraphics::draw_encoded_masked_image(
  self : PdfGraphics,
  file : PdfFile,
  width : Int32,
  height : Int32,
  bpc : Int32,
  space : PdfDeviceColorSpace?,
  invert : Bool,
  data : Bytes,
  codec : Bytes?,
  soft_mask : PdfObject?,
  stencil_mask : PdfObject?,
) -> Unit raise PdfStreamError {
  match codec {
    Some(b"DCTDecode") | Some(b"JPXDecode") | Some(b"JBIG2Decode") => ()
    Some(_) =>
      raise InvalidStream(
        "PDF image masks with encoded image data are not supported yet",
      )
    None => raise InvalidStream("PDF image masks with encoded image data are not supported yet")
  }
  self.object.group_begin(1.0F, 0, 0.0F, 0.0F, 1.0F, 1.0F)
  self.draw_image_data(
    width, height, bpc, space, false, invert, data, codec, None,
  )
  match soft_mask {
    Some(value) => {
      let mask = pdf_load_soft_mask(file, value)
      self.object.mask_begin(1, 0x000000ffU, b"")
      self.emit_image(
        pdf_png_encode_rgb(
          mask.width,
          mask.height,
          pdf_soft_mask_rgb(mask),
        ),
      )
      self.object.mask_end()
    }
    None =>
      match stencil_mask {
        Some(PdfArray(_)) =>
          raise InvalidStream(
            "PDF encoded images with colour-key masks are not supported yet",
          )
        Some(value) => {
          let mask = pdf_load_stencil_mask(file, value)
          self.object.mask_begin(0, 0U, b"")
          self.emit_image(
            pdf_png_encode_rgba(
              mask.width,
              mask.height,
              pdf_stencil_mask_rgba(mask),
            ),
          )
          self.object.mask_end()
        }
        None => raise InvalidStream("PDF image mask is missing")
      }
  }
  self.object.group_end()
}

///|
fn PdfGraphics::draw_image_xobject(
  self : PdfGraphics,
  file : PdfFile,
  dict : PdfObject,
  raw : Bytes,
) -> Unit raise PdfStreamError {
  let is_mask = match file.page_deref(pdf_dict_get(dict, b"ImageMask")) {
    PdfBool(value) => value
    _ => false
  }
  let soft_mask = match pdf_dict_get(dict, b"SMask") {
    Some(PdfNull) | Some(PdfName(b"None")) | None => None
    Some(value) => Some(value)
  }
  let stencil_mask = match pdf_dict_get(dict, b"Mask") {
    Some(PdfNull) | Some(PdfName(b"None")) | None => None
    Some(value) => Some(value)
  }
  let decode : Array[Double] = match
    file.page_deref(pdf_dict_get(dict, b"Decode")) {
    PdfArray(values) =>
      values.map(fn(value) {
        match value {
          PdfInt(number) => number.to_double()
          PdfReal(number) => number
          _ => 0.0
        }
      })
    _ => []
  }
  let width = pdf_image_dimension(file, dict, b"Width", "width")
  let height = pdf_image_dimension(file, dict, b"Height", "height")
  let filters = file.resolved_stream_filters(dict)
  let ccitt_filter = pdf_ccitt_filter_index(filters) >= 0
  let bpc = match file.page_num(pdf_dict_get(dict, b"BitsPerComponent")) {
    Some(value) => value.to_int()
    None => if is_mask || ccitt_filter { 1 } else { 8 }
  }
  let space = if is_mask {
    None
  } else {
    match pdf_dict_get(dict, b"ColorSpace") {
      Some(value) => Some(file.resolve_device_color(value, 0))
      None => None
    }
  }
  let invert = !decode.is_empty() && decode[0] == 1.0
  let (data, codec) = pdf_decode_stream(
    raw,
    filters,
    1073741824L,
    false,
    1073741824L,
  )
  let ccitt = match codec {
    Some(b"CCITTFaxDecode") => Some(pdf_ccitt_params(file, dict))
    _ => None
  }
  let ccitt_decode_array = match codec {
    Some(b"CCITTFaxDecode") => decode.length() == 2
    _ => false
  }
  let jpx_decode_array = match codec {
    Some(b"JPXDecode") => decode.length() == 2
    _ => false
  }
  let jbig2_decode_array = match codec {
    Some(b"JBIG2Decode") => decode.length() == 2
    _ => false
  }
  if !is_mask &&
    !decode.is_empty() &&
    !ccitt_decode_array &&
    !jpx_decode_array &&
    !jbig2_decode_array {
    raise InvalidStream("PDF image Decode arrays are not supported yet")
  }
  let has_attachment = match (soft_mask, stencil_mask) {
    (Some(_), _) | (_, Some(_)) => true
    _ => false
  }
  if !is_mask && has_attachment {
    let encoded = match codec {
      Some(_) => true
      None => false
    }
    if encoded {
      self.draw_encoded_masked_image(
        file,
        width,
        height,
        bpc,
        space,
        invert,
        data,
        codec,
        soft_mask,
        stencil_mask,
      )
      return
    }
    if bpc != 8 {
      raise InvalidStream(
        "PDF image masks with this bit depth are not supported yet",
      )
    }
    let space = match space {
      Some(value) => value
      None => raise InvalidStream("PDF image color space is missing")
    }
    let rgb = pdf_image_rgb_samples(width, height, space, data)
    let rgba = pdf_image_rgba_from_rgb(width, height, rgb)
    let masked = match soft_mask {
      Some(value) =>
        pdf_apply_image_mask(
          rgba,
          width,
          height,
          pdf_load_soft_mask(file, value),
        )
      None =>
        match stencil_mask {
          Some(PdfArray(values)) => {
            let key : Array[Double] = []
            for value in values {
              match file.page_num(Some(value)) {
                Some(number) => key.push(number)
                None => raise InvalidStream("invalid PDF colour key mask")
              }
            }
            pdf_apply_image_alpha(
              rgba,
              pdf_color_key_alpha(width, height, space, data, key),
            )
          }
          Some(value) =>
            pdf_apply_image_mask(
              rgba,
              width,
              height,
              pdf_load_stencil_mask(file, value),
            )
          None => raise InvalidStream("PDF image mask is missing")
        }
    }
    self.emit_image(pdf_png_encode_rgba(width, height, masked))
  } else {
    self.draw_image_data(
      width, height, bpc, space, is_mask, invert, data, codec, ccitt,
    )
  }
}

///|
fn pdf_form_numbers(
  file : PdfFile,
  dict : PdfObject,
  key : Bytes,
  count : Int32,
) -> Array[Double]? raise PdfStreamError {
  match file.page_deref(pdf_dict_get(dict, key)) {
    PdfNull => None
    PdfArray(values) if values.length() == count => {
      let out : Array[Double] = []
      for value in values {
        match file.page_num(Some(value)) {
          Some(number) => out.push(number)
          None => raise InvalidStream("invalid PDF form array")
        }
      }
      Some(out)
    }
    _ => raise InvalidStream("invalid PDF form array")
  }
}

///|
fn PdfGraphics::draw_form_xobject(
  self : PdfGraphics,
  file : PdfFile,
  dict : PdfObject,
  raw : Bytes,
) -> Unit raise PdfStreamError {
  if self.form_depth >= 16 {
    raise InvalidStream("PDF form XObject nesting limit")
  }
  let group = match file.page_deref(pdf_dict_get(dict, b"Group")) {
    PdfNull => None
    PdfDict(_) => Some(file.page_deref(pdf_dict_get(dict, b"Group")))
    _ => raise InvalidStream("invalid PDF form group")
  }
  let group_style = match group {
    Some(value) => {
      match file.page_deref(pdf_dict_get(value, b"S")) {
        PdfName(b"Transparency") => ()
        _ => raise InvalidStream("unsupported PDF form group")
      }
      let alpha = match file.page_num(pdf_dict_get(value, b"ca")) {
        Some(number) => Double::min(1.0, Double::max(0.0, number))
        None => 1.0
      }
      let blend = match file.page_deref(pdf_dict_get(value, b"BM")) {
        PdfName(name) => pdf_blend_mode(name)
        PdfArray(values) if !values.is_empty() =>
          match file.page_deref(Some(values[0])) {
            PdfName(name) => pdf_blend_mode(name)
            _ => 0
          }
        _ => 0
      }
      Some((alpha, blend))
    }
    None => None
  }
  let matrix = pdf_form_numbers(file, dict, b"Matrix", 6)
  let bbox = pdf_form_numbers(file, dict, b"BBox", 4)
  let identity = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
  let placed_matrix = match matrix {
    Some(values) =>
      (values[0], values[1], values[2], values[3], values[4], values[5])
    None => identity
  }
  let group_bounds = match group_style {
    Some(_) =>
      match bbox {
        Some(values) =>
          Some(
            pdf_transform_rect(
              placed_matrix,
              (values[0], values[1], values[2], values[3]),
            ),
          )
        None => None
      }
    None => None
  }
  let old_resources = self.resources
  match pdf_dict_get(dict, b"Resources") {
    Some(value) => self.resources = Some(file.page_deref(Some(value)))
    None => ()
  }
  defer {
    self.form_depth -= 1
    self.resources = old_resources
  }
  self.form_depth += 1
  let depth = self.stack.length()
  self.save()
  let mut grouped = false
  match (group_style, group_bounds) {
    (Some((alpha, blend)), Some((x, y, width, height))) => {
      self.object.group_begin(
        Float::from_double(alpha),
        blend,
        Float::from_double(x),
        Float::from_double(y),
        Float::from_double(width),
        Float::from_double(height),
      )
      grouped = true
    }
    _ => ()
  }
  match matrix {
    Some(values) =>
      self.transform(
        (values[0], values[1], values[2], values[3], values[4], values[5]),
      )
    None => ()
  }
  match bbox {
    Some(values) => {
      let width = values[2] - values[0]
      let height = values[3] - values[1]
      if width > 0.0 && height > 0.0 {
        self.object.clip_rect(
          Float::from_double(values[0]),
          Float::from_double(values[1]),
          Float::from_double(width),
          Float::from_double(height),
        )
      }
    }
    None => ()
  }
  self.run_ops(raw)
  self.finish_text()
  if self.mask_group_active && self.mask_group_level > depth {
    self.close_mask_group()
  }
  while self.stack.length() > depth + 1 {
    self.restore()
  }
  if grouped {
    self.object.group_end()
  }
  self.restore()
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
    PdfName(b"Form") => {
      let raw = match loaded.stream {
        Some(value) => value
        None => raise InvalidStream("PDF form stream is missing")
      }
      self.draw_form_xobject(file, loaded.value, raw)
    }
    _ => raise InvalidStream("unsupported PDF XObject")
  }
}

///|
fn PdfGraphics::execute(
  self : PdfGraphics,
  operator : Bytes,
  args : Array[ContentValue],
) -> Unit raise PdfStreamError {
  match operator {
    b"BX" => {
      self.compatibility += 1
      return
    }
    b"EX" => {
      if self.compatibility > 0 {
        self.compatibility -= 1
      }
      return
    }
    b"BDC" => {
      let count = args.length()
      if count >= 2 && !self.property_visible(args[count - 1]) {
        self.hidden += 1
      }
      return
    }
    b"BMC" => return
    b"EMC" => {
      if self.hidden > 0 {
        self.hidden -= 1
      }
      return
    }
    b"MP" | b"DP" => return
    b"d0" | b"d1" => return
    _ => ()
  }
  if self.hidden > 0 {
    return
  }
  if operator != b"Q" && operator != b"gs" && operator != b"q" {
    self.ensure_mask_group()
  }
  if self.text_operator(operator, args) {
    return
  }
  if self.text.state.in_text {
    match operator {
      b"gs"
      | b"Do"
      | b"sh"
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
      _ =>
        if self.compatibility == 0 {
          raise InvalidStream(
            "unsupported operator in PDF text object: " +
            @utf8.decode_lossy(operator[:]),
          )
        }
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
          Name(name) => {
            self.close_mask_group()
            self.apply_ext_state(name)
          }
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
    b"sh" =>
      if n >= 1 {
        match args[n - 1] {
          Name(name) => self.paint_shading(name)
          _ => ()
        }
      }
    b"q" => self.save()
    b"Q" => {
      if self.mask_group_active && self.stack.length() == self.mask_group_level {
        self.close_mask_group()
      }
      self.restore()
    }
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
        self.state.stroke_pattern = None
      } else {
        self.state.fill = color
        self.state.fill_space = PdfGray
        self.state.fill_pattern = None
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
          self.state.stroke_pattern = None
        } else {
          self.state.fill = color
          self.state.fill_space = PdfRGB
          self.state.fill_pattern = None
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
          self.state.stroke_pattern = None
        } else {
          self.state.fill = color
          self.state.fill_space = PdfCMYK
          self.state.fill_pattern = None
        }
      }
    b"CS" | b"cs" =>
      if n >= 1 {
        let space = self.resolve_color_space(args[n - 1])
        if operator == b"CS" {
          self.state.stroke_space = space
          self.state.stroke = 0x000000ffU
          self.state.stroke_pattern = None
        } else {
          self.state.fill_space = space
          self.state.fill = 0x000000ffU
          self.state.fill_pattern = None
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
      let mut pattern : Bytes? = None
      for arg in args {
        match arg {
          Integer(value) => values.push(value.to_double())
          Real(value) => values.push(value)
          Name(name) => pattern = Some(name)
          _ => ()
        }
      }
      match pattern {
        Some(name) => {
          match space {
            PdfPattern => ()
            _ =>
              raise InvalidStream(
                "PDF pattern used outside a Pattern colour space",
              )
          }
          if stroke {
            self.state.stroke_pattern = Some(name)
          } else {
            self.state.fill_pattern = Some(name)
          }
        }
        None => {
          match space {
            PdfPattern =>
              raise InvalidStream(
                "PDF Pattern colour space requires a pattern name",
              )
            _ => ()
          }
          let color = pdf_device_color(space, values)
          if stroke {
            self.state.stroke = color
            self.state.stroke_pattern = None
          } else {
            self.state.fill = color
            self.state.fill_pattern = None
          }
        }
      }
    }
    b"W" => self.clip = 0
    b"W*" => self.clip = 1
    b"S" =>
      self.end_path(false, 0, true) catch {
        InvalidStream(message) => raise InvalidStream(message)
        _ => raise InvalidStream("PDF path output failed")
      }
    b"s" => {
      self.path.close()
      self.end_path(false, 0, true) catch {
        InvalidStream(message) => raise InvalidStream(message)
        _ => raise InvalidStream("PDF path output failed")
      }
    }
    b"f" | b"F" =>
      self.end_path(true, 0, false) catch {
        InvalidStream(message) => raise InvalidStream(message)
        _ => raise InvalidStream("PDF path output failed")
      }
    b"f*" =>
      self.end_path(true, 1, false) catch {
        InvalidStream(message) => raise InvalidStream(message)
        _ => raise InvalidStream("PDF path output failed")
      }
    b"B" =>
      self.end_path(true, 0, true) catch {
        InvalidStream(message) => raise InvalidStream(message)
        _ => raise InvalidStream("PDF path output failed")
      }
    b"B*" =>
      self.end_path(true, 1, true) catch {
        InvalidStream(message) => raise InvalidStream(message)
        _ => raise InvalidStream("PDF path output failed")
      }
    b"b" => {
      self.path.close()
      self.end_path(true, 0, true) catch {
        InvalidStream(message) => raise InvalidStream(message)
        _ => raise InvalidStream("PDF path output failed")
      }
    }
    b"b*" => {
      self.path.close()
      self.end_path(true, 1, true) catch {
        InvalidStream(message) => raise InvalidStream(message)
        _ => raise InvalidStream("PDF path output failed")
      }
    }
    b"n" =>
      self.end_path(false, 0, false) catch {
        InvalidStream(message) => raise InvalidStream(message)
        _ => raise InvalidStream("PDF path output failed")
      }
    b"ri" | b"i" => ()
    _ =>
      if self.compatibility == 0 {
        raise InvalidStream(
          "unsupported PDF graphics operator: " +
          @utf8.decode_lossy(operator[:]),
        )
      }
  }
}

///|
fn PdfGraphics::run_ops(
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
        if op == b"BI" {
          self.inline_image(lexer)
        } else {
          self.execute(op, args)
        }
        args.clear()
      }
    }
  }
}

///|
fn PdfGraphics::run(
  self : PdfGraphics,
  content : Bytes,
) -> Unit raise PdfStreamError {
  self.run_ops(content)
  self.finish_text()
  self.close_mask_group()
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
) -> (
  PdfPageGeometry,
  Bytes,
  Array[Bytes],
  Array[String],
  Array[Bytes],
  Array[Bytes],
  Array[String],
) raise PdfStreamError {
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
    file=Some(self),
    resources=page.attrs.resources,
    optional_content=pdf_optional_content(self),
  )
  graphics.run(content)
  graphics.draw_annotations(page.dict, geometry.matrix)
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
  (
    geometry,
    encoded,
    graphics.children,
    identities,
    graphics.images,
    graphics.font_parts,
    graphics.warnings,
  )
}

///|
fn PdfFile::graphics_page(
  self : PdfFile,
  page : PdfPageLeaf,
  which : String,
) -> (PdfPageGeometry, Bytes) raise PdfStreamError {
  let (geometry, encoded, children, _, images, fonts, _) = self.graphics_page_parts(
    page, which,
  )
  if !children.is_empty() || !images.is_empty() || !fonts.is_empty() {
    raise InvalidStream(
      "PDF page contains child objects and requires document context",
    )
  }
  (geometry, encoded)
}
