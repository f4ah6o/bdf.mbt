///|
fn conditional_test_color(kind : Int32, rgb : UInt32) -> XlsxColor {
  { kind, rgb, index: 0, tint: 0.0, }
}

///|
fn conditional_test_fill(rgb : UInt32) -> XlsxFill {
  {
    pattern: "solid",
    foreground: conditional_test_color(1, rgb),
    background: xlsx_default_color(),
    gradient: None,
  }
}

///|
fn conditional_test_border(style : String) -> XlsxBorder {
  {
    left: { style, color: conditional_test_color(1, 0xFF0000U), },
    right: xlsx_empty_side(),
    top: xlsx_empty_side(),
    bottom: xlsx_empty_side(),
    diagonal: xlsx_empty_side(),
    diagonal_up: false,
    diagonal_down: false,
    vertical: xlsx_empty_side(),
    horizontal: xlsx_empty_side(),
  }
}

///|
test "conditional differential properties merge first-rule-wins" {
  let first : XlsxConditionalStyle = {
    bold: Some(true),
    italic: None,
    strike: None,
    underline: None,
    color: Some(conditional_test_color(1, 0x1122CCU)),
    fill: Some(conditional_test_fill(0x1122CCU)),
    border: None,
  }
  let second : XlsxConditionalStyle = {
    bold: Some(false),
    italic: Some(true),
    strike: None,
    underline: None,
    color: Some(conditional_test_color(1, 0x33CC66U)),
    fill: Some(conditional_test_fill(0x33CC66U)),
    border: Some(conditional_test_border("thin")),
  }
  let merged = xlsx_merge_conditional_style(first, second)
  assert_eq(merged.bold, Some(true))
  assert_eq(merged.italic, Some(true))
  match merged.color {
    Some(color) =>
      assert_eq(xlsx_conditional_color_equal(color, conditional_test_color(1, 0x1122CCU)), true)
    None => fail("color must keep the first rule's value")
  }
  match merged.fill {
    Some(fill) =>
      assert_eq(xlsx_conditional_color_equal(fill.foreground, conditional_test_color(1, 0x1122CCU)), true)
    None => fail("fill must keep the first rule's color")
  }
  assert_eq(merged.border is Some(_), true)
}

///|
test "conditional blank style ignores text properties" {
  let style : XlsxConditionalStyle = {
    bold: Some(true),
    italic: None,
    strike: None,
    underline: None,
    color: Some(conditional_test_color(1, 0x1122CCU)),
    fill: Some(conditional_test_fill(0x33CC66U)),
    border: Some(conditional_test_border("thin")),
  }
  let blank = xlsx_conditional_blank_style(style)
  assert_eq(blank.bold is None, true)
  assert_eq(blank.color is None, true)
  assert_eq(blank.fill is Some(_), true)
  assert_eq(blank.border is Some(_), true)
}

///|
test "conditional style grouping merges equal styles" {
  let fill = conditional_test_fill(0x33CC66U)
  let style : XlsxConditionalStyle = {
    bold: None,
    italic: None,
    strike: None,
    underline: None,
    color: None,
    fill: Some(fill),
    border: None,
  }
  let other : XlsxConditionalStyle = { ..style, fill: Some(conditional_test_fill(0xCC5500U)), }
  assert_eq(xlsx_conditional_style_equal(style, style), true)
  assert_eq(xlsx_conditional_style_equal(style, other), false)
  let source : Map[Int32, Map[Int32, XlsxConditionalStyle]] = Map([])
  let row0 : Map[Int32, XlsxConditionalStyle] = Map([])
  row0[0] = style
  row0[1] = style
  source[0] = row0
  let row1 : Map[Int32, XlsxConditionalStyle] = Map([])
  row1[2] = other
  source[1] = row1
  let group_styles : Array[XlsxConditionalStyle] = []
  let group_matches : Array[Map[Int32, Map[Int32, Bool]]] = []
  xlsx_conditional_group_styles(source, group_styles, group_matches)
  assert_eq(group_styles.length(), 2)
  assert_eq(group_matches[0].get(0).unwrap()[1], true)
  assert_eq(group_matches[1].get(1).unwrap()[2], true)
}

///|
test "conditional blank cells follow the sparse row shortcut" {
  let rows : Array[XlsxRow] = [
    { index: 0, height: -1.0, custom_height: false, hidden: false, style: -1, cells: [] },
    { index: 1001, height: -1.0, custom_height: false, hidden: false, style: -1, cells: [] },
  ]
  let tall : Array[XlsxRange] = [
    { row_start: 0L, column_start: 0, row_end: 1001L, column_end: 0 },
  ]
  let target : Map[Int32, Map[Int32, XlsxConditionalStyle]] = Map([])
  let style : XlsxConditionalStyle = {
    bold: None,
    italic: None,
    strike: None,
    underline: None,
    color: None,
    fill: Some(conditional_test_fill(0x1122CCU)),
    border: None,
  }
  xlsx_conditional_merge_blank_cells(
    rows, tall, 1002, 1, Map([]), [], style, target,
  )
  assert_eq(target.contains(0), true)
  assert_eq(target.contains(1), true)
  assert_eq(target.contains(2), false)
  assert_eq(target.contains(1001), true)
}
