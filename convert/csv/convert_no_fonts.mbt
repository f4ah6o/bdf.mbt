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
    no_woff2=true,
  )
}

///|
/// Convert CSV using one explicitly supplied TrueType or OpenType font.
/// TrueType and CFF glyph outlines are subsetted when supported and allowed;
/// `no_subset` embeds
/// the full font. `font_index` selects a face within a TTC collection.
/// Automatic font selection is not supported by this single-font entry point.
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
  no_woff2~ : Bool = false,
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
    no_woff2~,
  )
}

///|
/// Convert CSV with fonts supplied through an in-memory database. Each
/// character uses the upstream family and glyph fallback order. The host adds
/// font files to the database and can request system-font references instead
/// of embedding.
pub fn convert_with_fonts(
  data : Bytes,
  database : @fontdb.Database,
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
  no_woff2~ : Bool = false,
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
    no_subset~,
    ignore_embedding_restrictions~,
    system_fonts~,
    no_woff2~,
    database=Some(database),
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
  no_woff2~ : Bool,
  database~ : @fontdb.Database? = None,
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
  let (drawn, missing, font_warnings, has_fonts) = match (database, face) {
    (Some(db), _) if db.faces().length() > 0 => {
      let (system_grid, usage) = @sheet.draw_grid_with_database_usage(
        cells,
        db,
        header_rows=grid.header_rows,
        language~,
        table_style~,
      )
      let ordered = usage.faces.copy()
      ordered.sort_by((a, b) => {
        let left = db.face(a.face).unwrap()
        let right = db.face(b.face).unwrap()
        let path_order = csv_path_compare(left.path, right.path)
        if path_order == 0 {
          left.index.compare(right.index)
        } else {
          path_order
        }
      })
      let hashes : Map[Int32, String] = Map([])
      let font_warnings : Array[String] = []
      if !system_fonts {
        for used in ordered {
          let font = db.face(used.face).unwrap().font
          let (program, warning) = csv_embed_font(
            font,
            font.byte_length(),
            used.codepoints,
            no_subset,
            ignore_embedding_restrictions,
          )
          match warning {
            Some(warning) => font_warnings.push(warning)
            None => ()
          }
          match program {
            Some(program) =>
              hashes[used.face] = writer.add_part(
                "font",
                csv_encode_font(program, no_woff2, font_warnings),
              )
            None => ()
          }
        }
      }
      let drawn = if hashes.length() == 0 {
        system_grid
      } else {
        @sheet.draw_grid_with_database(
          cells,
          db,
          hashes,
          header_rows=grid.header_rows,
          language~,
          table_style~,
        )
      }
      (drawn, usage.missing, font_warnings, true)
    }
    (_, Some(font)) => {
      let (system_grid, usage) = @sheet.draw_grid_with_font_usage(
        cells,
        font,
        header_rows=grid.header_rows,
        language~,
        table_style~,
      )
      let (program, font_warning) = match font_data {
        Some(bytes) if usage.used && !system_fonts =>
          csv_embed_font(
            font,
            bytes.length(),
            usage.codepoints,
            no_subset,
            ignore_embedding_restrictions,
          )
        _ => (None, None)
      }
      let encode_warnings : Array[String] = []
      let hash = match program {
        Some(bytes) =>
          Some(
            writer.add_part(
              "font",
              csv_encode_font(bytes, no_woff2, encode_warnings),
            ),
          )
        None => None
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
      match font_warning {
        Some(warning) => encode_warnings.push(warning)
        None => ()
      }
      (drawn, usage.missing, encode_warnings, true)
    }
    _ =>
      (
        @sheet.draw_grid_no_fonts(
          cells,
          header_rows=grid.header_rows,
          language~,
          table_style~,
        ),
        [],
        [],
        false,
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
  if !has_fonts && !system_fonts {
    warnings.push(
      "no fonts found; text is laid out with estimated metrics and not embedded",
    )
  } else {
    for warning in font_warnings {
      warnings.push(warning)
    }
    match csv_missing_warning(missing) {
      Some(warning) => warnings.push(warning)
      None => ()
    }
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
