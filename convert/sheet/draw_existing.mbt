///|
/// A cell positioned within a sparse sheet row.
pub(all) struct SizedGridCell {
  column : Int32
  cell : Cell
  center : Bool
  visible : Bool
  occupied : Bool
  color : UInt32
}

///|
/// A sparse row of cells in an already-sized sheet.
pub(all) struct SizedGridRow {
  index : Int32
  cells : Array[SizedGridCell]
}

///|
/// A solid fill and the key used to combine adjacent equal fills.
pub(all) struct GridSolidFill {
  key : String
  color : UInt32
}

///|
/// Border weights on the four sides of a cell.
pub(all) struct GridCellBorder {
  top : Int32
  bottom : Int32
  left : Int32
  right : Int32
}

///|
/// Diagonal border style and directions for a cell or merged rectangle.
pub(all) struct GridCellDiagonal {
  weight : Int32
  color : UInt32
  up : Bool
  down : Bool
}

///|
/// Text decorations on a cell's no-font rendering.
pub(all) struct GridTextDecoration {
  underline : String
  strike : Bool
}

///|
/// A text run with its own color in a single-line fallback-font cell.
pub(all) struct GridRichColorRun {
  text : String
  color : UInt32
  family_override : Bool
  family : String
  east_asian : String
  size : Double
  bold : Bool
  italic : Bool
  underline : String
  strike : Bool
}

///|
/// An inclusive merged rectangle in a sized grid.
pub(all) struct GridMergeRegion {
  row_start : Int32
  row_end : Int32
  column_start : Int32
  column_end : Int32
}

///|
/// A hyperlink over an inclusive cell range.
pub(all) struct GridLink {
  row_start : Int32
  row_end : Int32
  column_start : Int32
  column_end : Int32
  target : String
}

///|
priv struct GridFillRect {
  x0 : Double
  x1 : Double
  y0 : Double
  y1 : Double
  fill : GridSolidFill
}

///|
/// Measure a character using the upstream fallback metrics at the given size.
pub fn sized_fallback_advance(
  character : Char,
  bold : Bool,
  size : Double,
) -> Double {
  let base = fallback_advance(character, bold)
  if size == 11.0 {
    base
  } else {
    base / 11.0 * size
  }
}

