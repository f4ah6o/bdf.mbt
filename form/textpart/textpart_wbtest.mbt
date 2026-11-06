///|
fn sample_image() -> Image {
  {
    version: VERSION,
    cpi: 10.0,
    lpi: 6.0,
    columns: 40,
    lines: 12,
    margin: { left: 2, top: 1 },
    skip: 1,
    ambiguous_wide: false,
    font: "",
    pages: [
      {
        lines: [
          {
            text: "納品書 No.12",
            paper: [],
            size: [Range::new(0, 12, SIZE_BIG)],
          },
          Line::new(""),
          { text: "┌──┐", paper: [Range::new(0, 4, "")], size: [] },
          {
            text: "│ペン│ 2",
            paper: [Range::new(0, 1, ""), Range::new(5, 1, "")],
            size: [],
          },
          Line::new("e\u{301}x"),
        ],
      },
      { lines: [{ text: "AB", paper: [], size: [Range::new(0, 2, SIZE_WIDE)] }] },
    ],
  }
}

///|
fn cell_flat(cell : Cell) -> (String, Int, Int, String, Bool) {
  (cell.text, cell.col, cell.cols, cell.size, cell.paper)
}

///|
test "textpart widths" {
  let cases : Array[(Char, Int, Int)] = [
    ('A', 1, 1),
    (' ', 1, 1),
    ('ｱ', 1, 1),
    ('漢', 2, 2),
    ('あ', 2, 2),
    ('Ａ', 2, 2),
    ('　', 2, 2),
    ('─', 1, 2),
    ('│', 1, 2),
    ('○', 1, 2),
    ('※', 1, 2),
    ('α', 1, 2),
    ('\u{301}', 0, 0),
    ('\u{200b}', 0, 0),
    ('\u{fe0f}', 0, 0),
    ('\t', 0, 0),
    ('\u{7f}', 0, 0),
    ('\u{1f600}', 2, 2),
    ('\u{20b9f}', 2, 2),
  ]
  for entry in cases {
    assert_eq(width(entry.0, false), entry.1, msg="narrow")
    assert_eq(width(entry.0, true), entry.2, msg="east asian")
  }
}

///|
test "textpart cells and rows" {
  let image = sample_image()
  let cells = image.cells(image.pages[0].lines[0])
  assert_eq(cells.length(), 9)
  assert_eq(cell_flat(cells[0]), ("納", 0, 4, SIZE_BIG, false))
  assert_eq(cell_flat(cells[3]), (" ", 12, 1, "", false))
  assert_eq(cell_flat(cells[8]), ("2", 17, 1, "", false))
  let paper = image.cells(image.pages[0].lines[3])
  assert_true(paper[0].paper, msg="the first rule")
  assert_false(paper[1].paper, msg="the space after the rule")
  assert_eq(paper[1].col, 1)
  assert_eq(paper[3].col, 5)
  assert_true(paper[3].paper, msg="the last rule")
  assert_false(paper[4].paper, msg="the space after the last rule")
  let combining = image.cells(image.pages[0].lines[4])
  assert_eq(combining.length(), 2)
  assert_eq(combining[0].text, "e\u{301}")
  assert_eq(combining[1].col, 1)
  assert_true(image.pages[0].lines[0].tall(), msg="a big line is tall")
  assert_false(image.pages[1].lines[0].tall(), msg="a wide line is not tall")
  assert_eq(image.rows(image.pages[0]), 10)
}

///|
test "textpart text" {
  let image = sample_image()
  assert_eq(
    image.text({ margins: false, no_paper: false, crlf: false }),
    "納  品  書   No.12\n\n┌──┐\n│ペン│ 2\ne\u{301}x\n\u{c}A B\n",
  )
  assert_eq(
    image.text({ margins: true, no_paper: true, crlf: true }),
    "\r\n  納  品  書   No.12\r\n\r\n\r\n   ペン  2\r\n  e\u{301}x\r\n\u{c}\r\n  A B\r\n",
  )
}

///|
test "textpart JSON round trip" {
  let image = sample_image()
  let text = image.encode()
  assert_true(
    text.contains(
      "{\"version\":1,\"cpi\":10,\"lpi\":6,\"columns\":40,\"lines\":12,\"margin\":{\"left\":2,\"top\":1},\"skip\":1,\"pages\":[{\"lines\":[{\"text\":\"納品書 No.12\",\"size\":[{\"col\":0,\"cols\":12,\"size\":\"big\"}]},{\"text\":\"\"}",
    ),
    msg="the JSON order",
  )
  let back = decode(text)
  assert_eq(back.version, image.version)
  assert_eq(back.columns, image.columns)
  assert_eq(back.pages.length(), image.pages.length())
  assert_eq(back.pages[0].lines.length(), image.pages[0].lines.length())
  assert_eq(back.pages[0].lines[0].text, image.pages[0].lines[0].text)
  assert_eq(back.pages[0].lines[0].size[0].size, SIZE_BIG)
}

///|
test "textpart rejects bad images" {
  let bad : Array[String] = [
    "{\"version\":2,\"cpi\":10,\"lpi\":6,\"columns\":80,\"lines\":66,\"margin\":{\"left\":0,\"top\":0},\"pages\":[]}",
    "{\"version\":1,\"cpi\":0,\"lpi\":6,\"columns\":80,\"lines\":66,\"margin\":{\"left\":0,\"top\":0},\"pages\":[]}",
    "{\"version\":1,\"cpi\":10,\"lpi\":6,\"columns\":0,\"lines\":66,\"margin\":{\"left\":0,\"top\":0},\"pages\":[]}",
    "{\"version\":1,\"cpi\":10,\"lpi\":6,\"columns\":80,\"lines\":6,\"margin\":{\"left\":0,\"top\":4},\"skip\":2,\"pages\":[]}",
    "{\"version\":1,\"cpi\":10,\"lpi\":6,\"columns\":80,\"lines\":2,\"margin\":{\"left\":0,\"top\":0},\"pages\":[{\"lines\":[{\"text\":\"\"},{\"text\":\"\"},{\"text\":\"\"}]}]}",
    "{\"version\":1,\"cpi\":10,\"lpi\":6,\"columns\":80,\"lines\":0,\"margin\":{\"left\":0,\"top\":0},\"pages\":[{\"lines\":[{\"text\":\"ab\",\"paper\":[{\"col\":0,\"cols\":2},{\"col\":1,\"cols\":1}]}]}]}",
    "{\"version\":1,\"cpi\":10,\"lpi\":6,\"columns\":80,\"lines\":0,\"margin\":{\"left\":0,\"top\":0},\"pages\":[{\"lines\":[{\"text\":\"ab\",\"paper\":[{\"col\":0,\"cols\":0}]}]}]}",
    "{\"version\":1,\"cpi\":10,\"lpi\":6,\"columns\":80,\"lines\":0,\"margin\":{\"left\":0,\"top\":0},\"pages\":[{\"lines\":[{\"text\":\"ab\",\"size\":[{\"col\":0,\"cols\":2,\"size\":\"huge\"}]}]}]}",
    "[]",
  ]
  for value in bad {
    let rejected = try {
      ignore(decode(value))
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg="decode accepts " + value)
  }
}
