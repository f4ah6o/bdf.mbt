///|
test "clipboard serializes merged cells and escapes content" {
  let cells : Array[@render.CellText] = [
    { row: 0, col: 0, rows: 1, cols: 1, text: "head", scope: Some("col"), },
    { row: 0, col: 1, rows: 1, cols: 2, text: "\"wide\"\n&<>", scope: None, },
    { row: 1, col: 0, rows: 2, cols: 1, text: "a\tb", scope: None, },
    { row: 1, col: 1, rows: 1, cols: 1, text: "42", scope: None, },
  ]
  let all = @render.cell_clipboard(cells, {
    row0: 0,
    col0: 0,
    row1: 2,
    col1: 2,
  })
  assert_eq(all.text, "head\t\"\"\"wide\"\"\n&<>\"\t\n\"a\tb\"\t42\t\n\t\t")
  assert_eq(
    all.html,
    "<meta charset=\"utf-8\"><table><tr><th scope=\"col\">head</th><td colspan=\"2\">&quot;wide&quot;<br style=\"mso-data-placement:same-cell\">&amp;&lt;&gt;</td></tr><tr><td rowspan=\"2\">a\tb</td><td>42</td><td></td></tr><tr><td></td><td></td></tr></table>",
  )
  let clipped = @render.cell_clipboard(cells, {
    row0: 0,
    col0: 2,
    row1: 2,
    col1: 2,
  })
  assert_eq(clipped.text, "\"\"\"wide\"\"\n&<>\"\n\n")
  assert_eq(
    clipped.html,
    "<meta charset=\"utf-8\"><table><tr><td>&quot;wide&quot;<br style=\"mso-data-placement:same-cell\">&amp;&lt;&gt;</td></tr><tr><td></td></tr><tr><td></td></tr></table>",
  )
  let trimmed = @render.cell_clipboard(
    cells,
    { row0: 0, col0: 0, row1: 4, col1: 4, },
    trim=true,
  )
  assert_eq(trimmed.text, "head\t\"\"\"wide\"\"\n&<>\"\n\"a\tb\"\t42")
  assert_eq(
    trimmed.html,
    "<meta charset=\"utf-8\"><table><tr><th scope=\"col\">head</th><td>&quot;wide&quot;<br style=\"mso-data-placement:same-cell\">&amp;&lt;&gt;</td></tr><tr><td>a\tb</td><td>42</td></tr></table>",
  )
  let hidden = @render.cell_clipboard(
    cells,
    { row0: 0, col0: 0, row1: 2, col1: 2, },
    skip_row=r => r == 1,
    skip_col=c => c == 1,
  )
  assert_eq(hidden.text, "head\t\"\"\"wide\"\"\n&<>\"\n\"a\tb\"\t")
  assert_eq(
    hidden.html,
    "<meta charset=\"utf-8\"><table><tr><th scope=\"col\">head</th><td>&quot;wide&quot;<br style=\"mso-data-placement:same-cell\">&amp;&lt;&gt;</td></tr><tr><td>a\tb</td><td></td></tr></table>",
  )
}

///|
test "clipboard escapes untrusted cell scope attributes" {
  let cells : Array[@render.CellText] = [
    {
      row: 0,
      col: 0,
      rows: 1,
      cols: 1,
      text: "x",
      scope: Some("col\"\nmalicious"),
    },
  ]
  let value = @render.cell_clipboard(cells, {
    row0: 0,
    col0: 0,
    row1: 0,
    col1: 0,
  })
  assert_eq(
    value.html,
    "<meta charset=\"utf-8\"><table><tr><th scope=\"col&quot;&#10;malicious\">x</th></tr></table>",
  )
}

///|
test "clipboard rejects huge or overlapping ranges" {
  let huge = try {
    ignore(
      @render.cell_clipboard([], {
        row0: 0,
        col0: 0,
        row1: 1000000,
        col1: 1000000,
      }),
    )
    false
  } catch {
    _ => true
  }
  assert_true(huge)
  let cells : Array[@render.CellText] = [
    { row: 0, col: 0, rows: 3000, cols: 1000, text: "a", scope: None, },
    { row: 0, col: 0, rows: 3000, cols: 1000, text: "b", scope: None, },
  ]
  let overlap = try {
    ignore(
      @render.cell_clipboard(cells, { row0: 0, col0: 0, row1: 2999, col1: 999, }),
    )
    false
  } catch {
    _ => true
  }
  assert_true(overlap)
}
