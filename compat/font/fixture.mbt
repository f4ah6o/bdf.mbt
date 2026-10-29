///|
#export_name("load_font")
pub fn load_font(data : Bytes, index : Int32) -> @sfnt.Font {
  try! @sfnt.parse(data, index~)
}

///|
#export_name("glyph")
pub fn glyph(font : @sfnt.Font, code : Int32) -> Int32 {
  font.glyph(code).unwrap_or(0)
}

///|
#export_name("advance")
pub fn advance(font : @sfnt.Font, glyph : Int32) -> Int32 {
  font.advance_units(glyph)
}

///|
#export_name("metrics")
pub fn metrics(font : @sfnt.Font) -> String {
  let m = font.metrics
  let info = font.info
  Json::object({
    "count": Json::number(m.glyph_count.to_double()),
    "upem": Json::number(m.units_per_em.to_double()),
    "cff": Json::boolean(m.is_cff),
    "ascent": Json::number(m.ascent),
    "descent": Json::number(m.descent),
    "underlinePos": Json::number(m.underline_position),
    "underlineThick": Json::number(m.underline_thickness),
    "capHeight": Json::number(m.cap_height),
    "embeddable": Json::boolean(m.embeddable),
    "subsettable": Json::boolean(m.subsettable),
    "family": Json::string(info.family),
    "style": Json::string(info.style),
    "weight": Json::number(info.weight.to_double()),
    "italic": Json::boolean(info.italic),
    "monospace": Json::boolean(info.monospace),
    "math": Json::boolean(info.has_math),
  }).stringify()
}

///|
fn cell(text : String, number~ : Bool = false) -> @sheet.Cell {
  { text, number, }
}

///|
#export_name("geometry")
pub fn geometry(font : @sfnt.Font, scenario : Int32) -> String {
  let cells = scenario_cells(scenario)
  let result = try! @sheet.grid_geometry_with_font(
    cells,
    font,
    header_rows=if scenario == 1 || scenario >= 5 {
      0
    } else if scenario == 4 {
      2
    } else {
      1
    },
    subheader=scenario == 4,
    filter_buttons=scenario == 3,
    table_rows=if scenario == 3 { cells.length() } else { 0 },
    language=match scenario {
      1 => "ja"
      5 => "ko"
      6 => "zh-CN"
      7 => "zh-TW"
      _ => ""
    },
  )
  let runs = (items : Array[@sheet.Run]) => {
    Json::array(
      items.map(run => {
        Json::array([
          Json::number(run.count.to_double()),
          Json::number(run.size.to_double()),
        ])
      }),
    )
  }
  Json::object({
    "cols": runs(result.columns),
    "rows": runs(result.rows),
    "frozen": Json::number(result.frozen_rows.to_double()),
  }).stringify()
}

///|
fn scenario_cells(scenario : Int32) -> Array[Array[@sheet.Cell]] {
  match scenario {
    0 =>
      [
        [cell("Name"), cell("Amount"), cell("Notes")],
        [cell("Alice"), cell("123.45", number=true), cell("line\nwrap")],
        [cell("Bob"), cell("-12", number=true), cell("small text")],
      ]
    1 =>
      [
        [cell("A"), cell("B")],
        [cell("C"), cell("200", number=true)],
        [cell("漢字カナ"), cell("7", number=true)],
      ]
    2 =>
      [
        [cell("wide text ".repeat(120)), cell(""), cell("end")],
        [cell("a\nb\nc"), cell("0123")],
      ]
    3 =>
      [
        [cell("name"), cell("value")],
        [cell("alpha"), cell("22", number=true)],
        [cell("beta"), cell("333", number=true)],
      ]
    4 =>
      [
        [cell("head"), cell("summary")],
        [cell("sub"), cell("")],
        [cell("x\n日本語"), cell("3", number=true)],
      ]
    _ =>
      [
        [cell("漢字"), cell("A")],
        [cell("한글"), cell("1", number=true)],
        [cell("中文字"), cell("2", number=true)],
      ]
  }
}

///|
#export_name("drawing_tile")
pub fn drawing_tile(
  font : @sfnt.Font,
  scenario : Int32,
  hash : String,
  index : Int32,
) -> Bytes {
  let cells = scenario_cells(scenario)
  let result = try! @sheet.draw_grid_with_font(
    cells,
    font,
    hash=if hash == "" { None } else { Some(hash) },
    header_rows=if scenario == 1 || scenario >= 5 {
      0
    } else if scenario == 4 {
      2
    } else {
      1
    },
    subheader=scenario == 4,
    table_style=if scenario == 3 { "Medium2" } else { "" },
    language=match scenario {
      1 => "ja"
      5 => "ko"
      6 => "zh-CN"
      7 => "zh-TW"
      _ => ""
    },
  )
  result.tiles[index].object
}

///|
fn csv_result(
  data : Bytes,
  font : Bytes,
  scenario : Int32,
  index : Int32,
) -> @csv.NoFontResult raise {
  let kind = scenario % 7
  @csv.convert_with_font(
    no_woff2=true,
    data,
    font,
    font_index=index,
    no_subset=scenario < 7,
    name="People",
    title="Report",
    header=if kind == 3 { HeaderNo } else { HeaderYes },
    data_mode=if kind == 3 { DataNone } else { DataDefault },
    table_style=if kind == 2 { "Medium2" } else { "" },
    quote=if kind == 4 { -1 } else { 0 },
    system_fonts=kind == 5,
    ignore_embedding_restrictions=kind == 6,
  )
}