///|
/// Draw unstyled cells in an already-sized sheet with fallback font metrics.
pub fn draw_sized_grid_no_fonts(
  rows : Array[SizedGridRow],
  geometry : GridGeometry,
  all_columns : Array[Run],
  language : String,
  document_language : String,
  verticals~ : Map[Int32, Map[Int32, String]] = Map([]),
  horizontals~ : Map[Int32, Map[Int32, String]] = Map([]),
  bolds~ : Map[Int32, Map[Int32, Bool]] = Map([]),
  fills~ : Map[Int32, Map[Int32, GridSolidFill]] = Map([]),
  sizes~ : Map[Int32, Map[Int32, Double]] = Map([]),
  borders~ : Map[Int32, Map[Int32, GridCellBorder]] = Map([]),
  spans~ : Map[Int32, Map[Int32, Int32]] = Map([]),
  border_colors~ : Map[Int32, Map[Int32, Array[UInt32]]] = Map([]),
  merge_regions~ : Array[GridMergeRegion] = [],
  east_asian_fonts~ : Map[Int32, Map[Int32, String]] = Map([]),
  wraps~ : Map[Int32, Map[Int32, Bool]] = Map([]),
  diagonals~ : Map[Int32, Map[Int32, GridCellDiagonal]] = Map([]),
  font_families~ : Map[Int32, Map[Int32, String]] = Map([]),
  italics~ : Map[Int32, Map[Int32, Bool]] = Map([]),
  decorations~ : Map[Int32, Map[Int32, GridTextDecoration]] = Map([]),
  scripts~ : Map[Int32, Map[Int32, String]] = Map([]),
  shrink_scales~ : Map[Int32, Map[Int32, Double]] = Map([]),
  indents~ : Map[Int32, Map[Int32, Double]] = Map([]),
  center_across~ : Map[Int32, Map[Int32, Bool]] = Map([]),
  links~ : Array[GridLink] = [],
  auto_filter~ : (Int32, Int32, Int32)? = None,
  notes~ : Array[(Int32, Int32)] = [],
  rich_colors~ : Map[Int32, Map[Int32, Array[GridRichColorRun]]] = Map([]),
  rich_base_sizes~ : Map[Int32, Map[Int32, Double]] = Map([]),
) -> DrawnGrid raise {
  let region_rows : Map[Int32, Map[Int32, GridMergeRegion]] = Map([])
  let mut region_room = 4194304L
  for region in merge_regions {
    if region.row_start < 0 ||
      region.row_end >= 1048576 ||
      region.row_end < region.row_start ||
      region.column_start < 0 ||
      region.column_end >= 16384 ||
      region.column_end < region.column_start {
      raise InvalidArgument("invalid merged region")
    }
    let area = (region.row_end - region.row_start + 1).to_int64() *
      (region.column_end - region.column_start + 1).to_int64()
    region_room -= area
    if region_room < 0L {
      raise InvalidArgument("too many merged cells")
    }
    for row in region.row_start..<=region.row_end {
      if !(spans.get(row) is Some(columns) &&
        columns.get(region.column_start) == Some(region.column_end)) {
        raise InvalidArgument("merged region does not match its row spans")
      }
      let columns = match region_rows.get(row) {
        Some(columns) => columns
        None => {
          let columns : Map[Int32, GridMergeRegion] = Map([])
          region_rows[row] = columns
          columns
        }
      }
      if columns.contains(region.column_start) {
        raise InvalidArgument("duplicate merged region")
      }
      columns[region.column_start] = region
    }
  }
  let mut span_room = 4194304L
  for row, columns in spans {
    if row < 0 || row >= 1048576 {
      raise InvalidArgument("merged row is outside the sheet")
    }
    let starts : Array[Int32] = [ for start, _ in columns => start ]
    starts.sort()
    let mut previous_end = -1
    for start in starts {
      let end = columns[start]
      if start < 0 || end >= 16384 || end < start || start <= previous_end {
        raise InvalidArgument("invalid or overlapping merged columns")
      }
      span_room -= (end - start + 1).to_int64()
      if span_room < 0L {
        raise InvalidArgument("too many merged cells")
      }
      previous_end = end
    }
  }
  let col_positions = grid_positions(all_columns)
  if col_positions.length() != 16385 {
    raise InvalidArgument("expected sizes for 16384 columns")
  }
  let row_positions = grid_positions(geometry.rows)
  let count = row_positions.length() - 1
  let context : GridDrawContext = {
    tiles: [],
    indexes: Map([]),
    width: col_positions[16384],
    height: row_positions[count],
    document_language,
  }
  let family = grid_family("")
  let visible_columns = grid_positions(geometry.columns).length() - 1
  context.sized_grid_fills(
    rows, fills, region_rows, merge_regions, col_positions, row_positions, visible_columns,
  )
  let mut text_columns = 0
  for sparse in rows {
    let i = sparse.index
    if i >= count || i >= 1048576 {
      break
    }
    if i < 0 {
      continue
    }
    let row : Array[Cell] = []
    let render_cells : Map[Int32, Cell] = Map([])
    let colors : Map[Int32, UInt32] = Map([])
    let centered : Map[Int32, Bool] = Map([])
    let visibility : Map[Int32, Bool] = Map([])
    let empty_strings : Map[Int32, Bool] = Map([])
    for entry in sparse.cells {
      if entry.column < 0 || entry.column >= 16384 {
        continue
      }
      while row.length() <= entry.column {
        row.push({ text: "", number: false, })
      }
      row[entry.column] = if entry.occupied && entry.cell.text == "" {
        { text: "\u0000", number: entry.cell.number, }
      } else {
        entry.cell
      }
      render_cells[entry.column] = entry.cell
      colors[entry.column] = entry.color
      centered[entry.column] = entry.center
      visibility[entry.column] = entry.visible
      if !entry.occupied {
        empty_strings[entry.column] = true
      }
    }
    let row_spans = spans.get(i).unwrap_or(Map([]))
    for start, end in row_spans {
      while row.length() <= end {
        row.push({ text: "", number: false, })
      }
      for column in start..<=end {
        if row[column].text == "" && !empty_strings.contains(column) {
          row[column] = { text: "\u0000", number: false, }
        }
      }
    }
    let y = row_positions[i]
    let height = row_positions[i + 1] - y
    for column, _ in row {
      if column >= 16384 {
        break
      }
      let mut last = column
      let mut hidden_by_span = false
      let mut last_row = i
      for start, end in row_spans {
        if column >= start && column <= end {
          let region = match region_rows.get(i) {
            Some(columns) => columns.get(start)
            None => None
          }
          if column == start &&
            (region is None || (region is Some(r) && r.row_start == i)) {
            last = end
            if region is Some(r) {
              last_row = r.row_end
            }
          } else {
            hidden_by_span = true
          }
          break
        }
      }
      let reference_last = last
      if hidden_by_span ||
        !visibility.get(column).unwrap_or(false) ||
        col_positions[reference_last + 1] <= col_positions[column] ||
        last_row >= count ||
        row_positions[last_row + 1] <= y {
        continue
      }
      let mut overflow_last = reference_last
      if center_across.get(i) is Some(columns) && columns.contains(column) {
        overflow_last = if row_spans.contains(column) {
          reference_last
        } else {
          column
        }
        let mut selection_last = column
        while selection_last + 1 < visible_columns &&
              columns.get(selection_last + 1) == Some(true) {
          selection_last += 1
        }
        if selection_last > column {
          last = selection_last
        }
      }
      let height = if last_row == i {
        height
      } else {
        row_positions[last_row + 1] - y
      }
      let cell = render_cells[column]
      let bold = match bolds.get(i) {
        Some(columns) => columns.get(column).unwrap_or(false)
        None => false
      }
      let original_size = match sizes.get(i) {
        Some(columns) => columns.get(column).unwrap_or(11.0)
        None => 11.0
      }
      let scale = match shrink_scales.get(i) {
        Some(columns) => columns.get(column).unwrap_or(1.0)
        None => 1.0
      }
      let indent = match indents.get(i) {
        Some(columns) => columns.get(column).unwrap_or(0.0)
        None => 0.0
      }
      let size = original_size * scale
      let line_size = if scale == 0.0 { original_size } else { size }
      let script = match scripts.get(i) {
        Some(columns) => columns.get(column).unwrap_or("")
        None => ""
      }
      let draw_size = if script == "" { size } else { size * (2.0 / 3.0) }
      let italic = match italics.get(i) {
        Some(columns) => columns.get(column).unwrap_or(false)
        None => false
      }
      let decoration = match decorations.get(i) {
        Some(columns) =>
          columns.get(column).unwrap_or({ underline: "", strike: false, })
        None => { underline: "", strike: false, }
      }
      let east_asian = match east_asian_fonts.get(i) {
        Some(columns) =>
          match columns.get(column) {
            Some(name) if name != "" =>
              css_quote(name) + ", " + @fontdb.classify(name)
            _ => ""
          }
        None => ""
      }
      let family = match font_families.get(i) {
        Some(columns) =>
          match columns.get(column) {
            Some(name) if name != "" =>
              css_quote(name) + ", " + @fontdb.classify(name)
            _ => family
          }
        None => family
      }
      let advance = (character : Char, is_bold : Bool) => {
        let initial_size = if script == "" {
          original_size
        } else {
          original_size * (2.0 / 3.0)
        }
        sized_fallback_advance(character, is_bold, initial_size) * scale
      }
      let metrics = (_ : Char, _ : Bool) => (0.9 * line_size, 0.25 * line_size)
      let wrap = match wraps.get(i) {
        Some(columns) => columns.get(column).unwrap_or(false)
        None => false
      }
      let text = sized_grid_text(cell.text, wrap)
      let display : Cell = { text, number: cell.number, }
      let rich_runs = match rich_colors.get(i) {
        Some(columns) => columns.get(column).unwrap_or([])
        None => []
      }
      let mut varying = false
      for run in rich_runs {
        if run.size.is_nan() || run.size.is_inf() || run.size < 0.0 {
          raise InvalidArgument("invalid styled run size")
        }
        if run.size > 0.0 {
          varying = true
        }
      }
      let mut rich_width = 0.0
      if varying {
        if scale != 1.0 ||
          script != "" ||
          (!wrap && text.length() > 1024) ||
          (!wrap && text.trim().to_string() != text) {
          raise InvalidArgument(
            "styled rich text runs require one unscaled line",
          )
        }
        let mut shown = 0
        for run in rich_runs {
          let run_size = if run.size > 0.0 { run.size } else { draw_size }
          if wrap && shown >= 1024 {
            break
          }
          for ch in run.text {
            if !wrap && ch.to_int() < 0x20 {
              raise InvalidArgument("varying run sizes require printable text")
            }
            if ch == '\n' || ch == '\t' || ch.to_int() >= 0x20 {
              shown += 1
            }
            if shown > 1024 {
              raise InvalidArgument(
                "varying run sizes exceed the supported length",
              )
            }
            if !wrap {
              rich_width += sized_fallback_advance(ch, run.bold, run_size)
            }
            if wrap && shown >= 1024 {
              break
            }
          }
        }
      }
      let rich_layout = if varying && wrap {
        let measure : Array[RichMeasureRun] = rich_runs.map(run => {
          text: run.text,
          size: if run.size > 0.0 {
            run.size
          } else {
            draw_size
          },
        })
        let rich_base = match rich_base_sizes.get(i) {
          Some(values) => values.get(column).unwrap_or(draw_size)
          None => draw_size
        }
        Some(
          wrap_rich_text(
            measure,
            Double::max(
              col_positions[last + 1] - col_positions[column] - 3.75 - indent,
              0.0,
            ),
            rich_base,
          ),
        )
      } else {
        None
      }
      let initial = grid_cell_layout(
        row,
        display,
        column,
        col_positions,
        y,
        height,
        bold,
        language,
        advance,
        metrics,
        end_column=last,
        overflow_end=overflow_last,
        allow_overflow=last_row == i,
        force_wrap=wrap,
        line_width=if varying && !wrap { Some(rich_width) } else { None },
        rich_layout~,
        indent~,
      )
      let horizontal : DrawCell = if centered.get(column).unwrap_or(false) {
        let lines = initial.lines.map(fn(line) {
          {
            text: line.text,
            x: col_positions[column] +
            (col_positions[last + 1] - col_positions[column] - line.width) / 2.0,
            baseline: line.baseline,
            ascent: line.ascent,
            descent: line.descent,
            width: line.width,
            cjk_wrap: line.cjk_wrap,
            explicit: line.explicit,
          }
        })
        let mut x0 = col_positions[column]
        let mut x1 = col_positions[last + 1]
        let mut text0 = 1.0e300
        let mut text1 = -1.0e300
        for line in lines {
          text0 = Double::min(text0, line.x)
          text1 = Double::max(text1, line.x + line.width)
        }
        if last_row == i && !wrap && (text0 < x0 || text1 > x1) {
          let mut next = overflow_last + 1
          while next < 16384 && x1 < text1 {
            if next < row.length() && row[next].text != "" {
              break
            }
            x1 = col_positions[next + 1]
            next += 1
          }
          let mut previous = column - 1
          while previous >= 0 && x0 > text0 {
            if previous < row.length() && row[previous].text != "" {
              break
            }
            x0 = col_positions[previous]
            previous -= 1
          }
        }
        let ty0 = lines[0].baseline - lines[0].ascent
        let ty1 = lines[lines.length() - 1].baseline +
          lines[lines.length() - 1].descent
        let clipped = text0 < x0 - 0.01 ||
          text1 > x1 + 0.01 ||
          ty0 < y - 0.01 ||
          ty1 > y + height + 0.01
        if !clipped {
          x0 = Double::min(text0, col_positions[column])
          x1 = Double::max(text1, col_positions[last + 1])
        }
        {
          x0,
          x1,
          y0: initial.y0,
          y1: initial.y1,
          clip: clipped,
          lang: initial.lang,
          lang_known: initial.lang_known,
          lines,
        }
      } else {
        initial
      }
      let horizontal_kind = match horizontals.get(i) {
        Some(columns) => columns.get(column).unwrap_or("general")
        None => "general"
      }
      let horizontal = sized_grid_horizontal_layout(
        horizontal,
        horizontal_kind,
        row,
        display,
        column,
        last,
        col_positions,
        y,
        height,
        line_size,
        last_row == i && !wrap,
        indent,
      )
      let vertical = match verticals.get(i) {
        Some(columns) => columns.get(column).unwrap_or("bottom")
        None => "bottom"
      }
      let layout = sized_grid_vertical_layout(
        horizontal, y, height, vertical, line_size,
      )
      let shift = if script == "superscript" {
        size * 0.33
      } else if script == "subscript" {
        -size * 0.15
      } else {
        0.0
      }
      let layout = if shift == 0.0 {
        layout
      } else {
        {
          ..layout,
          lines: layout.lines.map(line => {
            ..line,
            baseline: line.baseline - shift,
          }),
        }
      }
      if layout.x1 > col_positions[visible_columns] {
        let target = layout.x1 - 0.01
        let mut lo = 0
        let mut hi = 16384
        while lo < hi {
          let mid = lo + (hi - lo) / 2
          if col_positions[mid + 1] > target {
            hi = mid
          } else {
            lo = mid + 1
          }
        }
        text_columns = Int32::max(text_columns, Int32::min(lo, 16383) + 1)
      }
      let reference = cell_reference(i, column, false) +
        (if row_spans.contains(column) {
          ":" + cell_reference(last_row, reference_last, false)
        } else {
          ""
        })
      let rich_lines : Array[Array[GridRichColorRun]] = []
      if !rich_runs.is_empty() {
        let chars : Array[Char] = []
        let owners : Array[Int32] = []
        let mut shown = 0
        for index, run in rich_runs {
          if shown >= 1024 {
            break
          }
          for ch in run.text {
            if ch == '\n' {
              if wrap {
                chars.push(ch)
                owners.push(index)
              }
              shown += 1
            } else {
              let visible = if ch == '\t' { ' ' } else { ch }
              if visible.to_int() < 0x20 {
                continue
              }
              chars.push(visible)
              owners.push(index)
              shown += 1
            }
            if shown >= 1024 {
              break
            }
          }
        }
        let mut cursor = 0
        for line_index, line in layout.lines {
          if line_index > 0 {
            while cursor < chars.length() &&
                  chars[cursor] != '\n' &&
                  break_space(chars[cursor]) {
              cursor += 1
            }
            if line.explicit {
              if cursor >= chars.length() || chars[cursor] != '\n' {
                raise InvalidArgument("styled runs must match visible lines")
              }
              cursor += 1
            }
          }
          let output : Array[GridRichColorRun] = []
          let mut previous = -1
          for ch in line.text {
            if cursor >= chars.length() || chars[cursor] != ch {
              raise InvalidArgument("styled runs must match visible lines")
            }
            let owner = owners[cursor]
            if previous == owner && !output.is_empty() {
              let last = output.length() - 1
              output[last] = {
                ..output[last],
                text: output[last].text + ch.to_string(),
              }
            } else {
              output.push({ ..rich_runs[owner], text: ch.to_string(), })
            }
            previous = owner
            cursor += 1
          }
          rich_lines.push(output)
        }
        while cursor < chars.length() &&
              (break_space(chars[cursor]) || chars[cursor] == '\n') {
          cursor += 1
        }
        if cursor != chars.length() {
          raise InvalidArgument("styled runs must match visible lines")
        }
      }
      for tile in context.in_bounds(layout.x0, layout.y0, layout.x1, layout.y1) {
        tile.emit_cell(
          layout,
          reference,
          family,
          bold,
          colors.get(column).unwrap_or(0x000000ffU),
          advance,
          None,
          None,
          None,
          Map([]),
          size=draw_size,
          east_asian~,
          italic~,
          underline=decoration.underline,
          strike=decoration.strike,
          rich_lines~,
        )
      }
    }
  }
  context.sized_grid_borders(
    rows, borders, border_colors, diagonals, spans, region_rows, merge_regions, col_positions,
    row_positions, visible_columns,
  )
  for (row, column) in notes {
    if row < 0 || row >= count || column < 0 || column >= visible_columns {
      continue
    }
    let mut first_row = row
    let mut last_row = row
    let mut first_column = column
    let mut last_column = column
    if region_rows.get(row) is Some(regions) {
      for _, region in regions {
        if column >= region.column_start && column <= region.column_end {
          first_row = region.row_start
          last_row = region.row_end
          first_column = region.column_start
          last_column = region.column_end
        }
      }
    }
    let x0 = col_positions[first_column]
    let x1 = col_positions[last_column + 1]
    let y0 = row_positions[first_row]
    let y1 = row_positions[last_row + 1]
    if x1 <= x0 || y1 <= y0 {
      continue
    }
    let size = 3.75
    for tile in context.in_bounds(x1 - size, y0, x1, y0 + size) {
      let ox = tile.x.to_double() * 2048.0
      let oy = tile.y.to_double() * 2048.0
      let path : @core.Path = {
        verbs: b"\x00\x01\x01\x04",
        coordinates: [
          x1 - size - ox,
          y0 - oy,
          x1 - ox,
          y0 - oy,
          x1 - ox,
          y0 + size - oy,
        ],
      }
      tile.fill_color(0xe02020ffU)
      let index = tile.object.add_path(@core.Inline(path))
      tile.object.fill_path(index, 0)
      tile.drawn = true
    }
  }
  if auto_filter is Some((row, first, last)) {
    if row >= 0 && row < count && first >= 0 && first < visible_columns {
      let end = Int32::min(last, visible_columns - 1)
      let height = row_positions[row + 1] - row_positions[row]
      for column in first..<=end {
        let width = col_positions[column + 1] - col_positions[column]
        if width > 0.0 && height > 0.0 {
          context.paint_filter_button(
            col_positions[column],
            row_positions[row],
            width,
            height,
          )
        }
      }
    }
  }
  let mut link_room = 16384
  for link in links {
    if link.row_start < 0 ||
      link.column_start < 0 ||
      link.row_start >= count ||
      link.column_start >= visible_columns {
      continue
    }
    let last_row = Int32::min(link.row_end, count - 1)
    let last_column = Int32::min(link.column_end, visible_columns - 1)
    if last_row < link.row_start || last_column < link.column_start {
      continue
    }
    let x0 = col_positions[link.column_start]
    let x1 = col_positions[last_column + 1]
    let y0 = row_positions[link.row_start]
    let y1 = row_positions[last_row + 1]
    if x0 >= x1 || y0 >= y1 {
      continue
    }
    let tile_count = grid_link_tile_count(x0, y0, x1, y1)
    if tile_count - 1L > link_room.to_int64() {
      raise InvalidArgument("sheet: links exceed the supported tile budget")
    }
    link_room -= (tile_count - 1L).to_int()
    for tile in context.in_bounds(x0, y0, x1, y1) {
      tile.object.link(
        Float::from_double(x0 - tile.x.to_double() * 2048.0),
        Float::from_double(y0 - tile.y.to_double() * 2048.0),
        Float::from_double(x1 - x0),
        Float::from_double(y1 - y0),
        link.target,
      )
    }
  }
  let tiles = context.tiles.map(fn(tile) {
    { x: tile.x, y: tile.y, object: tile.object.encode(), drawn: tile.drawn, }
  })
  let final_count = Int32::min(
    16384,
    Int32::max(visible_columns, text_columns + 2),
  )
  let columns : Array[Run] = []
  let mut remaining = final_count
  for run in all_columns {
    let count = Int32::min(remaining, run.count)
    if count > 0 {
      columns.push({ count, size: run.size, })
      remaining -= count
    }
    if remaining <= 0 {
      break
    }
  }
  {
    geometry: {
      columns,
      rows: geometry.rows,
      frozen_rows: geometry.frozen_rows,
    },
    tiles,
  }
}

