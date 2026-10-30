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
  x : Double
  y : Double
  width : Double
  height : Double
  description : String
  image : Bytes
}

///|
fn GridDrawContext::paint_picture(
  self : GridDrawContext,
  writer : @core.DocumentWriter,
  picture : GridPicture,
  rows : Array[Double],
  columns : Array[Double],
) -> Unit raise {
  if picture.kind < 0 ||
    picture.kind > 2 ||
    picture.x.is_nan() ||
    picture.x.is_inf() ||
    picture.y.is_nan() ||
    picture.y.is_inf() ||
    picture.width.is_nan() ||
    picture.width.is_inf() ||
    picture.height.is_nan() ||
    picture.height.is_inf() {
    raise InvalidArgument("sheet: invalid picture geometry")
  }
  if picture.kind == 0 || picture.kind == 1 {
    if picture.from_row < 0 ||
      picture.from_row >= rows.length() ||
      picture.from_column < 0 ||
      picture.from_column >= columns.length() {
      raise InvalidArgument("sheet: picture anchor is outside the sheet")
    }
  }
  if picture.kind == 0 &&
    (
      picture.to_row < picture.from_row ||
      picture.to_row >= rows.length() ||
      picture.to_column < picture.from_column ||
      picture.to_column >= columns.length()
    ) {
    raise InvalidArgument("sheet: picture anchor is outside the sheet")
  }
  if picture.kind == 2 && (picture.x < 0.0 || picture.y < 0.0) {
    raise InvalidArgument("sheet: invalid picture position")
  }
  for position in rows {
    if position.is_nan() ||
      position.is_inf() ||
      position * 4.0 != (position * 4.0).trunc() {
      raise InvalidArgument(
        "sheet: pictures with fractional row heights are not supported",
      )
    }
  }
  let (x, y, width, height) = if picture.kind == 0 {
    let x = columns[picture.from_column]
    let y = rows[picture.from_row]
    (x, y, columns[picture.to_column] - x, rows[picture.to_row] - y)
  } else if picture.kind == 1 {
    (
      columns[picture.from_column],
      rows[picture.from_row],
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
    return
  }
  let margin = Double::max(width, height) * 0.5 + 8.0
  if x + width + margin > 2048.0 || y + height + margin > 2048.0 {
    raise InvalidArgument(
      "sheet: pictures spanning multiple tiles are not supported",
    )
  }
  for tile in self.tiles {
    if tile.x != 0 || tile.y != 0 {
      raise InvalidArgument(
        "sheet: pictures with multiple tiles are not supported",
      )
    }
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
  object.image(
    image_index,
    0.0F,
    0.0F,
    Float::from_double(width),
    Float::from_double(height),
  )
  object.restore()
  object.restore()
  if picture.description != "" {
    object.mark(11, "")
  }
  let hash = writer.add_part("obj", object.encode())
  let tiles = self.in_bounds(
    x - margin,
    y - margin,
    x + width + margin,
    y + height + margin,
  )
  if tiles.length() > 16384 {
    raise InvalidArgument("sheet: drawings exceed the supported tile budget")
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
}