///|
#export_name("csv_document")
pub fn csv_document(
  data : Bytes,
  font : Bytes,
  scenario : Int32,
  index : Int32,
) -> Bytes {
  (try! csv_result(data, font, scenario, index)).bdf
}

///|
#export_name("csv_warnings")
pub fn csv_warnings(
  data : Bytes,
  font : Bytes,
  scenario : Int32,
  index : Int32,
) -> String {
  Json::array(
    (try! csv_result(data, font, scenario, index)).warnings.map(w => {
      Json::string(w)
    }),
  ).stringify()
}

///|
#export_name("canvas_program")
pub fn canvas_program(font : @sfnt.Font) -> Bytes {
  try! font.canvas_program()
}

///|
#export_name("subset_program")
pub fn subset_program(font : @sfnt.Font, text : String) -> Bytes {
  let codepoints : Array[Int32] = [ for ch in text => ch.to_int() ]
  (try! font.subset_program(codepoints)).unwrap()
}

///|
#export_name("truetype_outline")
pub fn truetype_outline(font : @sfnt.Font, glyph : Int32) -> String {
  let (ok, commands) = font.outline_truetype(glyph)
  let paths = commands.map(command => {
    let (kind, values) = match command {
      @sfnt.Move(x, y) => ("M", [x, y])
      @sfnt.Line(x, y) => ("L", [x, y])
      @sfnt.Quad(a, b, c, d) => ("Q", [a, b, c, d])
      @sfnt.Cubic(a, b, c, d, e, f) => ("C", [a, b, c, d, e, f])
      @sfnt.Close => ("Z", [])
    }
    let row = [Json::string(kind)]
    for value in values {
      row.push(Json::number(value))
    }
    Json::array(row)
  })
  let bounds = match font.bounds_truetype(glyph) {
    None => Json::null()
    Some((a, b, c, d)) =>
      Json::array([
        Json::number(a),
        Json::number(b),
        Json::number(c),
        Json::number(d),
      ])
  }
  Json::object({
    "ok": Json::boolean(ok),
    "commands": Json::array(paths),
    "bounds": bounds,
  }).stringify()
}

///|
#export_name("has_cff_outlines")
pub fn has_cff_outlines(font : @sfnt.Font) -> Bool {
  font.cff_outlines() is Some(_)
}

///|
#export_name("load_cff_outlines")
pub fn load_cff_outlines(font : @sfnt.Font) -> @sfnt.CffOutlines {
  font.cff_outlines().unwrap()
}

///|
#export_name("cff_outline")
pub fn cff_outline(font : @sfnt.CffOutlines, glyph : Int32) -> String {
  let (ok, commands) = font.outline(glyph)
  let paths = commands.map(command => {
    let (kind, values) = match command {
      @sfnt.Move(x, y) => ("M", [x, y])
      @sfnt.Line(x, y) => ("L", [x, y])
      @sfnt.Quad(a, b, c, d) => ("Q", [a, b, c, d])
      @sfnt.Cubic(a, b, c, d, e, f) => ("C", [a, b, c, d, e, f])
      @sfnt.Close => ("Z", [])
    }
    let row = [Json::string(kind)]
    for value in values {
      row.push(Json::number(value))
    }
    Json::array(row)
  })
  let bounds = match font.bounds(glyph) {
    None => Json::null()
    Some((a, b, c, d)) =>
      Json::array([
        Json::number(a),
        Json::number(b),
        Json::number(c),
        Json::number(d),
      ])
  }
  Json::object({
    "ok": Json::boolean(ok),
    "commands": Json::array(paths),
    "bounds": bounds,
  }).stringify()
}

///|
fn csv_compressed_result(
  data : Bytes,
  font : Bytes,
  scenario : Int32,
  index : Int32,
) -> @csv.NoFontResult raise {
  let kind = scenario % 7
  @csv.convert_with_font(
    data,
    font,
    font_index=index,
    no_subset=scenario < 7,
    name="People",
    title="Report",
    header=if kind == 3 { HeaderNo } else { HeaderYes },
    data_mode=if kind == 3 { DataNone } else { DataDefault },
    table_style=if kind == 2 { "Medium2" } else { "" },
    quote=if kind == 4 { -1 } else { 0 },
    system_fonts=kind == 5,
    ignore_embedding_restrictions=kind == 6,
  )
}

///|
#export_name("csv_compressed_document")
pub fn csv_compressed_document(
  data : Bytes,
  font : Bytes,
  scenario : Int32,
  index : Int32,
) -> Bytes {
  (try! csv_compressed_result(data, font, scenario, index)).bdf
}

///|
#export_name("csv_compressed_warnings")
pub fn csv_compressed_warnings(
  data : Bytes,
  font : Bytes,
  scenario : Int32,
  index : Int32,
) -> String {
  Json::array(
    (try! csv_compressed_result(data, font, scenario, index)).warnings.map(
      Json::string,
    ),
  ).stringify()
}
