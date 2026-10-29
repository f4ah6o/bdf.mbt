///|
priv struct GridStyleBorder {
  weight : Int32
  color : UInt32
}

///|
priv struct GridStyleRegion {
  fill : UInt32
  color : UInt32
  bold : Bool
  size : Int32
  borders : Array[GridStyleBorder]
}

///|
priv struct GridStyle {
  whole : GridStyleRegion
  first : GridStyleRegion
  second : GridStyleRegion
  header : GridStyleRegion
}

///|
priv struct GridCellStyle {
  mut fill : UInt32
  mut color : UInt32
  mut bold : Bool
  borders : Array[GridStyleBorder]
}

///|
/// Whether a name identifies one of the built-in Excel table styles.
/// The `TableStyle` prefix and ASCII case are optional.
pub fn is_builtin_table_style(name : String) -> Bool {
  grid_builtin_style(name) is Some(_)
}

///|
fn GridCellStyle::apply_region(
  self : GridCellStyle,
  region : GridStyleRegion,
  top : Bool,
  bottom : Bool,
  left : Bool,
  right : Bool,
) -> Unit {
  if region.fill != 0U {
    self.fill = region.fill
  }
  if region.color != 0U {
    self.color = region.color
  }
  if region.bold {
    self.bold = true
  }
  if region.borders.length() != 6 {
    return
  }
  let sides = [
    if top {
      0
    } else {
      4
    },
    if bottom {
      1
    } else {
      4
    },
    if left {
      2
    } else {
      5
    },
    if right {
      3
    } else {
      5
    },
  ]
  for i, side in sides {
    let border = region.borders[side]
    if border.weight != 0 {
      self.borders[i] = border
    }
  }
}

///|
fn GridStyle::at(
  self : GridStyle,
  row : Int32,
  column : Int32,
  row_count : Int32,
  column_count : Int32,
  header_rows : Int32,
) -> GridCellStyle {
  let empty : GridStyleBorder = { weight: 0, color: 0U, }
  let cell : GridCellStyle = {
    fill: 0U,
    color: 0x000000ffU,
    bold: false,
    borders: [empty, empty, empty, empty],
  }
  cell.apply_region(
    self.whole,
    row == 0,
    row == row_count - 1,
    column == 0,
    column == column_count - 1,
  )
  if row >= header_rows {
    let first_size = Int32::max(self.first.size, 1)
    let second_size = Int32::max(self.second.size, 1)
    let offset = (row - header_rows) % (first_size + second_size)
    let region = if offset < first_size { self.first } else { self.second }
    let start = if offset < first_size {
      row - offset
    } else {
      row - offset + first_size
    }
    let end = Int32::min(start + Int32::max(region.size, 1), row_count) - 1
    cell.apply_region(
      region,
      row == start,
      row == end,
      column == 0,
      column == column_count - 1,
    )
  } else {
    cell.apply_region(
      self.header,
      row == 0,
      row == header_rows - 1,
      column == 0,
      column == column_count - 1,
    )
  }
  cell
}
