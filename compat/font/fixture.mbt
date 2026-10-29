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
  let cells : Array[Array[@sheet.Cell]] = match scenario {
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
