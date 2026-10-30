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
) -> Int32 raise {
  if picture.kind < 0 ||
    picture.kind > 2 ||
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
    picture.from_x_offset < 0.0 ||
    picture.from_y_offset.is_nan() ||
    picture.from_y_offset.is_inf() ||
    picture.from_y_offset < 0.0 ||
    picture.to_x_offset.is_nan() ||
    picture.to_x_offset.is_inf() ||
    picture.to_x_offset < 0.0 ||
    picture.to_y_offset.is_nan() ||
    picture.to_y_offset.is_inf() ||
    picture.to_y_offset < 0.0 {
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
  if picture.kind == 2 && (picture.x < 0.0 || picture.y < 0.0) {
    raise InvalidArgument("sheet: invalid picture position")
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
  let image_hash = writer.add_part("img", picture.image)
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
  object.save()
  object.save()
  let path : @core.Path = {
    verbs: b"\x00\x01\x01\x01\x04",
    coordinates: [0.0, 0.0, width, 0.0, width, height, 0.0, height],
  }
  let path_index = object.add_path(@core.Inline(path))
  object.clip_path(path_index, 0)
  let image_index = object.add_image(image_hash)
  if picture.alpha is Some(alpha) {
    object.alpha(alpha)
  }
  object.image(
    image_index,
    Float::from_double(picture.fill_left * width),
    Float::from_double(picture.fill_top * height),
    Float::from_double(width * (1.0 - picture.fill_left - picture.fill_right)),
    Float::from_double(height * (1.0 - picture.fill_top - picture.fill_bottom)),
  )
  object.restore()
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
