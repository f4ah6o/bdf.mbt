///|
fn check_docx_sections(
  name : String,
  chunks : Array[String],
  part : String,
  expected : Array[
    (Double, Double, Double, Double, Double, Double, Double, Double, Bool, Bool),
  ],
  border_data : Array[(Bool, Bool, Bool, Array[(String, Double, Double)?])],
  layout : Array[
    (
      String,
      Bool,
      Int64,
      String,
      String,
      Double,
      Double,
      Bool,
      Bool,
      Array[(Double, Double)],
      Array[(String, String)],
      Array[(String, String)],
    ),
  ],
) -> Unit raise {
  let joined = StringBuilder()
  for chunk in chunks {
    joined.write_string(chunk)
  }
  let compressed = @base64.decode(joined.to_string()[:])
  let input = @gzip.decompress(compressed[:])
  let (actual_part, sections) = docx_sections(input)
  assert_eq(actual_part, part, msg=name)
  assert_eq(sections.length(), expected.length(), msg=name)
  if name == "synthetic.docx" {
    match sections[0].borders[0] {
      Some(border) => assert_eq(border.color, "FF0000")
      None => fail("synthetic top border missing")
    }
  }
  for i in 0..<expected.length() {
    let (
      width,
      height,
      top,
      bottom,
      left,
      right,
      header,
      footer,
      top_exact,
      bottom_exact,
    ) = expected[i]
    let item = sections[i]
    let (from_text, first, not_first, borders) = border_data[i]
    assert_eq(
      (item.border_from_text, item.border_first, item.border_not_first),
      (from_text, first, not_first),
      msg="\{name} border flags \{i}",
    )
    for j in 0..<borders.length() {
      let actual = match item.borders[j] {
        Some(border) => Some((border.style, border.width, border.space))
        None => None
      }
      assert_eq(actual, borders[j], msg="\{name} border \{i} side \{j}")
    }

    let (
      typ,
      title,
      start,
      format,
      grid,
      pitch,
      spacing,
      vertical,
      sep,
      columns,
      headers,
      footers,
    ) = layout[i]
    assert_eq(
      (
        item.section_type,
        item.title_page,
        item.page_start,
        item.page_format,
        item.grid_type,
        item.line_pitch,
        item.char_space,
        item.vertical,
        item.column_sep,
        item.columns,
      ),
      (typ, title, start, format, grid, pitch, spacing, vertical, sep, columns),
      msg="\{name} layout \{i}",
    )
    check_docx_refs(item.headers, headers)
    check_docx_refs(item.footers, footers)
    assert_eq(
      (
        item.width,
        item.height,
        item.top,
        item.bottom,
        item.left,
        item.right,
        item.header,
        item.footer,
        item.top_exact,
        item.bottom_exact,
      ),
      expected[i],
      msg="\{name} section \{i}",
    )
  }
}

///|
test "DOCX section units" {
  assert_eq(docx_measure("1440", 0.0), 72.0)
  assert_eq(docx_measure("1in", 0.0), 72.0)
  assert_eq(docx_measure("2.54cm", 0.0), 72.0)
  assert_eq(docx_measure("invalid", 5.0), 5.0)
}

///|
fn check_docx_refs(
  actual : Array[(String, String)],
  expected : Array[(String, String)],
) -> Unit raise {
  assert_eq(actual.length(), expected.length())
  for (key, target) in expected {
    let mut found = false
    for (actual_key, actual_target) in actual {
      if key == actual_key && target == actual_target {
        found = true
      }
    }
    assert_true(found)
  }
}
