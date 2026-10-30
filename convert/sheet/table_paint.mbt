///|
fn DrawTile::rectangle(
  self : DrawTile,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  self.object.fill_rect(
    Float::from_double(x - self.x.to_double() * 2048.0),
    Float::from_double(y - self.y.to_double() * 2048.0),
    Float::from_double(w),
    Float::from_double(h),
  )
  self.drawn = true
}

///|
fn GridDrawContext::table_fill(
  self : GridDrawContext,
  color : UInt32,
  x1 : Double,
  y0 : Double,
  y1 : Double,
) -> Unit {
  if color == 0U || y0 >= y1 {
    return
  }
  for tile in self.in_bounds(0.0, y0, x1, y1) {
    tile.fill_color(color)
    tile.rectangle(0.0, y0, x1, y1 - y0)
  }
}

///|
fn GridDrawContext::paint_table_fills(
  self : GridDrawContext,
  style : GridStyle,
  row_count : Int32,
  column_count : Int32,
  header : Int32,
  columns : Array[Double],
  rows : Array[Double],
) -> Unit {
  let mut previous : UInt32 = 0U
  let mut start = 0.0
  for row in 0..<row_count {
    let color = style.at(row, 0, row_count, column_count, header).fill
    if color != previous {
      self.table_fill(previous, columns[column_count], start, rows[row])
      previous = color
      start = rows[row]
    }
  }
  self.table_fill(previous, columns[column_count], start, rows[row_count])
}

///|
fn GridDrawContext::paint_table_buttons(
  self : GridDrawContext,
  count : Int32,
  columns : Array[Double],
  rows : Array[Double],
) -> Unit raise {
  for column in 0..<count {
    let w = columns[column + 1] - columns[column]
    let h = rows[1] - rows[0]
    self.paint_filter_button(columns[column], rows[0], w, h)
  }
}

///|
fn GridDrawContext::paint_filter_button(
  self : GridDrawContext,
  left : Double,
  top : Double,
  w : Double,
  h : Double,
) -> Unit raise {
  let size = Double::min(12.0, Double::min(h - 0.75, w))
  if size <= 2.0 {
    return
  }
  let x = left + w - size - 0.375
  let y = top + h - size - 0.375
  for tile in self.in_bounds(x, y, x + size, y + size) {
    tile.fill_color(0xf4f4f4ffU)
    tile.rectangle(x, y, size, size)
    tile.object.line(0.75F, 0, 0, 10.0F)
    tile.object.stroke_color(0xa6a6a6ffU)
    let ox = tile.x.to_double() * 2048.0
    let oy = tile.y.to_double() * 2048.0
    tile.object.stroke_rect(
      Float::from_double(x - ox + 0.375),
      Float::from_double(y - oy + 0.375),
      Float::from_double(size - 0.75),
      Float::from_double(size - 0.75),
    )
    let cx = x + size / 2.0 - ox
    let cy = y + size / 2.0 - oy
    let width = size * 0.28
    let path : @core.Path = {
      verbs: b"\x00\x01\x01\x04",
      coordinates: [
        cx - width,
        cy - width / 2.0,
        cx + width,
        cy - width / 2.0,
        cx,
        cy + width / 2.0,
      ],
    }
    tile.fill_color(0x404040ffU)
    let index = tile.object.add_path(@core.Inline(path))
    tile.object.fill_path(index, 0)
    tile.drawn = true
  }
}
