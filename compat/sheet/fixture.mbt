///|
fn cell(text : String, number~ : Bool = false) -> @sheet.Cell {
  { text, number, }
}

///|
#export_name("column_fixture")
pub fn column_fixture(which : Int32) -> String {
  if which == 4 {
    let parsed = try! @csv.parse(
      @utf8.encode("name,amount,note\nAnn,1,abc\nBob,2.5,very long note here\n"),
      header=HeaderYes,
    )
    let widths = try! @csv.fit_grid_columns(@csv.prepare_grid(parsed))
    return Json::array(widths.map(value => Json::number(value.to_double()))).stringify()
  }
  let rows : Array[Array[@sheet.Cell]] = match which {
    0 =>
      [
        [cell("name"), cell("amount"), cell("note")],
        [cell("Ann"), cell("1,234.50", number=true), cell("two\r\nlines")],
        [cell("Bob"), cell("7", number=true), cell("long note ".repeat(20))],
      ]
    1 =>
      [
        [cell("X".repeat(300)), cell("1234567890".repeat(100), number=true)],
        [cell(""), cell("9", number=true)],
      ]
    2 =>
      [
        [
          cell("日本語"),
          cell("漢字\t  ABC"),
          cell("one\rshort\nlonger line"),
        ],
        [cell(" "), cell("\u{16fe2}\u{feff}文字"), cell("abc\u{200b}xyz")],
      ]
    _ =>
      [
        [cell("Header name"), cell("数字"), cell("x")],
        [cell("a"), cell("1", number=true)],
      ]
  }
  let widths = try! @sheet.fit_columns(
    rows,
    header_rows=1,
    filter_buttons=which == 3,
  )
  Json::array(widths.map(value => Json::number(value.to_double()))).stringify()
}

///|
#export_name("wrap_fixture")
pub fn wrap_fixture(text : String, width : Double) -> String {
  let lines = @sheet.wrap_text(text, width, advance=(_, _) => 1.0)
  Json::array(
    lines.map(line => {
      Json::object({
        "Text": Json::string(line.text),
        "Width": Json::number(line.width),
        "Explicit": Json::boolean(line.explicit),
        "Wrapped": Json::boolean(line.wrapped),
        "CJK": Json::boolean(line.cjk_wrap),
      })
    }),
  ).stringify()
}

///|
#export_name("row_fixture")
pub fn row_fixture(which : Int32) -> String {
  let rows : Array[Array[@sheet.Cell]] = match which {
    0 =>
      [
        [cell("a"), cell("b")],
        [cell("one\ntwo"), cell("x")],
        [cell("ordinary")],
      ]
    1 =>
      [
        [cell("header\nlabel")],
        [cell("wide words ".repeat(30) + "\nlast")],
        [cell("after")],
      ]
    2 =>
      [
        [cell("1\n" + "234567890".repeat(30), number=true)],
        [cell("日本語、漢字\n１２３")],
        [cell("")],
        [],
      ]
    _ => [[cell("a\n".repeat(40))], [cell("one\r\ntwo\rthree")]]
  }
  let header = if which < 2 { 1 } else { 0 }
  let columns = try! @sheet.fit_columns(rows, header_rows=header)
  let heights = try! @sheet.fit_rows(rows, columns, header_rows=header)
  Json::array(heights.map(value => Json::number(value.to_double()))).stringify()
}

///|
#export_name("line_break_fixture")
pub fn line_break_fixture(mode : Int32, code : Int32) -> Bool {
  let character = code.unsafe_to_char()
  match mode {
    0 => @sheet.line_break_allowed('-', character)
    1 => @sheet.line_break_allowed('x', character)
    2 => @sheet.line_break_allowed(character, 'x')
    _ => @sheet.line_break_joins('x', character)
  }
}
