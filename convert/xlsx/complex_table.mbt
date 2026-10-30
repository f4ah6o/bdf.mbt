///|
priv struct XlsxComplexStyle {
  ids : Array[Int32]
  sizes : Array[Int64]
}

///|
priv struct XlsxComplexTable {
  style : XlsxComplexStyle
  range : XlsxRange
  header : Int32
  totals : Int32
  first_column : Bool
  last_column : Bool
  row_stripes : Bool
  column_stripes : Bool
}

///|
fn xlsx_complex_table_names() -> Array[String] {
  [
    "wholeTable", "firstColumnStripe", "secondColumnStripe", "firstRowStripe", "secondRowStripe",
    "lastColumn", "firstColumn", "headerRow", "totalRow", "firstHeaderCell", "lastHeaderCell",
    "firstTotalCell", "lastTotalCell",
  ]
}

///|
fn XlsxWorkbook::xlsx_complex_table_style(
  self : XlsxWorkbook,
  wanted : String,
) -> XlsxComplexStyle? raise {
  let rel = match self.package.relationship_of_type(self.part, "/styles") {
    Some(value) => value
    None => return None
  }
  let data = self.package.read(rel.target) catch { _ => return None }
  let text = @utf8.decode_lossy(data[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    return None
  }
  let reader = @xml.NamespaceReader::from_string(text)
  let mut depth = 0
  let mut dxf_depth = -1
  let mut dxf_count = 0
  let mut dxf_seen = false
  let mut styles_depth = -1
  let mut style_depth = -1
  let mut styles_seen = false
  let mut found = false
  let mut invalid = false
  let mut items : Array[(String, Int32, Int64)] = []
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        if depth == 1 && name == "dxfs" && !dxf_seen {
          dxf_seen = true
          if event.kind is Start(_) {
            dxf_depth = depth + 1
          }
        } else if depth == dxf_depth && name == "dxf" {
          dxf_count += 1
        }
        if depth == 1 && name == "tableStyles" && !styles_seen {
          styles_seen = true
          if event.kind is Start(_) {
            styles_depth = depth + 1
          }
        } else if depth == styles_depth && name == "tableStyle" {
          if xlsx_decode_string(xlsx_attr(element, "name", "")) == wanted {
            found = true
            invalid = false
            items = []
            if event.kind is Start(_) {
              style_depth = depth + 1
            }
          }
        } else if depth == style_depth && name == "tableStyleElement" {
          let kind = xlsx_attr(element, "type", "")
          if xlsx_table_style_region_used(kind) {
            let mut width = 1L
            if kind == "firstRowStripe" ||
              kind == "secondRowStripe" ||
              kind == "firstColumnStripe" ||
              kind == "secondColumnStripe" {
              let size = xlsx_trim(xlsx_attr(element, "size", ""))
              if size != "" {
                match xlsx_int(size) {
                  Some(n) if n >= -2147483648L && n <= 2147483647L =>
                    width = Int64::max(1L, n)
                  _ => invalid = true
                }
              }
            }
            match xlsx_int(xlsx_trim(xlsx_attr(element, "dxfId", ""))) {
              Some(n) if n >= -2147483648L && n <= 2147483647L =>
                items.push((kind, n.to_int(), width))
              _ => invalid = true
            }
          }
        }
        if event.kind is Start(_) {
          depth += 1
        } else if depth == 0 {
          break
        }
      }
      End(_) => {
        depth -= 1
        if depth + 1 == dxf_depth {
          dxf_depth = -1
        }
        if depth + 1 == style_depth {
          style_depth = -1
        }
        if depth + 1 == styles_depth {
          styles_depth = -1
        }
        if depth == 0 {
          break
        }
      }
      Eof => if depth == 0 { break } else { return None }
      _ => ()
    }
  }
  if !found || invalid {
    return None
  }
  let names = xlsx_complex_table_names()
  let ids : Array[Int32] = [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
  let sizes : Array[Int64] = [
    1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L,
  ]
  for (kind, id, width) in items {
    if id < 0 || id >= dxf_count {
      continue
    }
    for i in 0..<names.length() {
      if kind == names[i] {
        ids[i] = id
        sizes[i] = width
        break
      }
    }
  }
  let mut any = false
  for id in ids {
    if id < 0 {
      continue
    }
    let _style = self.xlsx_table_differential_style(id) catch {
      _ => return None
    }
    any = true
  }
  if !any {
    return None
  }
  Some({ ids, sizes, })
}

///|
fn xlsx_complex_table_mask(
  table : XlsxComplexTable,
  row : Int32,
  col : Int32,
) -> Int32 {
  let range = table.range
  let r = row.to_int64()
  let c = col.to_int64()
  let data_start = range.row_start + table.header.to_int64()
  let data_end = range.row_end - table.totals.to_int64()
  let data_row = r >= data_start && r <= data_end
  let column_offset = (c - range.column_start.to_int64()) %
    (table.style.sizes[1] + table.style.sizes[2])
  let row_offset = if data_row {
    (r - data_start) % (table.style.sizes[3] + table.style.sizes[4])
  } else {
    0L
  }
  let selected : Array[Bool] = [
    true,
    table.column_stripes && data_row && column_offset < table.style.sizes[1],
    table.column_stripes && data_row && column_offset >= table.style.sizes[1],
    table.row_stripes && data_row && row_offset < table.style.sizes[3],
    table.row_stripes && data_row && row_offset >= table.style.sizes[3],
    table.last_column && col == range.column_end,
    table.first_column && col == range.column_start,
    table.header > 0 && r < range.row_start + table.header.to_int64(),
    table.totals > 0 && r > range.row_end - table.totals.to_int64(),
    table.header > 0 &&
    table.first_column &&
    r == range.row_start &&
    col == range.column_start,
    table.header > 0 &&
    table.last_column &&
    r == range.row_start &&
    col == range.column_end,
    table.totals > 0 &&
    table.first_column &&
    r == range.row_end &&
    col == range.column_start,
    table.totals > 0 &&
    table.last_column &&
    r == range.row_end &&
    col == range.column_end,
  ]
  let mut mask = 0
  for i in 0..<selected.length() {
    if selected[i] && table.style.ids[i] >= 0 {
      mask = mask | (1 << i)
    }
  }
  mask
}

