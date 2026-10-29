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
#export_name("geometry_fixture")
pub fn geometry_fixture(which : Int32) -> String {
  if which == 46 {
    let parsed = try! @csv.parse(
      @utf8.encode(
        "name,amount,note\nAnn,1,abc\nBob,2.5,\"very long\nnote here\"\n",
      ),
      header=HeaderYes,
    )
    return geometry_json(try! @csv.grid_geometry(@csv.prepare_grid(parsed)))
  }
  let rows : Array[Array[@sheet.Cell]] = match which {
    0 => []
    1 =>
      [[cell("name"), cell("value")], [cell("Alice"), cell("12", number=true)]]
    2 => [[cell("long text ".repeat(200))]]
    3 => [[cell("long text ".repeat(200)), cell(""), cell("stop")]]
    4 => {
      let rows : Array[Array[@sheet.Cell]] = [[cell("head")]]
      for _ in 1..<40 {
        rows.push([])
      }
      rows
    }
    5 =>
      [
        [cell("a\nb\nc"), cell("123456".repeat(50), number=true)],
        [cell("last")],
      ]
    _ => {
      let i = which - 6
      let rows : Array[Array[@sheet.Cell]] = []
      for r in 0..<3 {
        let row : Array[@sheet.Cell] = []
        for col in 0..<3 {
          let n = (i * 37 + r * 53 + col * 97) % 1100
          let mut text = "x".repeat(n)
          if (i + r + col) % 5 == 0 {
            text += "\nend"
          }
          row.push(cell(text, number=(i + r + col) % 3 == 0))
        }
        rows.push(row)
      }
      rows
    }
  }
  let header = if which == 1 {
    1
  } else if which == 4 {
    32
  } else if which >= 6 {
    (which - 6) % 3
  } else {
    0
  }
  let geometry = try! @sheet.grid_geometry(rows, header_rows=header)
  geometry_json(geometry)
}

///|
fn geometry_json(geometry : @sheet.GridGeometry) -> String {
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
    "cols": runs(geometry.columns),
    "rows": runs(geometry.rows),
    "frozen": Json::number(geometry.frozen_rows.to_double()),
  }).stringify()
}

///|
fn drawing_fixture(which : Int32) -> @sheet.DrawnGrid {
  let rows : Array[Array[@sheet.Cell]] = match which {
    0 => []
    1 => [[cell("hello")]]
    2 =>
      [[cell("name"), cell("value")], [cell("Alice"), cell("12", number=true)]]
    3 => [[cell("a\nb"), cell("  ")]]
    4 =>
      [
        [cell("日本語ABC 漢字"), cell("123", number=true)],
        [cell("漢字"), cell("カナ 한글")],
      ]
    5 => [[cell("long text ".repeat(200)), cell(""), cell("stop")]]
    6 => {
      let rows : Array[Array[@sheet.Cell]] = []
      for _ in 0..<160 {
        rows.push([cell("row"), cell("7", number=true)])
      }
      rows
    }
    7 => [[cell("   ")]]
    8 => {
      let row : Array[@sheet.Cell] = []
      for _ in 0..<65 {
        row.push(cell("xx"))
      }
      [row]
    }
    9 => [[cell("a\n".repeat(40))], [cell("next")]]
    10 =>
      [[cell("\u{feff}Hello"), cell("\t  x  ")], [cell("\u{1}"), cell("done")]]
    11 => [[cell("Header")], [cell("Subheader")], [cell("Value")]]
    12 => [[cell("漢字"), cell("English")], [cell("かな"), cell("한글")]]
    _ => {
      let i = which - 13
      let texts = [
        "English \t text", "カナ abc 漢字", "한글 ab", "漢字", "abc\n def",
        "  ", "", "abc-def xyz",
      ]
      let rows : Array[Array[@sheet.Cell]] = []
      for r in 0..<3 {
        let row : Array[@sheet.Cell] = []
        for col in 0..<3 {
          let mut text = texts[(i * 3 + r * 5 + col * 7) % texts.length()]
          if (i + r + col) % 11 == 0 {
            text += "xy".repeat(300)
          }
          row.push(cell(text, number=(i + r + col) % 4 == 0))
        }
        rows.push(row)
      }
      rows
    }
  }
  let header = if which >= 1 && which <= 4 {
    1
  } else if which == 11 {
    2
  } else if which >= 13 {
    (which - 13) % 3
  } else {
    0
  }
  let language = if which == 4 {
    "ja"
  } else if which == 12 {
    "zh-TW"
  } else if which >= 13 {
    ["", "ja", "ko", "zh-CN", "zh-TW"][(which - 13) % 5]
  } else {
    ""
  }
  try! @sheet.draw_grid_no_fonts(
    rows,
    header_rows=header,
    language~,
    subheader=which == 11,
  )
}

///|
#export_name("drawing_summary")
pub fn drawing_summary(which : Int32) -> String {
  let grid = drawing_fixture(which)
  Json::array(
    grid.tiles.map(tile => {
      Json::object({
        "x": Json::number(tile.x.to_double()),
        "y": Json::number(tile.y.to_double()),
        "drawn": Json::boolean(tile.drawn),
      })
    }),
  ).stringify()
}

///|
#export_name("drawing_tile")
pub fn drawing_tile(which : Int32, tile : Int32) -> Bytes {
  drawing_fixture(which).tiles[tile].object
}

///|
fn styled_fixture(style : String, which : Int32) -> @sheet.DrawnGrid {
  let rows : Array[Array[@sheet.Cell]] = match which {
    0 =>
      [
        [cell("Name"), cell("Total"), cell("Note")],
        [cell("Alice"), cell("12", number=true), cell("")],
        [cell("Bob"), cell("3", number=true), cell("one\ntwo")],
        [cell(""), cell(""), cell("")],
      ]
    1 =>
      [
        [cell("漢字"), cell("A")],
        [cell("かな"), cell("1", number=true)],
        [cell("B"), cell("2", number=true)],
      ]
    2 =>
      [
        [cell("Header"), cell("Value")],
        [cell("Sub"), cell("")],
        [cell("First"), cell("7", number=true)],
        [cell("Second"), cell("8", number=true)],
      ]
    3 => {
      let rows : Array[Array[@sheet.Cell]] = []
      for r in 0..<140 {
        let row : Array[@sheet.Cell] = []
        for col in 0..<45 {
          row.push(cell(if (r + col) % 7 == 0 { "" } else { "x" }))
        }
        rows.push(row)
      }
      rows
    }
    4 => {
      let rows : Array[Array[@sheet.Cell]] = [[cell("only")]]
      for _ in 1..<45 {
        rows.push([])
      }
      rows
    }
    _ => [[cell("")]]
  }
  try! @sheet.draw_grid_no_fonts(
    rows,
    table_style=style,
    header_rows=if which == 1 { 0 } else if which == 2 { 2 } else { 1 },
    subheader=which == 2,
    language=if which == 1 { "ja" } else { "" },
  )
}

///|
#export_name("styled_summary")
pub fn styled_summary(style : String, which : Int32) -> String {
  let grid = styled_fixture(style, which)
  Json::object({
    "geometry": Json::string(geometry_json(grid.geometry)),
    "tiles": Json::array(
      grid.tiles.map(tile => {
        Json::object({
          "x": Json::number(tile.x.to_double()),
          "y": Json::number(tile.y.to_double()),
          "drawn": Json::boolean(tile.drawn),
        })
      }),
    ),
  }).stringify()
}

///|
#export_name("styled_tile")
pub fn styled_tile(style : String, which : Int32, tile : Int32) -> Bytes {
  styled_fixture(style, which).tiles[tile].object
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
