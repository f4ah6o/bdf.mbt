///|
fn front_error(lines : Array[String]) -> String {
  try {
    ignore(parse_front_matter(lines, []))
    ""
  } catch {
    TextFormError(message) => message
  }
}

///|
test "textform grid defaults" {
  let grid = default_grid()
  assert_eq(grid.cpi, 10.0)
  assert_eq(grid.lpi, 6.0)
  assert_eq(grid.columns, 80)
  assert_eq(grid.lines, 66)
  assert_eq(grid.rows(), 66)
  assert_eq(grid.width(), 80)
  let grid = { ..grid, columns: 40, lines: 12, left: 2, top: 1, skip: 1 }
  assert_eq(grid.rows(), 10)
  assert_eq(grid.width(), 38)
}

///|
test "textform front matter split" {
  let (front, body, first, has) = split_front_matter(
    "---\ncolumns: 40\nmargin: {left: 2}\n---\nbody\n",
  )
  assert_true(has, msg="has front matter")
  assert_eq(front.length(), 2)
  assert_eq(front[0], "columns: 40")
  assert_eq(front[1], "margin: {left: 2}")
  assert_eq(body, "body\n")
  assert_eq(first, 5)
  let (front, body, first, has) = split_front_matter("body\n")
  assert_false(has, msg="no front matter")
  assert_eq(front.length(), 0)
  assert_eq(body, "body\n")
  assert_eq(first, 1)
  let (_, body, _, has) = split_front_matter("---\ncolumns: 40\n")
  assert_false(has, msg="unclosed front matter")
  assert_eq(body, "---\ncolumns: 40\n")
  let (_, body, _, has) = split_front_matter("---")
  assert_false(has, msg="a first line only")
  assert_eq(body, "---")
  let (front, body, first, has) = split_front_matter("---\na: 1\n...\nbody")
  assert_true(has, msg="... closes")
  assert_eq(front[0], "a: 1")
  assert_eq(body, "body")
  assert_eq(first, 4)
}

///|
test "textform comments and quotes" {
  assert_eq(strip_comment("a # b"), "a ")
  assert_eq(strip_comment("\"a # b\" # c"), "\"a # b\" ")
  assert_eq(strip_comment("# whole"), "")
  assert_eq(strip_comment("a#b"), "a#b")
  assert_eq(unquote("\"a\\nb\""), "a\nb")
  assert_eq(unquote("'it''s'"), "it's")
  assert_eq(unquote("plain"), "plain")
}

///|
test "textform front matter values" {
  let warnings : Array[String] = []
  let grid = parse_front_matter(
    [
      "columns: 40",
      "lines: 12",
      "margin: {left: 2, top: 1}",
      "skip: 1",
      "title: 1",
      "font: \"Gen\" # the family",
      "ambiguous: wide",
    ],
    warnings,
  )
  assert_eq(grid.columns, 40)
  assert_eq(grid.lines, 12)
  assert_eq(grid.left, 2)
  assert_eq(grid.top, 1)
  assert_eq(grid.skip, 1)
  assert_eq(grid.title, 1)
  assert_eq(grid.font, "Gen")
  assert_true(grid.ambiguous_wide, msg="ambiguous wide")
  assert_eq(grid.rows(), 10)
  assert_eq(warnings.length(), 0)
  let block = parse_front_matter(
    ["margin:", "  left: 3", "  top: 2", "columns: 20"],
    [],
  )
  assert_eq(block.left, 3)
  assert_eq(block.top, 2)
  let warnings : Array[String] = []
  let odd = parse_front_matter(["cpi: 13", "mystery: 1"], warnings)
  assert_eq(odd.cpi, 13.0)
  assert_true(warnings.length() >= 2, msg="pitch and unknown key warnings")
}

///|
test "textform front matter errors" {
  assert_true(
    front_error(["not a key"]).contains("not a key"),
    msg="a line without a colon",
  )
  assert_true(
    front_error(["margin: {left: 2"]).contains("not closed"),
    msg="an unclosed mapping",
  )
  assert_true(
    front_error(["  left: 2"]).contains("indented under no key"),
    msg="an indented key alone",
  )
  assert_true(
    front_error(["columns: 10", "margin: {left: 10}"]).contains("left margin"),
    msg="the left margin",
  )
  assert_true(
    front_error(["lines: 6", "margin: {top: 4}", "skip: 2"]).contains("top margin"),
    msg="the top margin and skip",
  )
  assert_true(
    front_error(["lines: 10", "title: 10"]).contains("title"),
    msg="the title lines",
  )
  assert_true(
    front_error(["ambiguous: huge"]).contains("ambiguous"),
    msg="an ambiguous width",
  )
}