///|
fn XlsxWorkbook::xlsx_complex_table_effective_style(
  self : XlsxWorkbook,
  table : XlsxComplexTable,
  mask : Int32,
) -> XlsxConditionalStyle raise {
  let mut result : XlsxConditionalStyle? = None
  for i in 0..<table.style.ids.length() {
    if (mask & (1 << i)) != 0 {
      let diff = self.xlsx_table_differential_style(table.style.ids[i])
      result = Some(
        match result {
          Some(base) => xlsx_merge_table_style(base, diff)
          None => diff
        },
      )
    }
  }
  match result {
    Some(value) => value
    None => self.xlsx_table_differential_style(-1)
  }
}

///|
// Bounds of the selected table region, including individual stripe runs.
fn xlsx_complex_table_region(
  table : XlsxComplexTable,
  index : Int32,
  row : Int32,
  col : Int32,
) -> (Int64, Int64, Int64, Int64) {
  let range = table.range
  let r0 = range.row_start
  let r1 = range.row_end
  let c0 = range.column_start.to_int64()
  let c1 = range.column_end.to_int64()
  let data0 = r0 + table.header.to_int64()
  let data1 = r1 - table.totals.to_int64()
  if index == 1 || index == 2 {
    let first = table.style.sizes[1]
    let second = table.style.sizes[2]
    let off = (col.to_int64() - c0) % (first + second)
    let start = col.to_int64() - off + (if index == 2 { first } else { 0L })
    let size = if index == 2 { second } else { first }
    (data0, start, data1, start + size - 1L)
  } else if index == 3 || index == 4 {
    let first = table.style.sizes[3]
    let second = table.style.sizes[4]
    let off = (row.to_int64() - data0) % (first + second)
    let start = row.to_int64() - off + (if index == 4 { first } else { 0L })
    let size = if index == 4 { second } else { first }
    (start, c0, Int64::min(start + size - 1L, data1), c1)
  } else if index == 5 {
    (r0, c1, r1, c1)
  } else if index == 6 {
    (r0, c0, r1, c0)
  } else if index == 7 {
    (r0, c0, r0 + table.header.to_int64() - 1L, c1)
  } else if index == 8 {
    (r1 - table.totals.to_int64() + 1L, c0, r1, c1)
  } else if index == 9 {
    (r0, c0, r0, c0)
  } else if index == 10 {
    (r0, c1, r0, c1)
  } else if index == 11 {
    (r1, c0, r1, c0)
  } else if index == 12 {
    (r1, c1, r1, c1)
  } else {
    (r0, c0, r1, c1)
  }
}

///|
// Resolve each side independently, in the same region precedence as upstream.
fn xlsx_complex_table_border(
  table : XlsxComplexTable,
  borders : Array[XlsxBorder?],
  row : Int32,
  col : Int32,
) -> (XlsxBorder, String) {
  let mask = xlsx_complex_table_mask(table, row, col)
  let mut top = xlsx_empty_side()
  let mut bottom = xlsx_empty_side()
  let mut left = xlsx_empty_side()
  let mut right = xlsx_empty_side()
  let mut top_id = 0
  let mut bottom_id = 0
  let mut left_id = 0
  let mut right_id = 0
  for i in 0..<borders.length() {
    if (mask & (1 << i)) == 0 {
      continue
    }
    if borders[i] is Some(border) {
      let (r0, c0, r1, c1) = xlsx_complex_table_region(table, i, row, col)
      let top_outer = row.to_int64() == r0
      let bottom_outer = row.to_int64() == r1
      let left_outer = col.to_int64() == c0
      let right_outer = col.to_int64() == c1
      let t = if top_outer { border.top } else { border.horizontal }
      let b = if bottom_outer { border.bottom } else { border.horizontal }
      let l = if left_outer { border.left } else { border.vertical }
      let r = if right_outer { border.right } else { border.vertical }
      if t.style != "" {
        top = t
        top_id = i * 2 + (if top_outer { 1 } else { 2 })
      }
      if b.style != "" {
        bottom = b
        bottom_id = i * 2 + (if bottom_outer { 1 } else { 2 })
      }
      if l.style != "" {
        left = l
        left_id = i * 2 + (if left_outer { 1 } else { 2 })
      }
      if r.style != "" {
        right = r
        right_id = i * 2 + (if right_outer { 1 } else { 2 })
      }
    }
  }
  let result : XlsxBorder = {
    top,
    bottom,
    left,
    right,
    diagonal: xlsx_empty_side(),
    diagonal_up: false,
    diagonal_down: false,
    vertical: xlsx_empty_side(),
    horizontal: xlsx_empty_side(),
  }
  (result, "\{top_id},\{bottom_id},\{left_id},\{right_id}")
}
