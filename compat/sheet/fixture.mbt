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
