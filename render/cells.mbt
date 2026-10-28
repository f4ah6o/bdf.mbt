///|
/// Text and span of a table cell. Rows and columns are zero-based.
pub(all) struct CellText {
  row : Int32
  col : Int32
  rows : Int32
  cols : Int32
  text : String
  scope : String?
} derive(Eq, Debug)

///|
/// Inclusive bounds of a rectangular cell selection.
pub(all) struct CellRange {
  row0 : Int32
  col0 : Int32
  row1 : Int32
  col1 : Int32
} derive(Eq, Debug)

///|
/// Spreadsheet clipboard representations of a cell selection.
pub(all) struct CellClipboard {
  text : String
  html : String
} derive(Eq, Debug)

///|
fn is_table_cell(nodes : Array[TextNode], i : Int32, table : Int32) -> Bool {
  let n = nodes[i]
  if n.kind != "cell" || n.row is None || n.col is None {
    return false
  }
  if table >= 0 {
    return n.parent == table
  }
  let mut p = n.parent
  let mut steps = 0
  while p >= 0 && p < nodes.length() && steps < nodes.length() {
    if nodes[p].kind == "table" {
      return false
    }
    p = nodes[p].parent
    steps += 1
  }
  p < 0
}

///|
/// Collect cells belonging to a table node, or cells outside tables for -1.
/// Runs of duplicate cells are combined and the result is ordered by position.
pub fn table_cells(
  content : TextContent,
  table~ : Int32 = -1,
) -> Array[CellText] {
  let nodes = content.nodes
  let owners : Map[Int32, Int32] = {}
  let texts : Map[Int32, StringBuilder] = {}
  for run in content.runs {
    if run.text == "" {
      continue
    }
    let mut index = run.node
    let mut steps = 0
    while index >= 0 && index < nodes.length() && steps < nodes.length() {
      if owners.get(index) is Some(cached) {
        index = cached
        break
      }
      if is_table_cell(nodes, index, table) {
        break
      }
      index = nodes[index].parent
      steps += 1
    }
    if index < 0 ||
      index >= nodes.length() ||
      steps >= nodes.length() ||
      !is_table_cell(nodes, index, table) {
      owners[run.node] = -1
      continue
    }
    owners[run.node] = index
    match texts.get(index) {
      None => {
        let builder = StringBuilder()
        builder.write_string(run.text)
        texts[index] = builder
      }
      Some(builder) => {
        if run.separator == 2 {
          builder.write_string("\n")
        } else if run.separator == 1 {
          builder.write_string(" ")
        }
        builder.write_string(run.text)
      }
    }
  }
  let result : Array[CellText] = []
  let positions : Map[(Int32, Int32), Int32] = {}
  for i, n in nodes {
    if !is_table_cell(nodes, i, table) {
      continue
    }
    let row = n.row.unwrap_or(0)
    let col = n.col.unwrap_or(0)
    let text = match texts.get(i) {
      Some(builder) => builder.to_string()
      None => ""
    }
    match positions.get((row, col)) {
      Some(existing) =>
        if text != "" {
          let old = result[existing]
          result[existing] = {
            ..old,
            text: if old.text == "" {
              text
            } else {
              old.text + " " + text
            },
          }
        }
      None => {
        positions[(row, col)] = result.length()
        result.push({
          row,
          col,
          rows: n.rows.unwrap_or(1),
          cols: n.cols.unwrap_or(1),
          text,
          scope: n.scope,
        })
      }
    }
  }
  result.sort_by((a, b) => {
    if a.row < b.row {
      -1
    } else if a.row > b.row {
      1
    } else if a.col < b.col {
      -1
    } else if a.col > b.col {
      1
    } else {
      0
    }
  })
  result
}

///|
priv struct ClippedCell {
  cell : CellText
  row0 : Int32
  col0 : Int32
  row1 : Int32
  col1 : Int32
}

///|
priv struct PlacedCell {
  cell : CellText
  rows : Int32
  cols : Int32
}

///|
priv struct CellPlan {
  row : Int32
  col : Int32
  rows : Int32
  cols : Int32
  cell : CellText
}

