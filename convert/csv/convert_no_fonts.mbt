///|
/// The result of converting CSV to a BDF sheet with fallback font metrics.
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
  let parsed = parse(data, charset~, delimiter~, quote~, header~)
  if table_style != "" && !@sheet.is_builtin_table_style(table_style) {
    raise InvalidDialect(
      "csv: unknown table style " + csv_go_quote(table_style, '"'),
    )
  }
  let decoded = decode_text(data, charset~)
  let language = guess_language(decoded.text, decoded.charset)
  let grid = prepare_grid(parsed)
  let drawn = @sheet.draw_grid_no_fonts(
    sheet_cells(grid),
    header_rows=grid.header_rows,
    language~,
    table_style~,
  )
  let meta : Map[String, Json] = {
    "source": Json::string("csv"),
    "generator": Json::string("bdf-go/0.1"),
  }
  if title != "" {
    meta["dc"] = Json::object({ "title": Json::string(title) })
  }
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
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
  warnings.push(
    "no fonts found; text is laid out with estimated metrics and not embedded",
  )
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
