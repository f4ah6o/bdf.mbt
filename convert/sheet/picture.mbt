///|
/// A picture to paint over a sized grid. Cell coordinates are zero-based and
/// lengths use BDF points. `kind` is 0 for the rectangle between `from` and
/// `to`, 1 for a rectangle of `width` and `height` at `from`, and 2 for an
/// absolute rectangle at (`x`, `y`). The image bytes are stored as a BDF part.
pub(all) struct GridPicture {
  kind : Int32
  from_row : Int32
  from_column : Int32
  to_row : Int32
  to_column : Int32
  from_x_offset : Double
  from_y_offset : Double
  to_x_offset : Double
  to_y_offset : Double
  x : Double
  y : Double
  width : Double
  height : Double
  description : String
  image : Bytes
  alpha : Float?
  fill_left : Double
  fill_top : Double
  fill_right : Double
  fill_bottom : Double
  crop_left : Double
  crop_top : Double
  crop_right : Double
  crop_bottom : Double
  image_width : Double
  image_height : Double
  flip_horizontal : Bool
  flip_vertical : Bool
  rotation : Int32
  frame_width : Double
  frame_height : Double
}

///|
fn GridDrawContext::paint_picture(
  self : GridDrawContext,
  writer : @core.DocumentWriter,
  picture : GridPicture,
  rows : Array[Double],
  columns : Array[Double],
  view_width : Double,
  pending : Array[(Int32, Int32, Bytes)]?,
  room : Int32,
  hidden~ : Bool = false,
  shape_fill~ : UInt32? = None,
  shape_stroke~ : (UInt32, Double)? = None,
) -> Int32 raise {
  if picture.kind < 0 ||
    picture.kind > 2 ||
    picture.rotation < -86400000 ||
    picture.rotation > 86400000 ||
    picture.x.is_nan() ||
    picture.x.is_inf() ||
    picture.y.is_nan() ||
    picture.y.is_inf() ||
    picture.width.is_nan() ||
    picture.width.is_inf() ||
    picture.height.is_nan() ||
    picture.height.is_inf() ||
    picture.from_x_offset.is_nan() ||
    picture.from_x_offset.is_inf() ||
    picture.from_y_offset.is_nan() ||
    picture.from_y_offset.is_inf() ||
    picture.to_x_offset.is_nan() ||
    picture.to_x_offset.is_inf() ||
    picture.to_y_offset.is_nan() ||
    picture.to_y_offset.is_inf() {
    raise InvalidArgument("sheet: invalid picture geometry")
  }
  for
    inset in [
      picture.fill_left,
      picture.fill_top,
      picture.fill_right,
      picture.fill_bottom,
    ] {
    if inset.is_nan() || inset.is_inf() || inset < 0.0 || inset > 1.0 {
      raise InvalidArgument("sheet: invalid picture inset")
    }
  }
  if picture.fill_left + picture.fill_right > 1.0 ||
    picture.fill_top + picture.fill_bottom > 1.0 {
    raise InvalidArgument("sheet: invalid picture inset")
  }
  for
    crop in [
      picture.crop_left,
      picture.crop_top,
      picture.crop_right,
      picture.crop_bottom,
    ] {
    if crop.is_nan() || crop.is_inf() || crop < -1.0 || crop >= 1.0 {
      raise InvalidArgument("sheet: invalid picture crop")
    }
  }
  if picture.crop_left + picture.crop_right >= 1.0 ||
    picture.crop_top + picture.crop_bottom >= 1.0 {
    raise InvalidArgument("sheet: invalid picture crop")
  }
  let cropped = picture.crop_left != 0.0 ||
    picture.crop_top != 0.0 ||
    picture.crop_right != 0.0 ||
    picture.crop_bottom != 0.0
  if cropped &&
    (
      picture.image_width <= 0.0 ||
      picture.image_height <= 0.0 ||
      picture.image_width.is_nan() ||
      picture.image_height.is_nan() ||
      picture.image_width.is_inf() ||
      picture.image_height.is_inf()
    ) {
    raise InvalidArgument("sheet: invalid picture size")
  }
  if picture.frame_width.is_nan() ||
    picture.frame_width.is_inf() ||
    picture.frame_height.is_nan() ||
    picture.frame_height.is_inf() ||
    picture.frame_width < 0.0 ||
    picture.frame_height < 0.0 ||
    (picture.frame_width == 0.0) != (picture.frame_height == 0.0) {
    raise InvalidArgument("sheet: invalid picture transform frame")
  }
  if shape_stroke is Some((_, width)) {
    if shape_fill is None ||
      width.is_nan() ||
      width.is_inf() ||
      width <= 0.0 ||
      width > 20000.0 {
      raise InvalidArgument("sheet: invalid shape line width")
    }
  }
  if picture.alpha is Some(alpha) {
    if alpha.is_nan() || alpha.is_inf() || alpha < 0.0F || alpha > 1.0F {
      raise InvalidArgument("sheet: invalid picture alpha")
    }
  }
  if picture.kind == 0 || picture.kind == 1 {
    if picture.from_row < 0 ||
      picture.from_row >= rows.length() - 1 ||
      picture.from_column < 0 ||
      picture.from_column >= columns.length() - 1 {
      raise InvalidArgument("sheet: picture anchor is outside the sheet")
    }
  }
  if picture.kind == 0 &&
    (
      picture.to_row < picture.from_row ||
      picture.to_row >= rows.length() - 1 ||
      picture.to_column < picture.from_column ||
      picture.to_column >= columns.length() - 1
    ) {
    raise InvalidArgument("sheet: picture anchor is outside the sheet")
  }
  let (x, y, width, height) = if picture.kind == 0 {
    let x = columns[picture.from_column] +
      Double::min(
        picture.from_x_offset,
        columns[picture.from_column + 1] - columns[picture.from_column],
      )
    let y = rows[picture.from_row] +
      Double::min(
        picture.from_y_offset,
        rows[picture.from_row + 1] - rows[picture.from_row],
      )
    let x1 = columns[picture.to_column] +
      Double::min(
        picture.to_x_offset,
        columns[picture.to_column + 1] - columns[picture.to_column],
      )
    let y1 = rows[picture.to_row] +
      Double::min(
        picture.to_y_offset,
        rows[picture.to_row + 1] - rows[picture.to_row],
      )
    (x, y, x1 - x, y1 - y)
  } else if picture.kind == 1 {
    (
      columns[picture.from_column] +
      Double::min(
        picture.from_x_offset,
        columns[picture.from_column + 1] - columns[picture.from_column],
      ),
      rows[picture.from_row] +
      Double::min(
        picture.from_y_offset,
        rows[picture.from_row + 1] - rows[picture.from_row],
      ),
      picture.width,
      picture.height,
    )
  } else {
    (picture.x, picture.y, picture.width, picture.height)
  }
  if x.is_nan() ||
    x.is_inf() ||
    y.is_nan() ||
    y.is_inf() ||
    width.is_nan() ||
    width.is_inf() ||
    height.is_nan() ||
    height.is_inf() {
    raise InvalidArgument("sheet: invalid picture geometry")
  }
  if width < 0.0 || height < 0.0 {
    return 0
  }
  let margin = Double::max(width, height) * 0.5 + 8.0
  if view_width.is_nan() ||
    view_width.is_inf() ||
    self.height.is_nan() ||
    self.height.is_inf() {
    raise InvalidArgument("sheet: invalid picture view dimensions")
  }
  let x0 = Double::max(x - margin, 0.0)
  let y0 = Double::max(y - margin, 0.0)
  let x1 = Double::min(x + width + margin, view_width)
  let y1 = Double::min(y + height + margin, self.height)
  let max_coordinate = 2147483647.0 * 2048.0
  if x1 > max_coordinate || y1 > max_coordinate {
    raise InvalidArgument("sheet: picture tile coordinates are too large")
  }
  let mut tile_count = 0
  if x0 < x1 && y0 < y1 {
    let nx = (x1 / 2048.0).ceil() - (x0 / 2048.0).floor()
    let ny = (y1 / 2048.0).ceil() - (y0 / 2048.0).floor()
    if nx * ny > room.to_double() {
      raise InvalidArgument("sheet: drawings exceed the supported tile budget")
    }
    tile_count = (nx * ny).to_int()
  }
  if hidden {
    let empty = @core.ObjectBuilder::new().encode()
    if pending is Some(pending) {
      pending.push((-1 - self.tiles.length(), -1, empty))
    } else {
      ignore(writer.add_part("obj", empty))
    }
    return tile_count
  }
  let image_hash = if shape_fill is Some(_) {
    ""
  } else {
    writer.add_part("img", picture.image)
  }
  let object = @core.ObjectBuilder::new()
  let bbox = (
    Float::from_double(-margin),
    Float::from_double(-margin),
    Float::from_double(width + 2.0 * margin),
    Float::from_double(height + 2.0 * margin),
  )
  object.set_bbox(bbox.0, bbox.1, bbox.2, bbox.3)
  if picture.description != "" {
    object.mark(10, picture.description)
  }
  let mut draw_width = width
  let mut draw_height = height
  let mut origin_x = 0.0
  let mut origin_y = 0.0
  if picture.frame_width > 0.0 {
    let sx = width / picture.frame_width
    let sy = height / picture.frame_height
    let center_x = picture.frame_width * sx / 2.0
    let center_y = picture.frame_height * sy / 2.0
    let angle = (if picture.rotation < 0 {
        -picture.rotation
      } else {
        picture.rotation
      }) %
      10800000
    let sideways = angle > 2700000 && angle < 8100000
    draw_width = picture.frame_width * (if sideways { sy } else { sx })
    draw_height = picture.frame_height * (if sideways { sx } else { sy })
    origin_x = center_x - draw_width / 2.0
    origin_y = center_y - draw_height / 2.0
  }
  if draw_width.is_nan() ||
    draw_width.is_inf() ||
    draw_height.is_nan() ||
    draw_height.is_inf() ||
    origin_x.is_nan() ||
    origin_x.is_inf() ||
    origin_y.is_nan() ||
    origin_y.is_inf() {
    raise InvalidArgument("sheet: invalid picture transform frame")
  }
  object.save()
  if picture.rotation != 0 {
    let radians = picture.rotation.to_double() / 60000.0 * @math.PI / 180.0
    let sin = @math.sin(radians)
    let cos = @math.cos(radians)
    let fh = if picture.flip_horizontal { -1.0 } else { 1.0 }
    let fv = if picture.flip_vertical { -1.0 } else { 1.0 }
    let a = cos * fh
    let b = sin * fh
    let c = -sin * fv
    let d = cos * fv
    let e = a * (-draw_width / 2.0) +
      c * (-draw_height / 2.0) +
      origin_x +
      draw_width / 2.0
    let f = b * (-draw_width / 2.0) +
      d * (-draw_height / 2.0) +
      origin_y +
      draw_height / 2.0
    object.transform(
      Float::from_double(a),
      Float::from_double(b),
      Float::from_double(c),
      Float::from_double(d),
      Float::from_double(e),
      Float::from_double(f),
    )
  } else if picture.flip_horizontal || picture.flip_vertical {
    object.transform(
      if picture.flip_horizontal {
        -1.0F
      } else {
        1.0F
      },
      0.0F,
      0.0F,
      if picture.flip_vertical {
        -1.0F
      } else {
        1.0F
      },
      if picture.flip_horizontal {
        Float::from_double(origin_x + draw_width)
      } else {
        Float::from_double(origin_x)
      },
      if picture.flip_vertical {
        Float::from_double(origin_y + draw_height)
      } else {
        Float::from_double(origin_y)
      },
    )
  } else if origin_x != 0.0 || origin_y != 0.0 {
    object.translate(Float::from_double(origin_x), Float::from_double(origin_y))
  }
  let path : @core.Path = {
    verbs: b"\x00\x01\x01\x01\x04",
    coordinates: [
      0.0, 0.0, draw_width, 0.0, draw_width, draw_height, 0.0, draw_height,
    ],
  }
  let path_index = object.add_path(@core.Inline(path))
  if shape_fill is Some(color) {
    object.fill_color(color)
    object.fill_path(path_index, 0)
    if shape_stroke is Some((stroke, width)) {
      object.save()
      object.line(Float::from_double(width), 0, 0, 8.0F)
      object.stroke_color(stroke)
      object.stroke_path(path_index)
      object.restore()
    }
  } else {
    object.save()
    object.clip_path(path_index, 0)
    let image_index = object.add_image(image_hash)
    if picture.alpha is Some(alpha) {
      object.alpha(alpha)
    }
    let dx = picture.fill_left * draw_width
    let dy = picture.fill_top * draw_height
    let dw = draw_width * (1.0 - picture.fill_left - picture.fill_right)
    let dh = draw_height * (1.0 - picture.fill_top - picture.fill_bottom)
    if cropped {
      let u0 = picture.crop_left * picture.image_width
      let u1 = (1.0 - picture.crop_right) * picture.image_width
      let v0 = picture.crop_top * picture.image_height
      let v1 = (1.0 - picture.crop_bottom) * picture.image_height
      let cu0 = Double::max(u0, 0.0)
      let cu1 = Double::min(u1, picture.image_width)
      let cv0 = Double::max(v0, 0.0)
      let cv1 = Double::min(v1, picture.image_height)
      // Go fuses the products and sums while computing destination coordinates.
      let dx0 = @core.fused_multiply_add(
        @core.fused_multiply_add(-picture.crop_left, picture.image_width, cu0) /
        (u1 - u0),
        dw,
        dx,
      )
      let dx1 = @core.fused_multiply_add(
        @core.fused_multiply_add(-picture.crop_left, picture.image_width, cu1) /
        (u1 - u0),
        dw,
        dx,
      )
      let dy0 = @core.fused_multiply_add(
        @core.fused_multiply_add(-picture.crop_top, picture.image_height, cv0) /
        (v1 - v0),
        dh,
        dy,
      )
      let dy1 = @core.fused_multiply_add(
        @core.fused_multiply_add(-picture.crop_top, picture.image_height, cv1) /
        (v1 - v0),
        dh,
        dy,
      )
      object.image_sub(
        image_index,
        Float::from_double(cu0),
        Float::from_double(cv0),
        Float::from_double(cu1 - cu0),
        Float::from_double(cv1 - cv0),
        Float::from_double(dx0),
        Float::from_double(dy0),
        Float::from_double(dx1 - dx0),
        Float::from_double(dy1 - dy0),
      )
    } else {
      object.image(
        image_index,
        Float::from_double(dx),
        Float::from_double(dy),
        Float::from_double(dw),
        Float::from_double(dh),
      )
    }
    object.restore()
  }
  object.restore()
  if picture.description != "" {
    object.mark(11, "")
  }
  let encoded = object.encode()
  let hash = if pending is Some(_) {
    @core.DocumentWriter::new().add_part("obj", encoded)
  } else {
    writer.add_part("obj", encoded)
  }
  let tiles : Array[DrawTile] = []
  if x0 < x1 && y0 < y1 {
    for ty in (y0 / 2048.0).to_int()..<(y1 / 2048.0).ceil().to_int() {
      for tx in (x0 / 2048.0).to_int()..<(x1 / 2048.0).ceil().to_int() {
        tiles.push(self.tile(tx, ty))
      }
    }
  }
  if pending is Some(pending) {
    let mut first_x = -1
    let mut first_y = -1
    let wanted : Map[String, Bool] = Map([])
    for tile in tiles {
      wanted["\{tile.x},\{tile.y}"] = true
    }
    for existing in self.tiles {
      if first_x < 0 && wanted.contains("\{existing.x},\{existing.y}") {
        first_x = existing.x
        first_y = existing.y
      }
    }
    if first_x < 0 {
      first_x = -1 - self.tiles.length()
    }
    pending.push((first_x, first_y, encoded))
  }
  for tile in tiles {
    let index = tile.object.add_object(hash, bbox)
    tile.object.use_object_at(
      index,
      Float::from_double(x - tile.x.to_double() * 2048.0),
      Float::from_double(y - tile.y.to_double() * 2048.0),
    )
    tile.drawn = true
  }
  tile_count
}