///|
fn lower_bound(list : Array[Int32], value : Int64) -> Int32 {
  let mut lo = 0
  let mut hi = list.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    if list[mid].to_int64() < value {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  lo
}

///|
fn append_tsv_field(out : StringBuilder, text : String) -> Unit {
  let mut quoted = false
  for c in text {
    if c == '\t' || c == '\n' || c == '\r' || c == '"' {
      quoted = true
      break
    }
  }
  if quoted {
    out.write_char('"')
  }
  for c in text {
    if c == '"' {
      out.write_string("\"\"")
    } else {
      out.write_char(c)
    }
  }
  if quoted {
    out.write_char('"')
  }
}

///|
fn append_html_text(out : StringBuilder, text : String) -> Unit {
  for c in text {
    match c {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '"' => out.write_string("&quot;")
      '\n' => out.write_string("<br style=\"mso-data-placement:same-cell\">")
      _ => out.write_char(c)
    }
  }
}

///|
fn append_html_attribute(out : StringBuilder, text : String) -> Unit {
  for c in text {
    match c {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '"' => out.write_string("&quot;")
      '\n' => out.write_string("&#10;")
      '\r' => out.write_string("&#13;")
      '\t' => out.write_string("&#9;")
      _ => out.write_char(c)
    }
  }
}

///|
/// Serialize selected cells as TSV and an HTML table, preserving merged cells.
/// Oversized or overlapping ranges are rejected before large allocations.
pub fn cell_clipboard(
  cells : Array[CellText],
  range : CellRange,
  trim~ : Bool = false,
  skip_row? : (Int32) -> Bool,
  skip_col? : (Int32) -> Bool,
) -> CellClipboard raise {
  let inside : Array[ClippedCell] = []
  let mut last_row = range.row0.to_int64() - 1L
  let mut last_col = range.col0.to_int64() - 1L
  for cell in cells {
    let r0 = cell.row.max(range.row0)
    let c0 = cell.col.max(range.col0)
    let r1 = (cell.row.to_int64() + cell.rows.to_int64() - 1L).min(
      range.row1.to_int64(),
    )
    let c1 = (cell.col.to_int64() + cell.cols.to_int64() - 1L).min(
      range.col1.to_int64(),
    )
    if r0.to_int64() > r1 || c0.to_int64() > c1 {
      continue
    }
    inside.push({
      cell,
      row0: r0,
      col0: c0,
      row1: r1.to_int(),
      col1: c1.to_int(),
    })
    if cell.text != "" {
      last_row = last_row.max(r0.to_int64())
      last_col = last_col.max(c0.to_int64())
    }
  }
  let row1 = if trim {
    range.row1.to_int64().min(last_row)
  } else {
    range.row1.to_int64()
  }
  let col1 = if trim {
    range.col1.to_int64().min(last_col)
  } else {
    range.col1.to_int64()
  }
  let nr = (row1 - range.row0.to_int64() + 1L).max(0L)
  let nc = (col1 - range.col0.to_int64() + 1L).max(0L)
  let limit = 4194304L.max(inside.length().to_int64() * 64L)
  if nr > limit || nc > limit || (nr > 0L && nc > limit / nr) {
    raise InvalidOperands("too many cells to copy")
  }
  let rows : Array[Int32] = []
  let cols : Array[Int32] = []
  let mut r = range.row0.to_int64()
  while r <= row1 {
    let value = r.to_int()
    let skip = match skip_row {
      Some(f) => f(value)
      None => false
    }
    if !skip {
      rows.push(value)
    }
    r += 1L
  }
  let mut c = range.col0.to_int64()
  while c <= col1 {
    let value = c.to_int()
    let skip = match skip_col {
      Some(f) => f(value)
      None => false
    }
    if !skip {
      cols.push(value)
    }
    c += 1L
  }
  let planned : Array[CellPlan] = []
  let mut spanned = 0L
  let n = cols.length()
  for clip in inside {
    let ri = lower_bound(rows, clip.row0.to_int64())
    let ci = lower_bound(cols, clip.col0.to_int64())
    let rn = lower_bound(rows, clip.row1.to_int64() + 1L) - ri
    let cn = lower_bound(cols, clip.col1.to_int64() + 1L) - ci
    if rn <= 0 || cn <= 0 {
      continue
    }
    spanned += rn.to_int64() * cn.to_int64()
    if spanned > limit {
      raise InvalidOperands("too many cells to copy")
    }
    planned.push({ row: ri, col: ci, rows: rn, cols: cn, cell: clip.cell, })
  }
  let placed : Map[Int32, PlacedCell] = {}
  let covered : Map[Int32, Bool] = {}
  for item in planned {
    placed[item.row * n + item.col] = {
      cell: item.cell,
      rows: item.rows,
      cols: item.cols,
    }
    for i in 0..<item.rows {
      for j in 0..<item.cols {
        if i != 0 || j != 0 {
          covered[(item.row + i) * n + item.col + j] = true
        }
      }
    }
  }
  let plain = StringBuilder()
  let html = StringBuilder()
  html.write_string("<meta charset=\"utf-8\"><table>")
  for i in 0..<rows.length() {
    if i > 0 {
      plain.write_char('\n')
    }
    html.write_string("<tr>")
    for j in 0..<n {
      if j > 0 {
        plain.write_char('\t')
      }
      let at = i * n + j
      let found = placed.get(at)
      if found is Some(value) {
        append_tsv_field(plain, value.cell.text)
      }
      if covered.contains(at) {
        continue
      }
      match found {
        None => html.write_string("<td></td>")
        Some(value) => {
          let tag = if value.cell.scope is Some(_) { "th" } else { "td" }
          html.write_string("<" + tag)
          if value.cell.scope is Some(scope) {
            html.write_string(" scope=\"")
            append_html_attribute(html, scope)
            html.write_char('"')
          }
          if value.rows > 1 {
            html.write_string(" rowspan=\"" + value.rows.to_string() + "\"")
          }
          if value.cols > 1 {
            html.write_string(" colspan=\"" + value.cols.to_string() + "\"")
          }
          html.write_char('>')
          append_html_text(html, value.cell.text)
          html.write_string("</" + tag + ">")
        }
      }
    }
    html.write_string("</tr>")
  }
  html.write_string("</table>")
  { text: plain.to_string(), html: html.to_string(), }
}
