///|
/// Bounds of a sheet region in document units.
pub(all) struct SheetViewport {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Eq, Debug)

///|
/// Inclusive tile-coordinate range.
pub(all) struct TileRange {
  x0 : Double
  y0 : Double
  x1 : Double
  y1 : Double
} derive(Eq, Debug)

///|
/// Dimensions of a sheet from its run-length encoded columns and rows.
pub fn sheet_size(view : @core.View) -> (Double, Double) {
  let mut width = 0.0
  let mut height = 0.0
  for run in view.cols {
    width += run.count.to_double() * run.size
  }
  for run in view.rows {
    height += run.count.to_double() * run.size
  }
  (width, height)
}

///|
/// The inclusive tile range intersecting a region, using the upstream edge rule.
pub fn sheet_tile_range(
  viewport : SheetViewport,
  tile_size : Double,
) -> TileRange {
  let tile = if tile_size > 0.0 { tile_size } else { 2048.0 }
  {
    x0: (viewport.x / tile).floor(),
    y0: (viewport.y / tile).floor(),
    x1: ((viewport.x + viewport.width - 0.000001) / tile).floor(),
    y1: ((viewport.y + viewport.height - 0.000001) / tile).floor(),
  }
}

///|
/// Find existing tiles in any of the ranges, once each, in row-major order.
/// Work is bounded by the number of actual tiles rather than region area.
pub fn sheet_tiles_in(
  tiles : Array[@core.Tile],
  ranges : Array[TileRange],
) -> Array[@core.Tile] {
  let result : Array[@core.Tile] = []
  for tile in tiles {
    let x = tile.x.to_double()
    let y = tile.y.to_double()
    let mut include = false
    for range in ranges {
      if x >= range.x0 && x <= range.x1 && y >= range.y0 && y <= range.y1 {
        include = true
        break
      }
    }
    if include {
      result.push(tile)
    }
  }
  result.sort_by((a, b) => {
    if a.y == b.y {
      a.x.compare(b.x)
    } else {
      a.y.compare(b.y)
    }
  })
  let unique : Array[@core.Tile] = []
  for tile in result {
    if unique.length() == 0 ||
      unique[unique.length() - 1].x != tile.x ||
      unique[unique.length() - 1].y != tile.y {
      unique.push(tile)
    }
  }
  unique
}

///|
fn walk_sheet_lines(
  runs : Array[@core.SheetRun],
  from : Double,
  to : Double,
  emit : (Double) -> Unit,
) -> Unit {
  let mut pos = 0.0
  for run in runs {
    if run.count <= 0 {
      continue
    }
    if run.size == 0.0 {
      if pos > to {
        return
      }
      if pos >= from {
        emit(pos)
      }
      continue
    }
    // Skip arithmetically only when repeated additions are exact in f64.
    // Other sizes must follow the upstream's addition order at boundaries.
    let scaled = run.size * 64.0
    let scaled_pos = pos * 64.0
    let exact = scaled.floor() == scaled &&
      scaled_pos.floor() == scaled_pos &&
      (pos.abs() + run.count.to_double() * run.size) * 64.0 <=
      9007199254740991.0
    if !exact {
      for _ in 0..<run.count {
        pos += run.size
        if pos > to {
          return
        }
        if pos >= from {
          emit(pos)
        }
      }
      continue
    }
    let end = pos + run.count.to_double() * run.size
    if end >= from && pos < to {
      let first = if from <= pos + run.size {
        1
      } else if from > end {
        run.count + 1
      } else {
        ((from - pos) / run.size).ceil().to_int().max(1)
      }
      let last = if to >= end {
        run.count
      } else if to < pos + run.size {
        0
      } else {
        ((to - pos) / run.size).floor().to_int().min(run.count)
      }
      for i in first..<=last {
        emit(pos + i.to_double() * run.size)
      }
    }
    pos = end
    if pos > to {
      return
    }
  }
}

///|
/// Emit the visible snapped gridlines without allocating a line per sheet cell.
pub fn sheet_grid_lines(
  view : @core.View,
  viewport : SheetViewport,
  scale : Double,
  emit : (Double, Double, Double, Double) -> Unit,
) -> Unit raise {
  if scale.is_nan() ||
    scale.is_inf() ||
    scale <= 0.0 ||
    viewport.x.is_nan() ||
    viewport.y.is_nan() ||
    viewport.width.is_nan() ||
    viewport.height.is_nan() ||
    viewport.x.is_inf() ||
    viewport.y.is_inf() ||
    viewport.width.is_inf() ||
    viewport.height.is_inf() ||
    viewport.width < 0.0 ||
    viewport.height < 0.0 {
    raise InvalidOperands("invalid sheet viewport or scale")
  }
  let (width, height) = sheet_size(view)
  let x1 = (viewport.x + viewport.width).min(width)
  let y1 = (viewport.y + viewport.height).min(height)
  walk_sheet_lines(view.cols, viewport.x, x1, x => {
    let snapped = (x * scale + 0.5).floor() / scale + 0.5 / scale
    emit(snapped, viewport.y, snapped, y1)
  })
  walk_sheet_lines(view.rows, viewport.y, y1, y => {
    let snapped = (y * scale + 0.5).floor() / scale + 0.5 / scale
    emit(viewport.x, snapped, x1, snapped)
  })
}