///|
fn grid_link_tile_count(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Int64 {
  ((x1 / 2048.0).ceil().to_int() - (x0 / 2048.0).to_int()).to_int64() *
  ((y1 / 2048.0).ceil().to_int() - (y0 / 2048.0).to_int()).to_int64()
}

///|
fn GridDrawContext::sized_grid_borders(
  self : GridDrawContext,
  rows : Array[SizedGridRow],
  borders : Map[Int32, Map[Int32, GridCellBorder]],
  border_colors : Map[Int32, Map[Int32, Array[UInt32]]],
  diagonals : Map[Int32, Map[Int32, GridCellDiagonal]],
  spans : Map[Int32, Map[Int32, Int32]],
  region_rows : Map[Int32, Map[Int32, GridMergeRegion]],
  merge_regions : Array[GridMergeRegion],
  columns : Array[Double],
  row_positions : Array[Double],
  visible_columns : Int32,
) -> Unit raise {
  let horizontal : Map[String, GridEdge] = Map([])
  let vertical : Map[String, GridEdge] = Map([])
  let diagonal_segments : Array[GridDiagonalSegment] = []
  for row in rows {
    let index = row.index
    if index < 0 {
      continue
    }
    if index >= row_positions.length() - 1 {
      break
    }
    if diagonals.get(index) is Some(values) &&
      row_positions[index] < row_positions[index + 1] {
      let keys : Array[Int32] = [ for column, _ in values => column ]
      keys.sort()
      for column in keys {
        if column >= 0 &&
          column < visible_columns &&
          columns[column] < columns[column + 1] &&
          !grid_region_contains(region_rows, index, column) {
          add_sized_diagonal(
            diagonal_segments,
            values[column],
            columns[column],
            row_positions[index],
            columns[column + 1],
            row_positions[index + 1],
          )
        }
      }
    }
    if borders.get(index) is Some(values) {
      let keys : Array[Int32] = [ for column, _ in values => column ]
      keys.sort()
      for column in keys {
        if column < 0 || column >= visible_columns {
          continue
        }
        if grid_region_contains(region_rows, index, column) ||
          (
            !grid_span_contains(spans, index, column) &&
            (
              row_positions[index] >= row_positions[index + 1] ||
              columns[column] >= columns[column + 1]
            )
          ) {
          continue
        }
        let border = values[column]
        let colors = match border_colors.get(index) {
          Some(row_colors) => row_colors.get(column).unwrap_or([])
          None => []
        }
        put_sized_borders(horizontal, vertical, index, column, border, colors)
      }
    }
  }
  for region in merge_regions {
    for row in region.row_start..<=region.row_end {
      if row >= row_positions.length() - 1 {
        break
      }
      if borders.get(row) is Some(values) {
        for column in region.column_start..<=region.column_end {
          if column >= visible_columns {
            break
          }
          if values.get(column) is Some(border) {
            let colors = match border_colors.get(row) {
              Some(row_colors) => row_colors.get(column).unwrap_or([])
              None => []
            }
            put_sized_borders(horizontal, vertical, row, column, border, colors)
          }
        }
      }
    }
    if region.row_end < row_positions.length() - 1 &&
      region.column_end < visible_columns {
      if diagonals.get(region.row_start) is Some(values) &&
        values.get(region.column_start) is Some(diagonal) {
        add_sized_diagonal(
          diagonal_segments,
          diagonal,
          columns[region.column_start],
          row_positions[region.row_start],
          columns[region.column_end + 1],
          row_positions[region.row_end + 1],
        )
      }
    }
  }
  self.draw_grid_edges(
    horizontal,
    vertical,
    columns,
    row_positions,
    diagonals=diagonal_segments,
  )
}

///|
fn add_sized_diagonal(
  segments : Array[GridDiagonalSegment],
  diagonal : GridCellDiagonal,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Unit {
  let border : GridStyleBorder = {
    weight: diagonal.weight,
    color: diagonal.color,
  }
  if diagonal.down {
    segments.push({ border, segment: { x0, y0, x1, y1, }, })
  }
  if diagonal.up {
    segments.push({ border, segment: { x0, y0: y1, x1, y1: y0, }, })
  }
}

///|
fn put_sized_borders(
  horizontal : Map[String, GridEdge],
  vertical : Map[String, GridEdge],
  row : Int32,
  column : Int32,
  border : GridCellBorder,
  colors : Array[UInt32],
) -> Unit {
  let color = fn(i : Int32) { colors.get(i).unwrap_or(0x000000ffU) }
  put_grid_edge(horizontal, row, column, {
    weight: border.top,
    color: color(0),
  })
  put_grid_edge(horizontal, row + 1, column, {
    weight: border.bottom,
    color: color(1),
  })
  put_grid_edge(vertical, row, column, { weight: border.left, color: color(2), })
  put_grid_edge(vertical, row, column + 1, {
    weight: border.right,
    color: color(3),
  })
}

///|
fn GridDrawContext::sized_fill_rect(
  self : GridDrawContext,
  fill : GridFillRect,
) -> Unit {
  for tile in self.in_bounds(fill.x0, fill.y0, fill.x1, fill.y1) {
    tile.fill_color(fill.fill.color)
    tile.rectangle(fill.x0, fill.y0, fill.x1 - fill.x0, fill.y1 - fill.y0)
  }
}

///|
fn GridDrawContext::sized_grid_fills(
  self : GridDrawContext,
  rows : Array[SizedGridRow],
  fills : Map[Int32, Map[Int32, GridSolidFill]],
  region_rows : Map[Int32, Map[Int32, GridMergeRegion]],
  merge_regions : Array[GridMergeRegion],
  columns : Array[Double],
  row_positions : Array[Double],
  visible_columns : Int32,
) -> Unit {
  let mut previous : Array[GridFillRect] = []
  for row in rows {
    let index = row.index
    if index < 0 {
      continue
    }
    if index >= row_positions.length() - 1 {
      break
    }
    let y0 = row_positions[index]
    let y1 = row_positions[index + 1]
    if y0 >= y1 {
      continue
    }
    if !previous.is_empty() && previous[0].y1 < y0 {
      for rect in previous {
        self.sized_fill_rect(rect)
      }
      previous = []
    }
    let current : Array[GridFillRect] = []
    if fills.get(index) is Some(values) {
      let keys : Array[Int32] = [ for column, _ in values => column ]
      keys.sort()
      for column in keys {
        if column < 0 || column >= visible_columns {
          continue
        }
        if grid_region_contains(region_rows, index, column) {
          continue
        }
        let x0 = columns[column]
        let x1 = columns[column + 1]
        if x0 >= x1 {
          continue
        }
        let fill = values[column]
        if !current.is_empty() {
          let last = current[current.length() - 1]
          if last.fill.key == fill.key && last.x1 == x0 {
            current[current.length() - 1] = { ..last, x1, }
            continue
          }
        }
        current.push({ x0, x1, y0, y1, fill, })
      }
    }
    let next : Array[GridFillRect] = []
    let mut j = 0
    for rect in current {
      while j < previous.length() && previous[j].x0 < rect.x0 {
        self.sized_fill_rect(previous[j])
        j += 1
      }
      if j < previous.length() &&
        previous[j].x0 == rect.x0 &&
        previous[j].x1 == rect.x1 &&
        previous[j].fill.key == rect.fill.key &&
        previous[j].y1 == rect.y0 {
        next.push({ ..rect, y0: previous[j].y0, })
        j += 1
      } else {
        next.push(rect)
      }
    }
    while j < previous.length() {
      self.sized_fill_rect(previous[j])
      j += 1
    }
    previous = next
  }
  for rect in previous {
    self.sized_fill_rect(rect)
  }
  for region in merge_regions {
    if region.row_end + 1 >= row_positions.length() ||
      region.column_end >= visible_columns {
      continue
    }
    if fills.get(region.row_start) is Some(values) {
      if values.get(region.column_start) is Some(fill) {
        let x0 = columns[region.column_start]
        let x1 = columns[region.column_end + 1]
        let y0 = row_positions[region.row_start]
        let y1 = row_positions[region.row_end + 1]
        if x0 < x1 && y0 < y1 {
          self.sized_fill_rect({ x0, x1, y0, y1, fill, })
        }
      }
    }
  }
}

///|
fn grid_region_contains(
  regions : Map[Int32, Map[Int32, GridMergeRegion]],
  row : Int32,
  column : Int32,
) -> Bool {
  if regions.get(row) is Some(columns) {
    for _, region in columns {
      if column >= region.column_start && column <= region.column_end {
        return true
      }
    }
  }
  false
}

///|
fn grid_span_contains(
  spans : Map[Int32, Map[Int32, Int32]],
  row : Int32,
  column : Int32,
) -> Bool {
  if spans.get(row) is Some(columns) {
    for start, end in columns {
      if column >= start && column <= end {
        return true
      }
    }
  }
  false
}

///|
fn sized_grid_horizontal_layout(
  layout : DrawCell,
  alignment : String,
  row : Array[Cell],
  cell : Cell,
  column : Int32,
  last : Int32,
  positions : Array[Double],
  y : Double,
  height : Double,
  _size : Double,
  allow_overflow : Bool,
  indent : Double,
) -> DrawCell {
  if alignment != "left" && alignment != "right" {
    return layout
  }
  let left = positions[column]
  let right = positions[last + 1]
  let lines = layout.lines.map(line => {
    ..line,
    x: if alignment == "left" {
      left + 1.5 + indent
    } else {
      right - 2.25 - indent - line.width
    },
  })
  let mut tx0 = 1.0e300
  let mut tx1 = -1.0e300
  for line in lines {
    tx0 = Double::min(tx0, line.x)
    tx1 = Double::max(tx1, line.x + line.width)
  }
  let mut x0 = left
  let mut x1 = right
  if allow_overflow &&
    !cell.number &&
    !cell.text.contains("\n") &&
    !cell.text.contains("\r") {
    if alignment == "right" {
      let mut previous = column - 1
      while previous >= 0 && x0 > tx0 {
        if previous < row.length() && row[previous].text != "" {
          break
        }
        x0 = positions[previous]
        previous -= 1
      }
    } else {
      let mut next = last + 1
      while next < 16384 && x1 < tx1 {
        if next < row.length() && row[next].text != "" {
          break
        }
        x1 = positions[next + 1]
        next += 1
      }
    }
  }
  let ty0 = lines[0].baseline - lines[0].ascent
  let ty1 = lines[lines.length() - 1].baseline +
    lines[lines.length() - 1].descent
  let clip = tx0 < x0 - 0.01 ||
    tx1 > x1 + 0.01 ||
    ty0 < y - 0.01 ||
    ty1 > y + height + 0.01
  if !clip {
    x0 = Double::min(tx0, left)
    x1 = Double::max(tx1, right)
  }
  { ..layout, x0, x1, clip, lines, }
}

///|
fn sized_grid_vertical_layout(
  layout : DrawCell,
  y : Double,
  height : Double,
  vertical : String,
  _size : Double,
) -> DrawCell {
  if vertical != "top" && vertical != "center" {
    return layout
  }
  let metrics : Array[(Double, Double)] = []
  let mut total = 0.0
  for line in layout.lines {
    metrics.push((line.ascent, line.descent))
    total += line.ascent + line.descent
  }
  let mut top = if vertical == "top" {
    y + 0.75
  } else {
    y + (height - total) / 2.0
  }
  let lines : Array[DrawLine] = []
  let mut tx0 = 1.0e300
  let mut tx1 = -1.0e300
  for i, line in layout.lines {
    let (ascent, descent) = metrics[i]
    tx0 = Double::min(tx0, line.x)
    tx1 = Double::max(tx1, line.x + line.width)
    lines.push({ ..line, baseline: top + ascent, })
    top += ascent + descent
  }
  let ty0 = lines[0].baseline - metrics[0].0
  let ty1 = lines[lines.length() - 1].baseline + metrics[metrics.length() - 1].1
  {
    ..layout,
    clip: tx0 < layout.x0 - 0.01 ||
    tx1 > layout.x1 + 0.01 ||
    ty0 < y - 0.01 ||
    ty1 > y + height + 0.01,
    lines,
  }
}

///|
fn sized_grid_text(text : String, allow_break : Bool) -> String {
  let output = StringBuilder()
  let mut shown = 0
  for c in text {
    if c == '\n' {
      if allow_break {
        output.write_char(c)
      }
      shown += 1
    } else {
      let char = if c == '\t' { ' ' } else { c }
      if char.to_int() < 0x20 {
        continue
      }
      output.write_char(char)
      shown += 1
    }
    if shown >= 1024 {
      break
    }
  }
  output.to_string()
}
