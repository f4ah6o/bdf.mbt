///|
fn grid_positions(runs : Array[Run]) -> Array[Double] {
  let positions : Array[Double] = [0.0]
  for run in runs {
    for _ in 0..<run.count {
      positions.push(positions[positions.length() - 1] + run.size.to_double())
    }
  }
  positions
}

///|
/// Draw a grid using the upstream no-font fallback metrics.
pub fn draw_grid_no_fonts(
  rows : Array[Array[Cell]],
  header_rows~ : Int32 = 0,
  subheader~ : Bool = false,
  language~ : String = "",
  table_style~ : String = "",
) -> DrawnGrid raise {
  draw_grid(
    rows,
    header_rows~,
    subheader~,
    language~,
    table_style~,
    font=None,
    hash=None,
    usage=None,
  )
}

///|
/// Draw a grid with an explicitly supplied SFNT face. `hash` identifies a
/// font part already added to the document; pass None for a system font.
pub fn draw_grid_with_font(
  rows : Array[Array[Cell]],
  font : @sfnt.Font,
  hash~ : String? = None,
  header_rows~ : Int32 = 0,
  subheader~ : Bool = false,
  language~ : String = "",
  table_style~ : String = "",
) -> DrawnGrid raise {
  draw_grid(
    rows,
    header_rows~,
    subheader~,
    language~,
    table_style~,
    font=Some(font),
    hash~,
    usage=None,
  )
}

///|
/// Glyph coverage collected while measuring and drawing a grid.
pub(all) struct FontUsage {
  used : Bool
  missing : Array[Int32]
}

///|
/// Draw with a system font reference and report the glyphs used or missing.
/// The result can be redrawn with a font hash after adding the font part.
pub fn draw_grid_with_font_usage(
  rows : Array[Array[Cell]],
  font : @sfnt.Font,
  header_rows~ : Int32 = 0,
  subheader~ : Bool = false,
  language~ : String = "",
  table_style~ : String = "",
) -> (DrawnGrid, FontUsage) raise {
  let usage : GridFontUsage = { used: false, missing: Map([]), }
  let drawn = draw_grid(
    rows,
    header_rows~,
    subheader~,
    language~,
    table_style~,
    font=Some(font),
    hash=None,
    usage=Some(usage),
  )
  let missing = usage.missing.keys().collect()
  missing.sort()
  (drawn, { used: usage.used, missing, })
}

///|
priv struct GridFontUsage {
  mut used : Bool
  missing : Map[Int32, Bool]
}

///|
fn draw_grid(
  rows : Array[Array[Cell]],
  header_rows~ : Int32,
  subheader~ : Bool,
  language~ : String,
  table_style~ : String,
  font~ : @sfnt.Font?,
  hash~ : String?,
  usage~ : GridFontUsage?,
) -> DrawnGrid raise {
  let advance = (character : Char, bold : Bool) => {
    match font {
      Some(face) => {
        match usage {
          Some(usage) =>
            match face.glyph(character.to_int()) {
              Some(_) => usage.used = true
              None =>
                if !character.is_whitespace() &&
                  character.to_int() >= 0x20 &&
                  character.to_int() != 0x200b &&
                  character.to_int() != 0xfeff {
                  usage.missing[character.to_int()] = true
                }
            }
          None => ()
        }
        font_advance(face, character)
      }
      None => fallback_advance(character, bold)
    }
  }
  if font is Some(_) {
    for digit in 48..<=57 {
      ignore(advance(digit.unsafe_to_char(), false))
    }
  }
  let (ascent, descent, mdw) = match font {
    Some(face) =>
      (
        face.metrics.ascent * 11.0,
        face.metrics.descent * 11.0,
        font_mdw(face, language),
      )
    None => (0.9 * 11.0, 0.25 * 11.0, 7.0)
  }
  let style = if table_style == "" {
    None
  } else {
    match grid_builtin_style(table_style) {
      Some(style) => Some(style)
      None => raise InvalidArgument("unknown table style: " + table_style)
    }
  }
  let mut last_col = -1
  for row_index, row in rows {
    if row_index >= 1048576 {
      break
    }
    for column, cell in row {
      if column >= 16384 {
        break
      }
      if cell.text != "" {
        last_col = Int32::max(last_col, column)
      }
    }
  }
  let table_rows = if style is Some(_) && last_col >= 0 {
    Int32::min(rows.length(), 1048576)
  } else {
    0
  }
  let header = Int32::max(0, Int32::min(header_rows, table_rows))
  let geometry = grid_geometry(
    rows,
    header_rows~,
    subheader~,
    filter_buttons=table_rows > 0 && header > 0,
    table_rows~,
    mdw~,
    advance~,
    metrics=(_, _) => (ascent, descent),
    default_line_height=ascent + descent,
  )
  let col_positions = grid_positions(geometry.columns)
  while col_positions.length() <= 16384 {
    col_positions.push(
      col_positions[col_positions.length() - 1] +
      ((8.0 * mdw + 5.0) / 8.0).ceil() * 8.0 * 0.75,
    )
  }
  let row_positions = grid_positions(geometry.rows)
  let row_count = row_positions.length() - 1
  let family = grid_family(language)
  let context : GridDrawContext = {
    tiles: [],
    indexes: Map([]),
    width: col_positions[16384],
    height: row_positions[row_count],
  }
  if style is Some(style) && table_rows > 0 {
    context.paint_table_fills(
      style,
      table_rows,
      last_col + 1,
      header,
      col_positions,
      row_positions,
    )
  }
  for row_index, row in rows {
    if row_index >= 1048576 || row_index >= row_count {
      break
    }
    let y = row_positions[row_index]
    let height = row_positions[row_index + 1] - y
    let base_bold = row_index < header_rows &&
      !(subheader && row_index == header_rows - 1)
    let base_color : UInt32 = if subheader && row_index == header_rows - 1 {
      0x7f7f7fffU
    } else {
      0x000000ffU
    }
    for column, cell in row {
      if column >= 16384 {
        break
      }
      if cell.text == "" {
        continue
      }
      let (bold, color) = if style is Some(style) &&
        table_rows > 0 &&
        column <= last_col &&
        row_index < table_rows &&
        row_index >= header {
        let styled = style.at(
          row_index,
          column,
          table_rows,
          last_col + 1,
          header,
        )
        (styled.bold, styled.color)
      } else {
        (base_bold, base_color)
      }
      let layout = grid_cell_layout(
        row, cell, column, col_positions, y, height, bold, language, advance, ascent,
        descent,
      )
      let ref = cell_reference(
        row_index,
        column,
        row_index < geometry.frozen_rows,
      )
      for tile in context.in_bounds(layout.x0, layout.y0, layout.x1, layout.y1) {
        tile.emit_cell(layout, ref, family, bold, color, advance, font, hash)
      }
    }
  }
  let result : Array[GridTile] = []
  if style is Some(style) && table_rows > 0 {
    context.paint_table_borders(
      style,
      table_rows,
      last_col + 1,
      header,
      col_positions,
      row_positions,
    )
    if header > 0 {
      context.paint_table_buttons(last_col + 1, col_positions, row_positions)
    }
  }
  for tile in context.tiles {
    result.push({
      x: tile.x,
      y: tile.y,
      object: tile.object.encode(),
      drawn: tile.drawn,
    })
  }
  { geometry, tiles: result, }
}
