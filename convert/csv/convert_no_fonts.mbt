///|
/// The result of converting CSV to a BDF sheet.
pub(all) struct NoFontResult {
  bdf : Bytes
  parsed : ParseResult
  warnings : Array[String]
}

///|
/// Convert CSV to a BDF sheet using the upstream converter's
/// no-font fallback. This explicit mode does not yet discover or embed fonts.
pub fn convert_no_fonts(
  data : Bytes,
  name~ : String = "",
  title~ : String = "",
  charset~ : String = "",
  delimiter~ : Byte = 0,
  quote~ : Int32 = 0,
  header~ : Header = HeaderAuto,
  data_mode~ : DataMode = DataDefault,
  no_text_index~ : Bool = false,
  table_style~ : String = "",
) -> NoFontResult raise {
  convert_grid(
    data,
    name~,
    title~,
    charset~,
    delimiter~,
    quote~,
    header~,
    data_mode~,
    no_text_index~,
    table_style~,
    font_data=None,
    font_index=0,
    no_subset=false,
    ignore_embedding_restrictions=false,
    system_fonts=false,
  )
}

///|
/// Convert CSV using one explicitly supplied TrueType or OpenType font.
/// TrueType glyph outlines are subsetted when allowed; `no_subset` embeds
/// the full font. `font_index` selects a face within a TTC collection.
/// Automatic font selection, CFF subsetting and WOFF2 are not yet supported.
/// Set `system_fonts` to use font names without embedding.
pub fn convert_with_font(
  data : Bytes,
  font_data : Bytes,
  font_index~ : Int32 = 0,
  no_subset~ : Bool = false,
  name~ : String = "",
  title~ : String = "",
  charset~ : String = "",
  delimiter~ : Byte = 0,
  quote~ : Int32 = 0,
  header~ : Header = HeaderAuto,
  data_mode~ : DataMode = DataDefault,
  no_text_index~ : Bool = false,
  table_style~ : String = "",
  ignore_embedding_restrictions~ : Bool = false,
  system_fonts~ : Bool = false,
) -> NoFontResult raise {
  convert_grid(
    data,
    name~,
    title~,
    charset~,
    delimiter~,
    quote~,
    header~,
    data_mode~,
    no_text_index~,
    table_style~,
    font_data=Some(font_data),
    font_index~,
    no_subset~,
    ignore_embedding_restrictions~,
    system_fonts~,
  )
}

///|
fn convert_grid(
  data : Bytes,
  name~ : String,
  title~ : String,
  charset~ : String,
  delimiter~ : Byte,
  quote~ : Int32,
  header~ : Header,
  data_mode~ : DataMode,
  no_text_index~ : Bool,
  table_style~ : String,
  font_data~ : Bytes?,
  font_index~ : Int32,
  no_subset~ : Bool,
  ignore_embedding_restrictions~ : Bool,
  system_fonts~ : Bool,
) -> NoFontResult raise {
  let parsed = parse(data, charset~, delimiter~, quote~, header~)
  if table_style != "" && !@sheet.is_builtin_table_style(table_style) {
    raise InvalidDialect(
      "csv: unknown table style " + csv_go_quote(table_style, '"'),
    )
  }
  let decoded = decode_text(data, charset~)
  let language = guess_language(decoded.text, decoded.charset)
  let grid = prepare_grid(parsed)
  let cells = sheet_cells(grid)
  let face = match font_data {
    Some(bytes) => {
      let face = @sfnt.parse(bytes, index=font_index)
      if face.info.family == "" || face.metrics.glyph_count == 0 {
        raise InvalidDialect("font has no usable glyph data or family name")
      }
      Some(face)
    }
    None => None
  }
  let meta : Map[String, Json] = {
    "source": Json::string("csv"),
    "generator": Json::string("bdf-go/0.1"),
  }
  if title != "" {
    meta["dc"] = Json::object({ "title": Json::string(title) })
  }
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let (drawn, usage) = match face {
    Some(font) => {
      let (system_grid, usage) = @sheet.draw_grid_with_font_usage(
        cells,
        font,
        header_rows=grid.header_rows,
        language~,
        table_style~,
      )
      let hash = match font_data {
        Some(_) if usage.used &&
          !system_fonts &&
          (font.metrics.embeddable || ignore_embedding_restrictions) => {
          let program = if no_subset {
            font.canvas_program()
          } else if font.metrics.subsettable || ignore_embedding_restrictions {
            match font.subset_program(usage.codepoints) {
              Some(subset) => subset
              None => font.mapped_program(usage.codepoints)
            }
          } else {
            font.mapped_program(usage.codepoints)
          }
          Some(writer.add_part("font", program))
        }
        _ => None
      }
      let drawn = match hash {
        Some(_) =>
          @sheet.draw_grid_with_font(
            cells,
            font,
            hash~,
            header_rows=grid.header_rows,
            language~,
            table_style~,
          )
        None => system_grid
      }
      (drawn, Some(usage))
    }
    None =>
      (
        @sheet.draw_grid_no_fonts(
          cells,
          header_rows=grid.header_rows,
          language~,
          table_style~,
        ),
        None,
      )
  }
  @sheet.store_grid(
    writer,
    drawn,
    title=if name == "" { "Sheet1" } else { name },
    text_index=!no_text_index,
  )
  let warnings = [ for warning in parsed.warnings => warning ]
  if data_mode != DataNone {
    match values_table(parsed) {
      Some(table) =>
        match
          store_table(writer, table, title=name, view="sheet1", mode=data_mode) {
          Some(warning) => warnings.push(warning)
          None => ()
        }
      None => ()
    }
  }
  match (face, usage) {
    (None, _) =>
      warnings.push(
        "no fonts found; text is laid out with estimated metrics and not embedded",
      )
    (Some(font), Some(usage)) => {
      if usage.used &&
        !system_fonts &&
        !font.metrics.embeddable &&
        !ignore_embedding_restrictions {
        warnings.push(
          "font " +
          font.info.family +
          " is not embedded: its license does not allow embedding",
        )
      }
      match csv_missing_warning(usage.missing) {
        Some(warning) => warnings.push(warning)
        None => ()
      }
    }
    _ => ()
  }
  let mut warned_cols = false
  for i, row in grid.rows {
    if i >= 1048576 {
      warnings.push(
        "only the first 1048576 rows are shown (the most a sheet has)",
      )
      break
    }
    if row.length() > 16384 && !warned_cols {
      warnings.push(
        "only the first 16384 columns are shown (the most a sheet has)",
      )
      warned_cols = true
    }
  }
  { bdf: writer.write_single(), parsed, warnings, }
}
