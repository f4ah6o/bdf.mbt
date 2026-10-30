///|
/// Result of converting the explicitly limited plain-sheet subset of XLSX.
pub(all) struct XlsxPlainResult {
  bdf : Bytes
  warnings : Array[String]
  sheets : Int32
}

///|
fn xlsx_table_style_region_used(name : String) -> Bool {
  match name {
    "wholeTable"
    | "firstColumnStripe"
    | "secondColumnStripe"
    | "firstRowStripe"
    | "secondRowStripe"
    | "lastColumn"
    | "firstColumn"
    | "headerRow"
    | "totalRow"
    | "firstHeaderCell"
    | "lastHeaderCell"
    | "firstTotalCell"
    | "lastTotalCell" => true
    _ => false
  }
}

///|
// Table differential formats without font, fill, or border do not affect drawing.
fn XlsxWorkbook::xlsx_nonformatting_table_style(
  self : XlsxWorkbook,
  wanted : String,
) -> Bool raise {
  let rel = match self.package.relationship_of_type(self.part, "/styles") {
    Some(value) => value
    None => return false
  }
  let data = self.package.read(rel.target) catch { _ => return false }
  let text = @utf8.decode_lossy(data[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    return false
  }
  let reader = @xml.NamespaceReader::from_string(text)
  let mut depth = 0
  let mut styles_depth = -1
  let mut style_depth = -1
  let mut styles_seen = false
  let mut dxf_depth = -1
  let mut dxf_seen = false
  let mut dxf_inner_depth = -1
  let dxf_effects : Array[Bool] = []
  let mut found = false
  let mut ambiguous = false
  let mut used_ids : Array[Int64] = []
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
          dxf_effects.push(false)
          if event.kind is Start(_) {
            dxf_inner_depth = depth + 1
          }
        } else if depth == dxf_inner_depth &&
          (name == "font" || name == "fill" || name == "border") {
          dxf_effects[dxf_effects.length() - 1] = true
        }
        if depth == 1 && name == "tableStyles" && !styles_seen {
          styles_seen = true
          if event.kind is Start(_) {
            styles_depth = depth + 1
          }
        } else if depth == styles_depth && name == "tableStyle" {
          let actual = xlsx_decode_string(xlsx_attr(element, "name", ""))
          if actual == wanted {
            found = true
            ambiguous = false
            used_ids = []
            if event.kind is Start(_) {
              style_depth = depth + 1
            }
          }
        } else if depth == style_depth && name == "tableStyleElement" {
          if xlsx_table_style_region_used(xlsx_attr(element, "type", "")) {
            let raw = xlsx_trim(xlsx_attr(element, "dxfId", ""))
            let lower = raw.to_lower()
            if lower.has_prefix("0x") ||
              lower.has_prefix("+0x") ||
              lower.has_prefix("-0x") {
              ambiguous = true
            } else {
              let id = match xlsx_int(raw) {
                Some(value) => value
                None => {
                  let value = @string.parse_double(raw) catch { _ => -1.0 }
                  if value.is_nan() {
                    0L
                  } else if value >= 2147483647.0 {
                    2147483647L
                  } else if value <= -1.0 {
                    -1L
                  } else {
                    value.to_int64()
                  }
                }
              }
              used_ids.push(id)
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
        if depth + 1 == dxf_inner_depth {
          dxf_inner_depth = -1
        }
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
      Eof => if depth == 0 { break } else { return false }
      _ => ()
    }
  }
  if !found || ambiguous {
    return false
  }
  for id in used_ids {
    if id >= 0L &&
      id < dxf_effects.length().to_int64() &&
      dxf_effects[id.to_int()] {
      return false
    }
  }
  true
}

///|
// Resolve supported table-region differentials.
fn XlsxWorkbook::xlsx_table_style(
  self : XlsxWorkbook,
  wanted : String,
) -> (Int32, Int32, Int64, Int32, Int64, Int32) raise {
  let rel = match self.package.relationship_of_type(self.part, "/styles") {
    Some(value) => value
    None => return (-1, 0, 1L, -1, 1L, -1)
  }
  let data = self.package.read(rel.target) catch {
    _ => return (-1, 0, 1L, -1, 1L, -1)
  }
  let text = @utf8.decode_lossy(data[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    return (-1, 0, 1L, -1, 1L, -1)
  }
  let reader = @xml.NamespaceReader::from_string(text)
  let mut depth = 0
  let mut styles_depth = -1
  let mut style_depth = -1
  let mut styles_seen = false
  let mut dxf_depth = -1
  let mut dxf_seen = false
  let mut dxf_count = 0
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
            let raw = xlsx_trim(xlsx_attr(element, "dxfId", ""))
            match xlsx_int(raw) {
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
      Eof => if depth == 0 { break } else { return (-1, 0, 1L, -1, 1L, -1) }
      _ => ()
    }
  }
  if !found || invalid {
    return (-1, 0, 1L, -1, 1L, -1)
  }
  let mut whole = -1
  let mut stripe_axis = 0
  let mut first_stripe = -1
  let mut second_stripe = -1
  let mut first_size = 1L
  let mut second_size = 1L
  let mut has_other = false
  for (kind, id, width) in items {
    if id < 0 || id >= dxf_count {
      continue
    }
    if kind == "wholeTable" {
      whole = id
    } else if kind == "firstRowStripe" ||
      kind == "secondRowStripe" ||
      kind == "firstColumnStripe" ||
      kind == "secondColumnStripe" {
      let axis = if kind == "firstRowStripe" || kind == "secondRowStripe" {
        1
      } else {
        2
      }
      if stripe_axis != 0 && stripe_axis != axis {
        has_other = true
      }
      stripe_axis = axis
      if kind == "firstRowStripe" || kind == "firstColumnStripe" {
        first_stripe = id
        first_size = width
      } else {
        second_stripe = id
        second_size = width
      }
    } else {
      has_other = true
    }
  }
  if whole >= 0 && (first_stripe >= 0 || second_stripe >= 0) && !has_other {
    let base = self.xlsx_conditional_style(whole) catch {
      _ => return (-1, 0, 1L, -1, 1L, -1)
    }
    if base.border is Some(_) {
      return (-1, 0, 1L, -1, 1L, -1)
    }
    if first_stripe >= 0 {
      let first = self.xlsx_conditional_style(first_stripe) catch {
        _ => return (-1, 0, 1L, -1, 1L, -1)
      }
      if first.border is Some(_) {
        return (-1, 0, 1L, -1, 1L, -1)
      }
    }
    if second_stripe >= 0 {
      let second = self.xlsx_conditional_style(second_stripe) catch {
        _ => return (-1, 0, 1L, -1, 1L, -1)
      }
      if second.border is Some(_) {
        return (-1, 0, 1L, -1, 1L, -1)
      }
    }
    if first_stripe >= 0 && second_stripe >= 0 {
      return (
        whole,
        if stripe_axis == 1 {
          23
        } else {
          24
        },
        first_size,
        first_stripe,
        second_size,
        second_stripe,
      )
    }
    if first_stripe >= 0 {
      return (
        whole,
        if stripe_axis == 1 {
          19
        } else {
          21
        },
        first_size,
        first_stripe,
        1L,
        -1,
      )
    }
    return (
      whole,
      if stripe_axis == 1 {
        20
      } else {
        22
      },
      second_size,
      second_stripe,
      1L,
      -1,
    )
  }
  let mut chosen = -1
  let mut selected_kind = ""
  let mut selected_width = 1L
  let mut other = -1
  let mut other_width = 1L
  let mut third = -1
  let mut axis = 0
  let mut first_id = -1
  let mut second_id = -1
  let mut first_width = 1L
  let mut second_width = 1L
  for (kind, id, width) in items {
    if id < 0 || id >= dxf_count {
      continue
    }
    let stripe_axis = if kind == "firstRowStripe" || kind == "secondRowStripe" {
      1
    } else if kind == "firstColumnStripe" || kind == "secondColumnStripe" {
      2
    } else {
      0
    }
    if stripe_axis != 0 {
      if selected_kind != "" || (axis != 0 && axis != stripe_axis) {
        return (-1, 0, 1L, -1, 1L, -1)
      }
      axis = stripe_axis
      if kind == "firstRowStripe" || kind == "firstColumnStripe" {
        first_id = id
        first_width = width
      } else {
        second_id = id
        second_width = width
      }
    } else {
      if axis != 0 ||
        (
          kind != "wholeTable" &&
          kind != "headerRow" &&
          kind != "totalRow" &&
          kind != "firstColumn" &&
          kind != "lastColumn" &&
          kind != "firstHeaderCell" &&
          kind != "lastHeaderCell" &&
          kind != "firstTotalCell" &&
          kind != "lastTotalCell"
        ) {
        return (-1, 0, 1L, -1, 1L, -1)
      }
      if selected_kind == "" || selected_kind == kind {
        selected_kind = kind
        selected_width = width
        chosen = id
      } else if selected_kind == "wholeTable" && kind == "headerRow" {
        other = id
        selected_kind = "wholeHeader"
      } else if selected_kind == "headerRow" && kind == "wholeTable" {
        other = chosen
        chosen = id
        selected_kind = "wholeHeader"
      } else if selected_kind == "wholeHeader" && kind == "wholeTable" {
        chosen = id
      } else if selected_kind == "wholeHeader" && kind == "headerRow" {
        other = id
      } else if selected_kind == "wholeTable" && kind == "totalRow" {
        other = id
        selected_kind = "wholeTotal"
      } else if selected_kind == "totalRow" && kind == "wholeTable" {
        other = chosen
        chosen = id
        selected_kind = "wholeTotal"
      } else if selected_kind == "wholeTotal" && kind == "wholeTable" {
        chosen = id
      } else if selected_kind == "wholeTotal" && kind == "totalRow" {
        other = id
      } else if selected_kind == "headerRow" && kind == "totalRow" {
        other = id
        selected_kind = "headerTotal"
      } else if selected_kind == "totalRow" && kind == "headerRow" {
        other = chosen
        chosen = id
        selected_kind = "headerTotal"
      } else if selected_kind == "headerTotal" && kind == "headerRow" {
        chosen = id
      } else if selected_kind == "headerTotal" && kind == "totalRow" {
        other = id
      } else if selected_kind == "wholeHeader" && kind == "totalRow" {
        third = id
        selected_kind = "wholeHeaderTotal"
      } else if selected_kind == "wholeTotal" && kind == "headerRow" {
        third = other
        other = id
        selected_kind = "wholeHeaderTotal"
      } else if selected_kind == "headerTotal" && kind == "wholeTable" {
        third = other
        other = chosen
        chosen = id
        selected_kind = "wholeHeaderTotal"
      } else if selected_kind == "wholeHeaderTotal" && kind == "wholeTable" {
        chosen = id
      } else if selected_kind == "wholeHeaderTotal" && kind == "headerRow" {
        other = id
      } else if selected_kind == "wholeHeaderTotal" && kind == "totalRow" {
        third = id
      } else {
        return (-1, 0, 1L, -1, 1L, -1)
      }
    }
  }
  if axis != 0 {
    if first_id >= 0 && second_id >= 0 {
      chosen = first_id
      selected_width = first_width
      other = second_id
      other_width = second_width
      selected_kind = if axis == 1 {
        "rowStripePair"
      } else {
        "columnStripePair"
      }
    } else if first_id >= 0 {
      chosen = first_id
      selected_width = first_width
      selected_kind = if axis == 1 {
        "firstRowStripe"
      } else {
        "firstColumnStripe"
      }
    } else if second_id >= 0 {
      chosen = second_id
      selected_width = second_width
      selected_kind = if axis == 1 {
        "secondRowStripe"
      } else {
        "secondColumnStripe"
      }
    }
  }
  if chosen < 0 {
    return (-1, 0, 1L, -1, 1L, -1)
  }
  let diff = self.xlsx_conditional_style(chosen) catch {
    _ => return (-1, 0, 1L, -1, 1L, -1)
  }
  if diff.border is Some(_) {
    return (-1, 0, 1L, -1, 1L, -1)
  }
  if other >= 0 {
    let extra = self.xlsx_conditional_style(other) catch {
      _ => return (-1, 0, 1L, -1, 1L, -1)
    }
    if extra.border is Some(_) {
      return (-1, 0, 1L, -1, 1L, -1)
    }
  }
  if third >= 0 {
    let last = self.xlsx_conditional_style(third) catch {
      _ => return (-1, 0, 1L, -1, 1L, -1)
    }
    if last.border is Some(_) {
      return (-1, 0, 1L, -1, 1L, -1)
    }
  }
  (
    chosen,
    if selected_kind == "headerRow" {
      1
    } else if selected_kind == "totalRow" {
      2
    } else if selected_kind == "firstColumn" {
      3
    } else if selected_kind == "lastColumn" {
      4
    } else if selected_kind == "firstHeaderCell" {
      5
    } else if selected_kind == "lastHeaderCell" {
      6
    } else if selected_kind == "firstTotalCell" {
      7
    } else if selected_kind == "lastTotalCell" {
      8
    } else if selected_kind == "firstRowStripe" {
      9
    } else if selected_kind == "secondRowStripe" {
      10
    } else if selected_kind == "firstColumnStripe" {
      11
    } else if selected_kind == "secondColumnStripe" {
      12
    } else if selected_kind == "rowStripePair" {
      13
    } else if selected_kind == "columnStripePair" {
      14
    } else if selected_kind == "wholeHeader" {
      15
    } else if selected_kind == "wholeTotal" {
      16
    } else if selected_kind == "headerTotal" {
      17
    } else if selected_kind == "wholeHeaderTotal" {
      18
    } else {
      0
    },
    selected_width,
    other,
    other_width,
    third,
  )
}

///|
fn xlsx_table_style_flag(
  element : @xml.NamespaceElement,
  name : String,
) -> Bool {
  match xlsx_trim(xlsx_attr(element, name, "")) {
    "1" | "true" | "on" => true
    _ => false
  }
}

///|
fn xlsx_table_stripe_choice(
  region : Int32,
  origin : Int64,
  range : XlsxRange,
  width : Int64,
  other_width : Int64,
  overlay_end : Int64,
  row : Int32,
  col : Int32,
) -> Int32 {
  if region == 23 || region == 24 {
    if row.to_int64() < origin || row.to_int64() > overlay_end {
      return 0
    }
    let pos = if region == 23 {
      row.to_int64() - origin
    } else {
      (col - range.column_start).to_int64()
    }
    if pos % (width + other_width) < width {
      1
    } else {
      2
    }
  } else if region >= 19 && region <= 22 {
    if row.to_int64() < origin || row.to_int64() > overlay_end {
      return 0
    }
    let pos = if region == 19 || region == 20 {
      row.to_int64() - origin
    } else {
      (col - range.column_start).to_int64()
    }
    let offset = pos % (width + 1L)
    if ((region == 19 || region == 21) && offset < width) ||
      ((region == 20 || region == 22) && offset >= 1L) {
      1
    } else {
      0
    }
  } else if region == 18 {
    let header = row.to_int64() <= width
    let total = row.to_int64() >= other_width
    if header && total {
      3
    } else if header {
      1
    } else if total {
      2
    } else {
      0
    }
  } else if region == 17 {
    let header = row.to_int64() <= width
    let total = row.to_int64() >= other_width
    if header && total {
      2
    } else if header {
      0
    } else if total {
      1
    } else {
      -1
    }
  } else if region == 15 {
    if row.to_int64() <= origin {
      1
    } else {
      0
    }
  } else if region == 16 {
    if row.to_int64() >= origin {
      1
    } else {
      0
    }
  } else if region == 13 || region == 14 {
    let pos = if region == 13 {
      row.to_int64() - origin
    } else {
      (col - range.column_start).to_int64()
    }
    if pos % (width + other_width) < width {
      0
    } else {
      1
    }
  } else if region == 9 || region == 10 {
    let offset = (row.to_int64() - origin) % (width + 1L)
    if (region == 9 && offset < width) || (region == 10 && offset >= 1L) {
      0
    } else {
      -1
    }
  } else if region == 11 || region == 12 {
    let offset = (col - range.column_start).to_int64() % (width + 1L)
    if (region == 11 && offset < width) || (region == 12 && offset >= 1L) {
      0
    } else {
      -1
    }
  } else {
    0
  }
}

///|
fn xlsx_merge_table_style(
  base : XlsxConditionalStyle,
  extra : XlsxConditionalStyle,
) -> XlsxConditionalStyle {
  {
    bold: match extra.bold {
      Some(v) => Some(v)
      None => base.bold
    },
    italic: match extra.italic {
      Some(v) => Some(v)
      None => base.italic
    },
    strike: match extra.strike {
      Some(v) => Some(v)
      None => base.strike
    },
    underline: match extra.underline {
      Some(v) => Some(v)
      None => base.underline
    },
    color: match extra.color {
      Some(v) => Some(v)
      None => base.color
    },
    fill: match extra.fill {
      Some(v) => Some(v)
      None => base.fill
    },
    border: None,
  }
}

///|
fn XlsxWorkbook::xlsx_table_effective_style(
  self : XlsxWorkbook,
  base_id : Int32,
  extra_id : Int32,
  third_id : Int32,
  region : Int32,
  choice : Int32,
) -> XlsxConditionalStyle raise {
  if (region == 23 || region == 24) && choice > 0 {
    return xlsx_merge_table_style(
      self.xlsx_conditional_style(base_id),
      self.xlsx_conditional_style(if choice == 1 { extra_id } else { third_id }),
    )
  }
  if region == 18 && choice > 0 {
    let mut result = self.xlsx_conditional_style(base_id)
    if choice == 1 || choice == 3 {
      result = xlsx_merge_table_style(
        result,
        self.xlsx_conditional_style(extra_id),
      )
    }
    if choice == 2 || choice == 3 {
      result = xlsx_merge_table_style(
        result,
        self.xlsx_conditional_style(third_id),
      )
    }
    return result
  }
  if !((
      (region == 15 || region == 16 || (region >= 19 && region <= 22)) &&
      choice == 1
    ) ||
    (region == 17 && choice == 2)) {
    return self.xlsx_conditional_style(
      if choice == 0 {
        base_id
      } else {
        extra_id
      },
    )
  }
  xlsx_merge_table_style(
    self.xlsx_conditional_style(base_id),
    self.xlsx_conditional_style(extra_id),
  )
}

///|
// An unstyled table affects header marks, filters and data extraction.
fn XlsxWorkbook::xlsx_plain_table_area(
  self : XlsxWorkbook,
  part : String,
  style_cache : Map[String, Bool],
  style_id_cache : Map[String, (Int32, Int32, Int64, Int32, Int64, Int32)],
  complex_rules : Map[Int32, XlsxComplexTable],
  complex_cache : Map[String, XlsxComplexStyle?],
  table_rules : Array[
    (
      XlsxRange,
      Int32,
      Int64,
      Int64,
      Int32,
      Int32,
      Int32,
      Int64,
      Int64,
      Int32,
      Int64,
      Int32,
      Int64,
    ),
  ],
) -> Int64 raise {
  let data = self.package.read(part) catch { _ => return -1L }
  let text = @utf8.decode_lossy(data[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    return -1L
  }
  let table = xlsx_read_list_table(data) catch { _ => None }
  let parsed_table = match table {
    Some(t) => t
    None => return -1L
  }
  let range = parsed_table.range
  if range.row_start < 0L ||
    range.row_end < range.row_start ||
    range.row_end >= 1048576L ||
    range.column_start < 0 ||
    range.column_end < range.column_start ||
    range.column_end >= 16384 {
    return -1L
  }
  let area = (range.row_end - range.row_start + 1L) *
    (range.column_end - range.column_start + 1).to_int64()
  let reader = @xml.NamespaceReader::from_string(text)
  let mut depth = 0
  let mut style_info_seen = false
  let mut style_rule = -1
  let mut complex_style : XlsxComplexStyle? = None
  let mut selected_region = 0
  let mut selected_width = 1L
  let mut other_rule = -1
  let mut third_rule = -1
  let mut other_width = 1L
  let mut first_column = false
  let mut last_column = false
  let mut row_stripes = false
  let mut column_stripes = false
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        if depth == 0 && name != "table" {
          return -1L
        }
        if depth == 1 && name == "tableStyleInfo" && !style_info_seen {
          style_info_seen = true
          first_column = xlsx_table_style_flag(element, "showFirstColumn")
          last_column = xlsx_table_style_flag(element, "showLastColumn")
          row_stripes = xlsx_table_style_flag(element, "showRowStripes")
          column_stripes = xlsx_table_style_flag(element, "showColumnStripes")
          let style = xlsx_decode_string(xlsx_attr(element, "name", ""))
          if style != "" {
            let accepted = match style_cache.get(style) {
              Some(value) => value
              None => {
                let value = self.xlsx_nonformatting_table_style(style)
                style_cache[style] = value
                value
              }
            }
            if !accepted {
              let (rule, region, width, extra, extra_width, last) = match
                style_id_cache.get(style) {
                Some(value) => value
                None => {
                  let value = self.xlsx_table_style(style)
                  style_id_cache[style] = value
                  value
                }
              }
              style_rule = rule
              selected_region = region
              selected_width = width
              other_rule = extra
              third_rule = last
              other_width = extra_width
              if style_rule < 0 {
                complex_style = match complex_cache.get(style) {
                  Some(value) => value
                  None => {
                    let value = self.xlsx_complex_table_style(style)
                    complex_cache[style] = value
                    value
                  }
                }
                match complex_style {
                  Some(value) => {
                    for id in value.ids {
                      if id >= 0 {
                        style_rule = id
                        break
                      }
                    }
                    selected_region = 25
                  }
                  None => return -1L
                }
              }
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
        if depth == 0 {
          break
        }
      }
      Eof => if depth == 0 { break } else { return -1L }
      _ => ()
    }
  }
  let header_corner = selected_region == 5 || selected_region == 6
  let total_corner = selected_region == 7 || selected_region == 8
  let stripe_region = selected_region >= 9 && selected_region <= 14
  let stripe_active = if selected_region == 9 ||
    selected_region == 10 ||
    selected_region == 13 {
    row_stripes
  } else {
    column_stripes
  }
  let stripe_origin = if selected_region == 15 {
    Int64::min(
      range.row_end,
      range.row_start + parsed_table.header_rows.to_int64() - 1L,
    )
  } else if selected_region == 16 {
    if parsed_table.totals_rows > 0 {
      Int64::max(
        range.row_start,
        range.row_end - parsed_table.totals_rows.to_int64() + 1L,
      )
    } else {
      range.row_end + 1L
    }
  } else {
    range.row_start + parsed_table.header_rows.to_int64()
  }
  let stripe_start = Int64::min(
    range.row_end + 1L,
    Int64::max(range.row_start, stripe_origin),
  )
  let stripe_end = Int64::max(
    range.row_start - 1L,
    Int64::min(
      range.row_end,
      range.row_end - parsed_table.totals_rows.to_int64(),
    ),
  )
  let style_start = if stripe_region {
    if stripe_active {
      stripe_start
    } else {
      range.row_end + 1L
    }
  } else if selected_region == 2 {
    if parsed_table.totals_rows > 0 {
      Int64::max(
        range.row_start,
        range.row_end - parsed_table.totals_rows.to_int64() + 1L,
      )
    } else {
      range.row_end + 1L
    }
  } else if total_corner {
    if parsed_table.totals_rows > 0 {
      range.row_end
    } else {
      range.row_end + 1L
    }
  } else {
    range.row_start
  }
  let style_end = if stripe_region {
    stripe_end
  } else if selected_region == 1 {
    if parsed_table.header_rows > 0 {
      Int64::min(
        range.row_end,
        range.row_start + parsed_table.header_rows.to_int64() - 1L,
      )
    } else {
      range.row_start - 1L
    }
  } else if header_corner {
    if parsed_table.header_rows > 0 {
      range.row_start
    } else {
      range.row_start - 1L
    }
  } else {
    range.row_end
  }
  let first_region = selected_region == 3 ||
    selected_region == 5 ||
    selected_region == 7
  let last_region = selected_region == 4 ||
    selected_region == 6 ||
    selected_region == 8
  let style_col_start = if (first_region && !first_column) ||
    (last_region && !last_column) {
    range.column_end + 1
  } else if last_region {
    range.column_end
  } else {
    range.column_start
  }
  let style_col_end = if first_region {
    range.column_start
  } else {
    range.column_end
  }
  let header_end = if parsed_table.header_rows > 0 {
    Int64::min(
      range.row_end,
      range.row_start + parsed_table.header_rows.to_int64() - 1L,
    )
  } else {
    range.row_start - 1L
  }
  let total_start = if parsed_table.totals_rows > 0 {
    Int64::max(
      range.row_start,
      range.row_end - parsed_table.totals_rows.to_int64() + 1L,
    )
  } else {
    range.row_end + 1L
  }
  let overlay_stripe = selected_region >= 19 && selected_region <= 24
  let overlay_active = if selected_region == 19 ||
    selected_region == 20 ||
    selected_region == 23 {
    row_stripes
  } else {
    column_stripes
  }
  let overlay_end = if overlay_active {
    range.row_end - parsed_table.totals_rows.to_int64()
  } else {
    stripe_origin - 1L
  }
  if complex_style is Some(style) {
    complex_rules[table_rules.length()] = {
      style,
      range,
      header: parsed_table.header_rows,
      totals: parsed_table.totals_rows,
      first_column,
      last_column,
      row_stripes,
      column_stripes,
    }
  }
  table_rules.push(
    (
      range,
      style_rule,
      style_start,
      style_end,
      style_col_start,
      style_col_end,
      selected_region,
      stripe_origin,
      if selected_region == 17 || selected_region == 18 {
        header_end
      } else {
        selected_width
      },
      other_rule,
      if selected_region == 17 || selected_region == 18 {
        total_start
      } else {
        other_width
      },
      third_rule,
      if overlay_stripe {
        overlay_end
      } else {
        0L
      },
    ),
  )
  area
}

///|
fn XlsxWorkbook::xlsx_plain_table_filters(
  self : XlsxWorkbook,
  part : String,
) -> Array[(Int32, Int32)] raise {
  let data = self.package.read(part) catch { _ => return [] }
  let table = match xlsx_read_list_table(data) {
    Some(value) => value
    None => return []
  }
  if table.header_rows <= 0 {
    return []
  }
  let reader = @xml.NamespaceReader::from_string(
    @utf8.decode_lossy(data[:], ignore_bom=true),
  )
  let hidden : Map[Int32, Bool] = Map([])
  let mut depth = 0
  let mut filter_depth = -1
  let mut seen = false
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        if depth == 1 && name == "autoFilter" && !seen {
          seen = true
          if event.kind is Start(_) {
            filter_depth = depth + 1
          }
        } else if depth == filter_depth && name == "filterColumn" {
          let raw = xlsx_trim(xlsx_attr(element, "colId", ""))
          let col = match xlsx_int(raw) {
            Some(value) => value
            None => {
              let value = @string.parse_double(raw) catch { _ => 0.0 }
              if value.is_nan() {
                0L
              } else if value.is_inf() || value <= -1.0 || value >= 16384.0 {
                -1L
              } else {
                value.to_int64()
              }
            }
          }
          if col >= 0L &&
            col < 16384L &&
            (
              xlsx_bool_or(element, "hiddenButton", false) ||
              !xlsx_bool_or(element, "showButton", true)
            ) {
            hidden[col.to_int()] = true
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
        if depth + 1 == filter_depth {
          filter_depth = -1
        }
        if depth == 0 {
          break
        }
      }
      Eof => break
      _ => ()
    }
  }
  if !seen {
    return []
  }
  let result : Array[(Int32, Int32)] = []
  let r = table.range
  for column in r.column_start..<=r.column_end {
    if !hidden.get(column - r.column_start).unwrap_or(false) {
      result.push((r.row_start.to_int(), column))
    }
  }
  result
}

///|
fn XlsxWorkbook::xlsx_check_plain_sheet(
  self : XlsxWorkbook,
  part : String,
) -> (
  Array[@sheet.GridLink],
  Bool,
  XlsxRange?,
  Array[(Int32, Int32)],
  Map[Int32, XlsxComplexTable],
  Array[
    (
      XlsxRange,
      Int32,
      Int64,
      Int64,
      Int32,
      Int32,
      Int32,
      Int64,
      Int64,
      Int32,
      Int64,
      Int32,
      Int64,
    ),
  ],
) raise {
  let data = self.package.read(part) catch {
    @ooxml.InvalidOoxml(message) => raise InvalidXlsxInput(message)
  }
  let text = @utf8.decode_lossy(data[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    raise InvalidXlsxInput("xlsx: the part declares entities")
  }
  let reader = @xml.NamespaceReader::from_string(text)
  let mut depth = 0
  let mut sheet_data_depth = -1
  let mut row_depth = -1
  let mut cell_depth = -1
  let mut inline_depth = -1
  let mut run_depth = -1
  let mut run_texts = 0
  let mut props_seen = false
  let mut props_depth = -1
  let mut run_size_seen = false
  let mut link_depth = -1
  let mut extension_depth = -1
  let mut table_depth = -1
  let mut table_room = 200000L
  let complex_rules : Map[Int32, XlsxComplexTable] = Map([])
  let complex_cache : Map[String, XlsxComplexStyle?] = Map([])
  let table_style_cache : Map[String, Bool] = Map([])
  let table_style_id_cache : Map[
    String,
    (Int32, Int32, Int64, Int32, Int64, Int32),
  ] = Map([])
  let table_rules : Array[
    (
      XlsxRange,
      Int32,
      Int64,
      Int64,
      Int32,
      Int32,
      Int32,
      Int64,
      Int64,
      Int32,
      Int64,
      Int32,
      Int64,
    ),
  ] = []
  let mut has_conditional = false
  let mut auto_filter : XlsxRange? = None
  let links : Array[@sheet.GridLink] = []
  let table_filters : Array[(Int32, Int32)] = []
  let relationships = self.package.relationships(part)
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        if depth == 1 {
          // The upstream worksheet reader ignores unrecognized top-level
          // metadata. These elements have rendering semantics there and must
          // remain unsupported until they are implemented here.
          if name == "AlternateContent" {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support worksheet feature " +
              name,
            )
          }
          if name == "drawing" {
            let id = xlsx_rel_id(element, "id")
            if id != "" && self.package.target(part, id) is Some(_) {
              raise InvalidXlsxInput(
                "xlsx: plain conversion does not support worksheet feature drawing",
              )
            }
          }
          if name == "tableParts" && event.kind is Start(_) {
            table_depth = depth + 1
          }
          if name == "sheetData" && event.kind is Start(_) {
            sheet_data_depth = depth + 1
          }
          if name == "hyperlinks" && event.kind is Start(_) {
            link_depth = depth + 1
          }
          if name == "conditionalFormatting" {
            has_conditional = true
          }
          if name == "autoFilter" {
            if xlsx_parse_range(xlsx_attr(element, "ref", "")) is Some(range) {
              auto_filter = Some(range)
            }
          }
          if name == "extLst" && event.kind is Start(_) {
            extension_depth = depth + 1
          }
        } else if depth == table_depth && name == "tablePart" {
          let id = xlsx_rel_id(element, "id")
          if self.package.target(part, id) is Some(rel) {
            let area = self.xlsx_plain_table_area(
              rel.target,
              table_style_cache,
              table_style_id_cache,
              complex_rules,
              complex_cache,
              table_rules,
            )
            if area < 0L || area > table_room {
              raise InvalidXlsxInput(
                "xlsx: plain conversion does not support worksheet feature tableParts",
              )
            }
            table_room -= area
            for cell in self.xlsx_plain_table_filters(rel.target) {
              table_filters.push(cell)
            }
          }
        } else if extension_depth >= 0 &&
          depth >= extension_depth &&
          name == "conditionalFormattings" {
          raise InvalidXlsxInput(
            "xlsx: plain conversion does not support extended conditional formatting",
          )
        } else if depth == link_depth && name == "hyperlink" {
          xlsx_add_plain_links(links, relationships, element)
        } else if depth == sheet_data_depth &&
          name == "row" &&
          event.kind is Start(_) {
          row_depth = depth + 1
        } else if depth == row_depth && name == "c" {
          let kind = xlsx_attr(element, "t", "")
          if kind != "" &&
            kind != "n" &&
            kind != "str" &&
            kind != "s" &&
            kind != "inlineStr" &&
            kind != "b" &&
            kind != "e" &&
            kind != "d" {
            raise InvalidXlsxInput(
              "xlsx: plain conversion supports only numeric, plain string, boolean and error cells",
            )
          }
          if event.kind is Start(_) {
            cell_depth = depth + 1
          }
        } else if depth == cell_depth && name == "is" && event.kind is Start(_) {
          inline_depth = depth + 1
          props_seen = false
          run_size_seen = false
        } else if depth == inline_depth && name == "r" {
          props_seen = false
          run_size_seen = false
          run_texts = 0
          if event.kind is Start(_) {
            run_depth = depth + 1
          } else {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support rich text",
            )
          }
        } else if depth == run_depth && name == "rPr" {
          if !props_seen {
            props_seen = true
            if event.kind is Start(_) {
              props_depth = depth + 1
            }
          }
        } else if depth == props_depth && name == "sz" && !run_size_seen {
          run_size_seen = true
          let raw = xlsx_trim(xlsx_attr(element, "val", "")).to_lower()
          let size = @string.parse_double(raw) catch { _ => 0.0 }
          if size.is_inf() ||
            size >= 1000000.0 ||
            raw.has_prefix("0x") ||
            raw.has_prefix("+0x") ||
            raw.has_prefix("-0x") {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support rich text with this run font size",
            )
          }
        } else if depth == run_depth && name == "t" {
          run_texts += 1
        }
        if event.kind is Start(_) {
          depth += 1
        } else if depth == 0 {
          break
        }
      }
      End(_) => {
        depth -= 1
        if depth + 1 == props_depth {
          props_depth = -1
        }
        if depth + 1 == run_depth {
          if run_texts == 0 {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support rich text",
            )
          }
          run_depth = -1
        }
        if depth + 1 == link_depth {
          link_depth = -1
        }
        if depth + 1 == extension_depth {
          extension_depth = -1
        }
        if depth + 1 == table_depth {
          table_depth = -1
        }
        if depth + 1 == inline_depth {
          inline_depth = -1
        }
        if depth + 1 == cell_depth {
          cell_depth = -1
        }
        if depth + 1 == row_depth {
          row_depth = -1
        }
        if depth + 1 == sheet_data_depth {
          sheet_data_depth = -1
        }
        if depth == 0 {
          break
        }
      }
      Eof =>
        if depth == 0 {
          break
        } else {
          raise InvalidXlsxInput("xlsx: unexpected EOF")
        }
      _ => ()
    }
  }
  (
    links, has_conditional, auto_filter, table_filters, complex_rules, table_rules,
  )
}

///|
fn xlsx_add_plain_links(
  links : Array[@sheet.GridLink],
  relationships : Array[@ooxml.OoxmlRelationship],
  element : @xml.NamespaceElement,
) -> Unit raise {
  let id = xlsx_rel_id(element, "id")
  if id == "" {
    return
  }
  let mut target = ""
  let mut external = false
  for rel in relationships {
    if rel.id == id {
      target = rel.target
      external = rel.external
      break
    }
  }
  if !external {
    return
  }
  if !target.has_prefix("http:") &&
    !target.has_prefix("https:") &&
    !target.has_prefix("mailto:") {
    return
  }
  if (target.has_prefix("http:") && !target.has_prefix("http://")) ||
    (target.has_prefix("https:") && !target.has_prefix("https://")) {
    raise InvalidXlsxInput("xlsx: unsupported hyperlink URL")
  }
  let location = xlsx_attr(element, "location", "")
  if location != "" {
    target = target + "#" + location
  }
  let bytes = @utf8.encode(target)
  let mut index = 0
  while index < bytes.length() {
    let b = bytes[index]
    let n = b.to_int()
    if n < 33 ||
      n > 126 ||
      b == b'[' ||
      b == b']' ||
      b == b'\\' ||
      b == b'"' ||
      b == b'<' ||
      b == b'>' ||
      b == b'`' ||
      b == b'{' ||
      b == b'}' ||
      b == b'^' ||
      b == b'|' {
      raise InvalidXlsxInput("xlsx: unsupported hyperlink URL")
    }
    if b == b'%' {
      if index + 2 >= bytes.length() ||
        !xlsx_url_hex(bytes[index + 1]) ||
        !xlsx_url_hex(bytes[index + 2]) {
        raise InvalidXlsxInput("xlsx: unsupported hyperlink URL")
      }
      index += 2
    }
    index += 1
  }
  // Keep the HTTP authority to a simple host and optional numeric port.
  // Other forms are rejected until URL parsing matches Go's url.Parse.
  if target.has_prefix("http://") || target.has_prefix("https://") {
    let bytes = @utf8.encode(target)
    let mut i = if target.has_prefix("http://") { 7 } else { 8 }
    let mut port = false
    while i < bytes.length() {
      let b = bytes[i]
      if b == b'/' || b == b'?' || b == b'#' {
        break
      }
      if b == b':' && !port {
        port = true
      } else if port {
        if b < b'0' || b > b'9' {
          raise InvalidXlsxInput("xlsx: unsupported hyperlink URL")
        }
      } else if !((b >= b'a' && b <= b'z') ||
        (b >= b'A' && b <= b'Z') ||
        (b >= b'0' && b <= b'9') ||
        b == b'.' ||
        b == b'-') {
        raise InvalidXlsxInput("xlsx: unsupported hyperlink URL")
      }
      i += 1
    }
  }
  let buffer = StringBuilder()
  for ch in xlsx_attr(element, "ref", "") {
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      buffer.write_char(' ')
    } else {
      buffer.write_char(ch)
    }
  }
  for item in buffer.to_string().split(" ") {
    if item == "" {
      continue
    }
    if xlsx_parse_range(item.to_owned()) is Some(range) &&
      range.row_start < 1048576L &&
      range.column_start < 16384 {
      links.push({
        row_start: range.row_start.to_int(),
        row_end: Int64::min(range.row_end, 1048575L).to_int(),
        column_start: range.column_start,
        column_end: Int32::min(range.column_end, 16383),
        target,
      })
    }
  }
}

///|
fn xlsx_url_hex(b : Byte) -> Bool {
  (b >= b'0' && b <= b'9') ||
  (b >= b'A' && b <= b'F') ||
  (b >= b'a' && b <= b'f')
}

///|
fn XlsxWorkbook::xlsx_check_plain_strings(self : XlsxWorkbook) -> Unit raise {
  let rel = match
    self.package.relationship_of_type(self.part, "/sharedStrings") {
    Some(r) => r
    None => return
  }
  let data = self.package.read(rel.target) catch { _ => return }
  let text = @utf8.decode_lossy(data[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    raise InvalidXlsxInput("xlsx: the part declares entities")
  }
  let reader = @xml.NamespaceReader::from_string(text)
  let mut depth = 0
  let mut string_depth = -1
  let mut run_depth = -1
  let mut run_texts = 0
  let mut props_seen = false
  let mut props_depth = -1
  let mut run_size_seen = false
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        if depth == 1 && name == "si" && event.kind is Start(_) {
          string_depth = depth + 1
          props_seen = false
          run_size_seen = false
        } else if depth == string_depth && name == "r" {
          props_seen = false
          run_size_seen = false
          run_texts = 0
          if event.kind is Start(_) {
            run_depth = depth + 1
          } else {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support rich text",
            )
          }
        } else if depth == run_depth && name == "rPr" {
          if !props_seen {
            props_seen = true
            if event.kind is Start(_) {
              props_depth = depth + 1
            }
          }
        } else if depth == props_depth && name == "sz" && !run_size_seen {
          run_size_seen = true
          let raw = xlsx_trim(xlsx_attr(element, "val", "")).to_lower()
          let size = @string.parse_double(raw) catch { _ => 0.0 }
          if size.is_inf() ||
            size >= 1000000.0 ||
            raw.has_prefix("0x") ||
            raw.has_prefix("+0x") ||
            raw.has_prefix("-0x") {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support rich text with this run font size",
            )
          }
        } else if depth == run_depth && name == "t" {
          run_texts += 1
        }
        if event.kind is Start(_) {
          depth += 1
        } else if depth == 0 {
          break
        }
      }
      End(_) => {
        depth -= 1
        if depth + 1 == props_depth {
          props_depth = -1
        }
        if depth + 1 == run_depth {
          if run_texts == 0 {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support rich text",
            )
          }
          run_depth = -1
        }
        if depth + 1 == string_depth {
          string_depth = -1
        }
        if depth == 0 {
          break
        }
      }
      Eof =>
        if depth == 0 {
          break
        } else {
          raise InvalidXlsxInput("xlsx: unexpected EOF")
        }
      _ => ()
    }
  }
}

///|
fn xlsx_check_plain_style(styles : XlsxStyles, style : Int32) -> Unit raise {
  let index = if style < 0 || style >= styles.cell_formats.length() {
    0
  } else {
    style
  }
  let format = styles.cell_formats[index]
  let a = format.alignment
  let font_index = if format.font < 0 || format.font >= styles.fonts.length() {
    0
  } else {
    format.font
  }
  let font = styles.fonts[font_index]
  let nondefault_fill = format.fill >= 0 &&
    format.fill < styles.fills.length() &&
    (
      styles.fills[format.fill].pattern != "" ||
      styles.fills[format.fill].gradient is Some(_)
    )
  let solid_fill = format.fill >= 0 &&
    format.fill < styles.fills.length() &&
    styles.fills[format.fill].pattern == "solid" &&
    styles.fills[format.fill].gradient is None
  let nondefault_border = if format.border >= 0 &&
    format.border < styles.borders.length() {
    let b = styles.borders[format.border]
    b.left.style != "" ||
    b.right.style != "" ||
    b.top.style != "" ||
    b.bottom.style != "" ||
    b.diagonal.style != "" ||
    b.vertical.style != "" ||
    b.horizontal.style != "" ||
    b.diagonal_up ||
    b.diagonal_down
  } else {
    false
  }
  let complex_border = if format.border >= 0 &&
    format.border < styles.borders.length() {
    let b = styles.borders[format.border]
    b.vertical.style != "" || b.horizontal.style != ""
  } else {
    false
  }
  if (font.scheme != "" && font.scheme != "minor" && font.scheme != "major") ||
    (
      font.vertical != "" &&
      font.vertical != "superscript" &&
      font.vertical != "subscript"
    ) ||
    (
      a.horizontal != "general" &&
      a.horizontal != "center" &&
      a.horizontal != "centerContinuous" &&
      a.horizontal != "left" &&
      a.horizontal != "right"
    ) ||
    (a.vertical != "bottom" && a.vertical != "top" && a.vertical != "center") ||
    a.rotation != 0 ||
    (nondefault_fill && (index == 0 || !solid_fill)) ||
    (index == 0 && nondefault_border) ||
    complex_border {
    raise InvalidXlsxInput(
      "xlsx: plain conversion does not support styled cells",
    )
  }
}

///|
/// Convert worksheets using estimated font metrics without embedding fonts.
/// Supports sheet views with numeric, plain string, boolean and error cells,
/// number formats, named and themed fonts, font colors, bold, italic, underlined
/// and struck text, superscript and subscript, horizontal alignment, top or
/// center vertical alignment, solid fills, line borders, merged cells, wrapping,
/// shrink-to-fit, indentation and center-across-selection.
/// Multiple border colors per line weight must use exact 8-bit RGB components;
/// patterned row and column fills, complex borders and other features are
/// rejected. Supported numeric conditional rules may apply a differential font,
/// solid fill and border or be inactive. For blank-cell fills or borders,
/// ranges are limited to 200,000 cells. Other conditional
/// formats are rejected.
/// Views with base fills are limited to 1,000,000 cells, and views
/// with base borders to 200,000 cells. External links support simple ASCII
/// HTTP(S) and mailto URLs with simple ASCII authorities; other URL forms are
/// rejected.
pub fn convert_plain_no_fonts(
  data : Bytes,
  data_mode~ : String = "",
  no_text_index~ : Bool = false,
) -> XlsxPlainResult raise {
  if data_mode != "" &&
    data_mode != "default" &&
    data_mode != "all" &&
    data_mode != "none" {
    raise InvalidXlsxInput("xlsx: invalid data mode")
  }
  let workbook = read_xlsx_workbook(data)
  let metadata = workbook.package.core_properties()
  let locale = workbook.locale()
  let styles = workbook.styles()
  let theme_colors = workbook.xlsx_plain_theme_colors()
  xlsx_check_plain_style(styles, 0)
  workbook.xlsx_check_plain_strings()
  let shared_runs = workbook.xlsx_shared_run_texts()
  let dc : Map[String, Json] = Map([])
  for
    (key, values) in [
      ("title", metadata.title),
      ("creator", metadata.creator),
      ("subject", metadata.subject),
      ("description", metadata.description),
      ("identifier", metadata.identifier),
      ("language", metadata.language),
      ("created", metadata.created),
      ("modified", metadata.modified),
    ] {
    if values.length() == 1 {
      dc[key] = Json::string(values[0])
    } else if values.length() > 1 {
      dc[key] = Json::array(values.map(Json::string))
    }
  }
  let meta : Map[String, Json] = {
    "source": Json::string("xlsx"),
    "generator": Json::string("bdf-go/0.1"),
  }
  if !dc.is_empty() {
    meta["dc"] = Json::object(dc)
  }
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let mode = if data_mode == "default" { "" } else { data_mode }
  let warnings = workbook.warnings.copy()
  let grids : Array[@sheet.NamedGrid] = []
  let mut counter = 0
  let mut warned_rtl = false
  let warned_sheets : Map[String, Bool] = Map([])
  let doc_language = metadata.language.get(0).unwrap_or("")
  for index, ref in workbook.sheets {
    if ref.hidden {
      continue
    }
    if ref.chart {
      raise InvalidXlsxInput(
        "xlsx: plain conversion does not support chart sheets",
      )
    }
    let number = index + 1
    let id = "sheet" + number.to_string()
    let (drawn, geo, missing_formula_values) = workbook.xlsx_draw_plain_sheet(
      ref, styles, locale, doc_language, theme_colors, shared_runs,
    )
    let (next, table_warnings) = workbook.store_sheet_tables(
      writer,
      ref.part,
      ref.name,
      number,
      id,
      mode,
      counter,
      locale.number_locale,
    )
    counter = next
    for warning in table_warnings {
      warnings.push(warning)
    }
    if !warned_sheets.contains(ref.name) && missing_formula_values > 0 {
      warnings.push(
        "sheet " +
        xlsx_go_quote(ref.name, '"') +
        ": " +
        missing_formula_values.to_string() +
        " formula cell(s) have no calculated value and are left empty (the workbook was saved without calculating them)",
      )
    }
    if !warned_sheets.contains(ref.name) && geo.right_to_left && !warned_rtl {
      warnings.push(
        "sheet " +
        xlsx_go_quote(ref.name, '"') +
        ": right-to-left sheets are drawn left to right",
      )
      warned_rtl = true
    }
    warned_sheets[ref.name] = true
    grids.push({
      id,
      title: ref.name,
      grid: drawn,
      gridlines: geo.show_grid,
      frozen_columns: Int32::min(geo.frozen_columns, 16384),
    })
  }
  @sheet.store_grids(writer, grids, !no_text_index)
  { bdf: writer.write_single(), warnings, sheets: grids.length(), }
}

///|
fn XlsxWorkbook::xlsx_draw_plain_sheet(
  workbook : XlsxWorkbook,
  ref : XlsxSheetRef,
  input_styles : XlsxStyles,
  locale : XlsxLocale,
  doc_language : String,
  theme_colors : Map[Int32, XlsxRgb],
  shared_runs : Array[XlsxPlainRun?],
) -> (@sheet.DrawnGrid, XlsxSheetGeometry, Int32) raise {
  let (
    links,
    has_conditional,
    filter_range,
    table_filters,
    complex_rules,
    table_rules,
  ) = workbook.xlsx_check_plain_sheet(ref.part)
  let (parsed, rich_cells) = workbook.xlsx_read_sheet_cells_with_runs(
    ref.part,
    shared_runs,
  )
  let mut styled_runs = false
  for _, columns in rich_cells {
    for _, run in columns {
      if run.font is Some(_) || !run.segments.is_empty() {
        styled_runs = true
      }
    }
  }
  let mut has_table_style = false
  for (_, id, _, _, _, _, _, _, _, _, _, _, _) in table_rules {
    if id >= 0 {
      has_table_style = true
    }
  }
  let styles = if has_conditional || styled_runs || has_table_style {
    {
      ..input_styles,
      fonts: input_styles.fonts.copy(),
      fills: input_styles.fills.copy(),
      borders: input_styles.borders.copy(),
      cell_formats: input_styles.cell_formats.map(format => {
        ..format,
        font: if format.font < 0 || format.font >= input_styles.fonts.length() {
          0
        } else {
          format.font
        },
        fill: if format.fill < 0 || format.fill >= input_styles.fills.length() {
          -1
        } else {
          format.fill
        },
        border: if format.border < 0 ||
          format.border >= input_styles.borders.length() {
          -1
        } else {
          format.border
        },
      }),
    }
  } else {
    input_styles
  }
  let mut rows = parsed.sorted_rows()
  let notes = workbook.xlsx_plain_notes(ref.part)
  let geo = workbook.read_sheet_geometry(ref.part)
  let (spans, region_rows, merge_regions) = xlsx_plain_spans(geo.merges)
  let center_across : Map[Int32, Map[Int32, Bool]] = Map([])
  for row in rows {
    for cell in row.cells {
      let index = if cell.style < 0 ||
        cell.style >= styles.cell_formats.length() {
        0
      } else {
        cell.style
      }
      let alignment = styles.cell_formats[index].alignment
      if alignment.horizontal == "centerContinuous" {
        let columns = match center_across.get(row.index) {
          Some(columns) => columns
          None => {
            let columns : Map[Int32, Bool] = Map([])
            center_across[row.index] = columns
            columns
          }
        }
        columns[cell.column] = cell.kind == 0
      }
    }
  }
  let mut base_fills = false
  let mut base_borders = false
  for column in geo.columns {
    if column.style >= 0 {
      let (fill, border) = xlsx_check_base_style(styles, column.style)
      base_fills = fill || base_fills
      base_borders = border || base_borders
    }
  }
  let (row_count, col_count) = xlsx_initial_extent(parsed, geo, notes)
  if has_conditional || styled_runs || has_table_style {
    rows = xlsx_normalize_conditional_styles(rows, styles.cell_formats.length())
  }
  if has_table_style {
    let matches : Map[Int32, Map[Int32, Map[Int32, Bool]]] = Map([])
    let matched_choices : Map[Int32, Array[Int32]] = Map([])
    for row in rows {
      for cell in row.cells {
        let format = input_styles.cell_formats[cell.style]
        if format.font != 0 {
          continue
        }
        for
          index, (
            range,
            id,
            style_start,
            style_end,
            style_col_start,
            style_col_end,
            region,
            origin,
            width,
            extra_id,
            extra_width,
            third_id,
            overlay_end,
          ) in table_rules {
          if row.index.to_int64() < range.row_start ||
            row.index.to_int64() > range.row_end ||
            cell.column < range.column_start ||
            cell.column > range.column_end {
            continue
          }
          let choice = if region == 25 {
            xlsx_complex_table_mask(
              complex_rules[index],
              row.index,
              cell.column,
            )
          } else {
            xlsx_table_stripe_choice(
              region,
              origin,
              range,
              width,
              extra_width,
              overlay_end,
              row.index,
              cell.column,
            )
          }
          let selected = if region == 25 {
            if choice != 0 {
              id
            } else {
              -1
            }
          } else if choice == 0 {
            id
          } else if (region == 18 && choice >= 2) ||
            ((region == 23 || region == 24) && choice == 2) {
            third_id
          } else {
            extra_id
          }
          if selected >= 0 &&
            choice >= 0 &&
            row.index.to_int64() >= style_start &&
            row.index.to_int64() <= style_end &&
            cell.column >= style_col_start &&
            cell.column <= style_col_end {
            let group_key = index * 8192 + choice
            let group = match matches.get(group_key) {
              Some(value) => value
              None => {
                let value : Map[Int32, Map[Int32, Bool]] = Map([])
                matches[group_key] = value
                let choices = match matched_choices.get(index) {
                  Some(existing) => existing
                  None => {
                    let existing : Array[Int32] = []
                    matched_choices[index] = existing
                    existing
                  }
                }
                choices.push(choice)
                value
              }
            }
            let columns = match group.get(row.index) {
              Some(value) => value
              None => {
                let value : Map[Int32, Bool] = Map([])
                group[row.index] = value
                value
              }
            }
            columns[cell.column] = true
          }
          break
        }
      }
    }
    for
      index, (_, id, _, _, _, _, region, _, _, extra_id, _, third_id, _) in table_rules {
      let choices = match matched_choices.get(index) {
        Some(value) => value
        None => []
      }
      choices.sort()
      for choice in choices {
        if region != 25 &&
          (
            (
              choice == 2 &&
              region != 17 &&
              region != 18 &&
              region != 23 &&
              region != 24
            ) ||
            (choice == 3 && region != 18)
          ) {
          continue
        }
        let selected = if region == 25 {
          if choice != 0 {
            id
          } else {
            -1
          }
        } else if choice == 0 {
          id
        } else if (region == 18 && choice >= 2) ||
          ((region == 23 || region == 24) && choice == 2) {
          third_id
        } else {
          extra_id
        }
        if selected >= 0 && matches.get(index * 8192 + choice) is Some(matched) {
          let diff = if region == 25 {
            workbook.xlsx_complex_table_effective_style(
              complex_rules[index],
              choice,
            )
          } else {
            workbook.xlsx_table_effective_style(
              id, extra_id, third_id, region, choice,
            )
          }
          let font_diff : XlsxConditionalStyle = { ..diff, fill: None, }
          rows = xlsx_apply_conditional_style(rows, styles, matched, font_diff)
        }
      }
    }
  }
  let layout_base_sizes = xlsx_rich_base_sizes(rows, styles, rich_cells)
  let (layout_rows, layout_styles) = if styled_runs {
    let layout_styles : XlsxStyles = {
      ..styles,
      fonts: styles.fonts.copy(),
      cell_formats: styles.cell_formats.copy(),
    }
    (xlsx_apply_plain_run_fonts(rows, layout_styles, rich_cells), layout_styles)
  } else {
    (rows, styles)
  }
  for
    table_index, (
      range,
      base_id,
      style_start,
      style_end,
      style_col_start,
      style_col_end,
      region,
      origin,
      width,
      extra_id,
      extra_width,
      third_id,
      overlay_end,
    ) in table_rules {
    let choices : Array[Int32] = []
    if region == 25 {
      let seen : Map[Int32, Bool] = Map([])
      let r0 = Int64::max(style_start, 0L).to_int()
      let r1 = Int64::min(style_end, (row_count - 1).to_int64()).to_int()
      let c0 = Int32::max(style_col_start, 0)
      let c1 = Int32::min(style_col_end, col_count - 1)
      if r0 <= r1 && c0 <= c1 {
        for r in r0..<=r1 {
          for c in c0..<=c1 {
            let mask = xlsx_complex_table_mask(complex_rules[table_index], r, c)
            if mask != 0 && !seen.contains(mask) {
              seen[mask] = true
              choices.push(mask)
            }
          }
        }
      }
    } else {
      choices.push(0)
      choices.push(1)
      choices.push(2)
      choices.push(3)
    }
    for choice in choices {
      if region != 25 &&
        (
          (
            choice == 2 &&
            region != 17 &&
            region != 18 &&
            region != 23 &&
            region != 24
          ) ||
          (choice == 3 && region != 18)
        ) {
        continue
      }
      let id = if region == 25 {
        base_id
      } else if choice == 0 {
        base_id
      } else if (region == 18 && choice >= 2) ||
        ((region == 23 || region == 24) && choice == 2) {
        third_id
      } else {
        extra_id
      }
      if id < 0 {
        continue
      }
      let diff = if region == 25 {
        workbook.xlsx_complex_table_effective_style(
          complex_rules[table_index],
          choice,
        )
      } else {
        workbook.xlsx_table_effective_style(
          base_id, extra_id, third_id, region, choice,
        )
      }
      if diff.fill is None {
        continue
      }
      let allowed : Map[Int32, Map[Int32, Bool]] = Map([])
      let first_row = Int64::max(style_start, 0L).to_int()
      let last_row = Int64::min(style_end, (row_count - 1).to_int64()).to_int()
      let first_col = Int32::max(style_col_start, 0)
      let last_col = Int32::min(style_col_end, col_count - 1)
      let row_styles : Map[Int32, Int32] = Map([])
      for row in parsed.sorted_rows() {
        row_styles[row.index] = row.style
      }
      let column_styles : Map[Int32, Int32] = Map([])
      for column in geo.columns {
        let lo = Int32::max(first_col, column.first)
        let hi = Int32::min(last_col, column.last)
        if lo <= hi {
          for c in lo..<=hi {
            column_styles[c] = column.style
          }
        }
      }
      if first_row <= last_row && first_col <= last_col {
        for r in first_row..<=last_row {
          let columns : Map[Int32, Bool] = Map([])
          for c in first_col..<=last_col {
            if (if region == 25 {
                xlsx_complex_table_mask(complex_rules[table_index], r, c)
              } else {
                xlsx_table_stripe_choice(
                  region, origin, range, width, extra_width, overlay_end, r, c,
                )
              }) !=
              choice {
              continue
            }
            for
              owner, (other, _, _, _, _, _, _, _, _, _, _, _, _) in table_rules {
              if r.to_int64() >= other.row_start &&
                r.to_int64() <= other.row_end &&
                c >= other.column_start &&
                c <= other.column_end {
                if owner == table_index {
                  let row_style = row_styles.get(r).unwrap_or(-1)
                  let base_style = if row_style >= 0 {
                    row_style
                  } else {
                    column_styles.get(c).unwrap_or(-1)
                  }
                  let index = if base_style < 0 ||
                    base_style >= input_styles.cell_formats.length() {
                    0
                  } else {
                    base_style
                  }
                  let fill_id = input_styles.cell_formats[index].fill
                  let nonempty = if fill_id >= 0 &&
                    fill_id < input_styles.fills.length() {
                    let fill = input_styles.fills[fill_id]
                    fill.pattern != "" || fill.gradient is Some(_)
                  } else {
                    false
                  }
                  if !nonempty {
                    columns[c] = true
                  }
                }
                break
              }
            }
          }
          allowed[r] = columns
        }
      }
      for row in parsed.sorted_rows() {
        if allowed.get(row.index) is Some(columns) {
          for cell in row.cells {
            if row.index.to_int64() < range.row_start ||
              row.index.to_int64() > range.row_end ||
              cell.column < first_col ||
              cell.column > last_col {
              continue
            }
            if (if region == 25 {
                xlsx_complex_table_mask(
                  complex_rules[table_index],
                  row.index,
                  cell.column,
                )
              } else {
                xlsx_table_stripe_choice(
                  region,
                  origin,
                  range,
                  width,
                  extra_width,
                  overlay_end,
                  row.index,
                  cell.column,
                )
              }) !=
              choice {
              continue
            }
            let mut owned = false
            for
              owner, (other, _, _, _, _, _, _, _, _, _, _, _, _) in table_rules {
              if row.index.to_int64() >= other.row_start &&
                row.index.to_int64() <= other.row_end &&
                cell.column >= other.column_start &&
                cell.column <= other.column_end {
                owned = owner == table_index
                break
              }
            }
            if !owned {
              continue
            }
            columns[cell.column] = true
            let index = if cell.style < 0 ||
              cell.style >= input_styles.cell_formats.length() {
              0
            } else {
              cell.style
            }
            let fill_id = input_styles.cell_formats[index].fill
            if fill_id >= 0 && fill_id < input_styles.fills.length() {
              let fill = input_styles.fills[fill_id]
              if fill.pattern != "" || fill.gradient is Some(_) {
                columns.remove(cell.column)
              }
            }
          }
        }
      }
      let matched : Map[Int32, Map[Int32, Bool]] = Map([])
      let chunks : Array[XlsxRange] = []
      let mut start = first_row
      while start <= last_row {
        let finish = Int32::min(start + 999, last_row)
        chunks.push({
          ..range,
          row_start: start.to_int64(),
          row_end: finish.to_int64(),
        })
        start = finish + 1
      }
      rows = xlsx_materialize_conditional_blanks(
        rows,
        geo,
        styles.cell_formats.length(),
        chunks,
        row_count,
        col_count,
        matched,
        Some(allowed),
      )
      for row in rows {
        if allowed.get(row.index) is Some(columns) {
          for cell in row.cells {
            if columns.contains(cell.column) {
              let result = match matched.get(row.index) {
                Some(value) => value
                None => {
                  let value : Map[Int32, Bool] = Map([])
                  matched[row.index] = value
                  value
                }
              }
              result[cell.column] = true
            }
          }
        }
      }
      let fill_diff : XlsxConditionalStyle = {
        ..diff,
        bold: None,
        italic: None,
        strike: None,
        underline: None,
        color: None,
      }
      rows = xlsx_apply_conditional_style(rows, styles, matched, fill_diff)
    }
  }
  if has_conditional {
    rows = workbook.xlsx_apply_plain_conditionals(
      ref.part,
      rows,
      styles,
      geo,
      row_count,
      col_count,
    )
  }
  let run_base_sizes = xlsx_rich_base_sizes(rows, styles, rich_cells)
  if styled_runs {
    rows = xlsx_apply_plain_run_fonts(rows, styles, rich_cells)
  }
  let visible_cols = xlsx_column_runs(geo, col_count, 7.0)
  let all_cols = xlsx_column_runs(geo, 16384, 7.0)
  let widths : Array[Double] = []
  for run in all_cols {
    for _ in 0..<run.count {
      widths.push(run.size.to_double())
    }
  }
  let columns : Array[@sheet.Run] = visible_cols.map(run => {
    count: run.count,
    size: run.size,
  })
  let all_columns : Array[@sheet.Run] = all_cols.map(run => {
    count: run.count,
    size: run.size,
  })
  let default_size = styles.fonts[0].size
  let fitted = xlsx_plain_fitted_rows(
    layout_rows,
    layout_styles,
    geo,
    spans,
    widths,
    workbook.date1904,
    locale.number_locale,
    default_size,
    rich_cells,
    layout_base_sizes,
  )
  let heights : Array[@sheet.Run] = xlsx_row_runs(
    layout_rows,
    geo,
    row_count,
    (0.9 + 0.25) * default_size,
    fitted,
  ).map(run => { count: run.count, size: run.size, })
  let geometry : @sheet.GridGeometry = {
    columns,
    rows: heights,
    frozen_rows: Int32::min(geo.frozen_rows, row_count),
  }
  let cells : Array[@sheet.SizedGridRow] = []
  let verticals : Map[Int32, Map[Int32, String]] = Map([])
  let horizontals : Map[Int32, Map[Int32, String]] = Map([])
  let bolds : Map[Int32, Map[Int32, Bool]] = Map([])
  let italics : Map[Int32, Map[Int32, Bool]] = Map([])
  let decorations : Map[Int32, Map[Int32, @sheet.GridTextDecoration]] = Map([])
  let rich_colors : Map[Int32, Map[Int32, Array[@sheet.GridRichColorRun]]] = Map([],
  )
  let scripts : Map[Int32, Map[Int32, String]] = Map([])
  let shrink_scales : Map[Int32, Map[Int32, Double]] = Map([])
  let indents : Map[Int32, Map[Int32, Double]] = Map([])
  let fills : Map[Int32, Map[Int32, @sheet.GridSolidFill]] = Map([])
  let sizes : Map[Int32, Map[Int32, Double]] = Map([])
  let wraps : Map[Int32, Map[Int32, Bool]] = Map([])
  let font_families : Map[Int32, Map[Int32, String]] = Map([])
  let east_asian_fonts : Map[Int32, Map[Int32, String]] = Map([])
  let theme = workbook.package.theme_fonts(workbook.part)
  let borders : Map[Int32, Map[Int32, @sheet.GridCellBorder]] = Map([])
  let diagonals : Map[Int32, Map[Int32, @sheet.GridCellDiagonal]] = Map([])
  let border_colors : Map[Int32, Map[Int32, Array[UInt32]]] = Map([])
  let border_colors_by_weight : Map[Int32, XlsxRgb] = Map([])
  let checked_styles : Map[Int32, Bool] = Map([])
  let format_cache : Map[Int32, Array[XlsxFormatSection]] = Map([])
  let color_cache : Map[Int32, UInt32] = Map([])
  let border_cache : Map[Int32, (@sheet.GridCellBorder, Array[XlsxRgb])] = Map([])
  for row in rows {
    if row.style >= 0 {
      let (fill, border) = xlsx_check_base_style(styles, row.style)
      base_fills = fill || base_fills
      base_borders = border || base_borders
    }
    let entries : Array[@sheet.SizedGridCell] = []
    for cell in row.cells {
      if cell.kind != 0 &&
        cell.kind != 1 &&
        cell.kind != 2 &&
        cell.kind != 3 &&
        cell.kind != 4 {
        raise InvalidXlsxInput(
          "xlsx: plain conversion does not support this cell",
        )
      }
      if !checked_styles.contains(cell.style) {
        xlsx_check_plain_style(styles, cell.style)
        checked_styles[cell.style] = true
      }
      let format_index = if cell.style < 0 ||
        cell.style >= styles.cell_formats.length() {
        0
      } else {
        cell.style
      }
      let font_id = styles.cell_formats[format_index].font
      let font_index = if font_id < 0 || font_id >= styles.fonts.length() {
        0
      } else {
        font_id
      }
      let font_size = styles.fonts[font_index].size
      let font = styles.fonts[font_index]
      let drawn_size = if font.vertical == "" {
        font_size
      } else {
        font_size * (2.0 / 3.0)
      }
      let themed_latin = if font.scheme == "minor" {
        theme.resolve("+mn-lt", locale.script)
      } else if font.scheme == "major" {
        theme.resolve("+mj-lt", locale.script)
      } else {
        ""
      }
      let font_name = if themed_latin != "" {
        themed_latin
      } else if font.name != "" {
        font.name
      } else {
        "Calibri"
      }
      if font_name != "Calibri" {
        let columns = match font_families.get(row.index) {
          Some(columns) => columns
          None => {
            let columns : Map[Int32, String] = Map([])
            font_families[row.index] = columns
            columns
          }
        }
        columns[cell.column] = font_name
      }
      let east_asian = if font.scheme == "minor" {
        theme.resolve("+mn-ea", locale.script)
      } else if font.scheme == "major" {
        theme.resolve("+mj-ea", locale.script)
      } else {
        ""
      }
      if east_asian != "" {
        let columns = match east_asian_fonts.get(row.index) {
          Some(columns) => columns
          None => {
            let columns : Map[Int32, String] = Map([])
            east_asian_fonts[row.index] = columns
            columns
          }
        }
        columns[cell.column] = east_asian
      }
      let span = xlsx_plain_region_at(
        spans,
        region_rows,
        row.index,
        cell.column,
      )
      let wrap = styles.cell_formats[format_index].alignment.wrap
      let indent = xlsx_plain_indent(
        styles.cell_formats[format_index].alignment,
        cell.kind,
      )
      let (border, colors) = match border_cache.get(format_index) {
        Some(border) => border
        None => {
          let border = xlsx_plain_border(styles, format_index, theme_colors)
          border_cache[format_index] = border
          border
        }
      }
      let border_id = styles.cell_formats[format_index].border
      if border_id >= 0 && border_id < styles.borders.length() {
        let source_border = styles.borders[border_id]
        if source_border.diagonal_up || source_border.diagonal_down {
          let (weight, color) = xlsx_plain_border_side(
            styles,
            source_border.diagonal,
            theme_colors,
          )
          if weight != 0 {
            xlsx_check_border_color(border_colors_by_weight, weight, color)
            let columns = match diagonals.get(row.index) {
              Some(columns) => columns
              None => {
                let columns : Map[Int32, @sheet.GridCellDiagonal] = Map([])
                diagonals[row.index] = columns
                columns
              }
            }
            columns[cell.column] = {
              weight,
              color: color.rgba(),
              up: source_border.diagonal_up,
              down: source_border.diagonal_down,
            }
          }
        }
      }
      if border.top != 0 ||
        border.bottom != 0 ||
        border.left != 0 ||
        border.right != 0 {
        let weights = [border.top, border.bottom, border.left, border.right]
        for i, weight in weights {
          if weight == 0 {
            continue
          }
          xlsx_check_border_color(border_colors_by_weight, weight, colors[i])
        }
        let columns = match borders.get(row.index) {
          Some(columns) => columns
          None => {
            let columns : Map[Int32, @sheet.GridCellBorder] = Map([])
            borders[row.index] = columns
            columns
          }
        }
        columns[cell.column] = if span is Some(region) {
          {
            top: if row.index == region.row_start {
              border.top
            } else {
              0
            },
            bottom: if row.index == region.row_end {
              border.bottom
            } else {
              0
            },
            left: if cell.column == region.column_start {
              border.left
            } else {
              0
            },
            right: if cell.column == region.column_end {
              border.right
            } else {
              0
            },
          }
        } else {
          border
        }
        let row_colors = match border_colors.get(row.index) {
          Some(row_colors) => row_colors
          None => {
            let row_colors : Map[Int32, Array[UInt32]] = Map([])
            border_colors[row.index] = row_colors
            row_colors
          }
        }
        row_colors[cell.column] = colors.map(color => color.rgba())
      }
      let fill_index = styles.cell_formats[format_index].fill
      if fill_index >= 0 && fill_index < styles.fills.length() {
        let fill = styles.fills[fill_index]
        if fill.pattern == "solid" {
          let columns = match fills.get(row.index) {
            Some(columns) => columns
            None => {
              let columns : Map[Int32, @sheet.GridSolidFill] = Map([])
              fills[row.index] = columns
              columns
            }
          }
          let black : XlsxRgb = { red: 0.0, green: 0.0, blue: 0.0, }
          columns[cell.column] = {
            key: xlsx_solid_fill_key(fill),
            color: styles
            .resolve_color(fill.foreground, black, theme_colors)
            .rgba(),
          }
        }
      }
      let formatted = if cell.kind == 1 {
        Some(
          xlsx_format_number(
            styles.cached_number_sections(
              cell.style,
              locale.number_locale,
              format_cache,
            ),
            cell.number,
            workbook.date1904,
          ),
        )
      } else if cell.kind == 2 &&
        rich_cells.get(row.index) is Some(columns) &&
        columns.get(cell.column) is Some(text) {
        Some(xlsx_plain_run_format(text.text))
      } else if cell.kind == 2 {
        Some(
          xlsx_format_text(
            styles.cached_number_sections(
              cell.style,
              locale.number_locale,
              format_cache,
            ),
            cell.text,
          ),
        )
      } else {
        styles.format_cell(cell, workbook.date1904, locale.number_locale)
      }
      if formatted is Some(formatted) {
        for piece in formatted.pieces {
          if piece.kind != 0 {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support format gaps or fills",
            )
          }
        }
        let mut text = formatted.text()
        if styles.cell_formats[format_index].alignment.shrink &&
          !wrap &&
          cell.kind != 1 {
          let mut cell_width = if cell.column >= 0 &&
            cell.column < widths.length() {
            widths[cell.column]
          } else {
            0.0
          }
          if span is Some(region) && cell.column == region.column_start {
            cell_width = 0.0
            for column in region.column_start..<=region.column_end {
              cell_width += widths[column]
            }
          }
          if styles.cell_formats[format_index].alignment.horizontal ==
            "centerContinuous" {
            let last = xlsx_plain_center_end(
              center_across,
              row.index,
              cell.column,
              col_count,
            )
            if last > cell.column {
              cell_width = 0.0
              for column in cell.column..<=last {
                cell_width += widths[column]
              }
            }
          }
          let available = Double::max(cell_width - 3.75 - indent, 0.0)
          let scale = if rich_cells.get(row.index) is Some(columns) &&
            columns.get(cell.column) is Some(run) &&
            !run.segments.is_empty() {
            let base_size = match run_base_sizes.get(row.index) {
              Some(sizes) => sizes.get(cell.column).unwrap_or(drawn_size)
              None => drawn_size
            }
            xlsx_rich_shrink_scale(
              run.segments,
              base_size,
              font.vertical,
              available,
            )
          } else {
            xlsx_plain_shrink_scale(text, available, drawn_size)
          }
          if scale != 1.0 {
            let columns = match shrink_scales.get(row.index) {
              Some(columns) => columns
              None => {
                let columns : Map[Int32, Double] = Map([])
                shrink_scales[row.index] = columns
                columns
              }
            }
            columns[cell.column] = scale
          }
        }
        if cell.kind == 1 && !wrap {
          let mut cell_width = if cell.column >= 0 &&
            cell.column < widths.length() {
            widths[cell.column]
          } else {
            0.0
          }
          if span is Some(region) && cell.column == region.column_start {
            cell_width = 0.0
            for column in region.column_start..<=region.column_end {
              cell_width += widths[column]
            }
          }
          if styles.cell_formats[format_index].alignment.horizontal ==
            "centerContinuous" {
            let last = xlsx_plain_center_end(
              center_across,
              row.index,
              cell.column,
              col_count,
            )
            if last > cell.column {
              cell_width = 0.0
              for column in cell.column..<=last {
                cell_width += widths[column]
              }
            }
          }
          let mut width = 0.0
          for c in text {
            width += @sheet.sized_fallback_advance(c, false, drawn_size)
          }
          if cell.column >= 0 &&
            cell.column < widths.length() &&
            cell_width > 0.0 &&
            width > cell_width - 3.75 - indent + 0.01 {
            let available = Double::max(cell_width - 3.75 - indent, 0.0)
            text = if formatted.general {
              xlsx_fit_plain_number(cell.number, available, drawn_size)
            } else {
              "#".repeat(
                (available /
                @sheet.sized_fallback_advance('#', false, drawn_size)).to_int(),
              )
            }
          }
        }
        let vertical = styles.cell_formats[format_index].alignment.vertical
        let horizontal = styles.cell_formats[format_index].alignment.horizontal
        if indent != 0.0 {
          let columns = match indents.get(row.index) {
            Some(columns) => columns
            None => {
              let columns : Map[Int32, Double] = Map([])
              indents[row.index] = columns
              columns
            }
          }
          columns[cell.column] = indent
        }
        if wrap {
          let columns = match wraps.get(row.index) {
            Some(columns) => columns
            None => {
              let columns : Map[Int32, Bool] = Map([])
              wraps[row.index] = columns
              columns
            }
          }
          columns[cell.column] = true
        }
        if font_size != 11.0 {
          let columns = match sizes.get(row.index) {
            Some(columns) => columns
            None => {
              let columns : Map[Int32, Double] = Map([])
              sizes[row.index] = columns
              columns
            }
          }
          columns[cell.column] = font_size
        }
        if styles.fonts[font_index].bold {
          let columns = match bolds.get(row.index) {
            Some(columns) => columns
            None => {
              let columns : Map[Int32, Bool] = Map([])
              bolds[row.index] = columns
              columns
            }
          }
          columns[cell.column] = true
        }
        if styles.fonts[font_index].italic {
          let columns = match italics.get(row.index) {
            Some(columns) => columns
            None => {
              let columns : Map[Int32, Bool] = Map([])
              italics[row.index] = columns
              columns
            }
          }
          columns[cell.column] = true
        }
        if font.underline != "" || font.strike {
          let columns = match decorations.get(row.index) {
            Some(columns) => columns
            None => {
              let columns : Map[Int32, @sheet.GridTextDecoration] = Map([])
              decorations[row.index] = columns
              columns
            }
          }
          columns[cell.column] = {
            underline: font.underline,
            strike: font.strike,
          }
        }
        if font.vertical != "" &&
          !(rich_cells.get(row.index) is Some(cols) &&
          cols.get(cell.column) is Some(r) &&
          !r.segments.is_empty()) {
          let columns = match scripts.get(row.index) {
            Some(columns) => columns
            None => {
              let columns : Map[Int32, String] = Map([])
              scripts[row.index] = columns
              columns
            }
          }
          columns[cell.column] = font.vertical
        }
        if vertical != "bottom" {
          let columns = match verticals.get(row.index) {
            Some(columns) => columns
            None => {
              let columns : Map[Int32, String] = Map([])
              verticals[row.index] = columns
              columns
            }
          }
          columns[cell.column] = vertical
        }
        if horizontal == "left" || horizontal == "right" {
          let columns = match horizontals.get(row.index) {
            Some(columns) => columns
            None => {
              let columns : Map[Int32, String] = Map([])
              horizontals[row.index] = columns
              columns
            }
          }
          columns[cell.column] = horizontal
        }
        if rich_cells.get(row.index) is Some(columns) &&
          columns.get(cell.column) is Some(run) &&
          !run.segments.is_empty() {
          let alignment = styles.cell_formats[format_index].alignment
          if horizontal != "general" &&
            horizontal != "left" &&
            horizontal != "right" &&
            horizontal != "center" &&
            horizontal != "centerContinuous" {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support these styled rich text runs",
            )
          }
          let original_size = match run_base_sizes.get(row.index) {
            Some(sizes) => sizes.get(cell.column).unwrap_or(font.size)
            None => font.size
          }
          let default_color = xlsx_plain_font_color(
            styles,
            cell.style,
            theme_colors,
          )
          let black : XlsxRgb = { red: 0.0, green: 0.0, blue: 0.0, }
          let segments : Array[@sheet.GridRichColorRun] = []
          let visible_segments = xlsx_shown_segments(
            run.segments,
            alignment.wrap,
          )
          let mut previous_plain = false
          for segment in visible_segments {
            if segment.text == "" {
              continue
            }
            let color = match segment.font {
              None => default_color
              Some(segment_font) => {
                let varying = (
                    segment_font.size > 0.0 && segment_font.size != font.size
                  ) ||
                  segment_font.vertical != ""
                if varying &&
                  (
                    (
                      horizontal != "general" &&
                      horizontal != "left" &&
                      horizontal != "right" &&
                      horizontal != "center" &&
                      horizontal != "centerContinuous"
                    ) ||
                    !visible_segments
                    .iter()
                    .all(part => {
                      part.text == "" ||
                      (match part.font {
                        Some(f) =>
                          (if f.size > 0.0 { f.size } else { original_size }) <=
                          font.size
                        None => original_size <= font.size
                      })
                    })
                  ) {
                  raise InvalidXlsxInput(
                    "xlsx: plain conversion does not support these styled rich text runs",
                  )
                }
                if segment_font.color.kind == 0 {
                  default_color
                } else {
                  if segment_font.color.kind == 2 &&
                    segment_font.color.index >= 0 &&
                    segment_font.color.index < 12 &&
                    !theme_colors.contains(segment_font.color.index) {
                    raise InvalidXlsxInput(
                      "xlsx: plain conversion does not support this theme color",
                    )
                  }
                  styles
                  .resolve_color(segment_font.color, black, theme_colors)
                  .rgba()
                }
              }
            }
            let plain = segment.font is None
            if plain && previous_plain && !segments.is_empty() {
              let last = segments.length() - 1
              segments[last] = {
                ..segments[last],
                text: segments[last].text + segment.text,
              }
            } else {
              let (bold, italic, underline, strike) = match segment.font {
                None => (font.bold, font.italic, font.underline, font.strike)
                Some(font) =>
                  (font.bold, font.italic, font.underline, font.strike)
              }
              let family_override = match segment.font {
                Some(font) => font.name != ""
                None => false
              }
              let family = match segment.font {
                Some(font) if font.name != "" => {
                  let themed = if font.scheme == "minor" {
                    theme.resolve("+mn-lt", locale.script)
                  } else if font.scheme == "major" {
                    theme.resolve("+mj-lt", locale.script)
                  } else {
                    ""
                  }
                  if themed != "" {
                    themed
                  } else {
                    font.name
                  }
                }
                _ => ""
              }
              let east_asian = match segment.font {
                Some(font) if font.name != "" =>
                  if font.scheme == "minor" {
                    theme.resolve("+mn-ea", locale.script)
                  } else if font.scheme == "major" {
                    theme.resolve("+mj-ea", locale.script)
                  } else {
                    ""
                  }
                _ => ""
              }
              segments.push({
                text: segment.text,
                color,
                family_override,
                family,
                east_asian,
                size: {
                  let effective = match segment.font {
                    Some(font) if font.size > 0.0 => font.size
                    _ => original_size
                  }
                  if effective != styles.fonts[font_index].size {
                    effective
                  } else {
                    0.0
                  }
                },
                bold,
                italic,
                underline,
                strike,
                vertical: match segment.font {
                  Some(f) => f.vertical
                  None => font.vertical
                },
              })
            }
            previous_plain = plain
          }
          let row_colors = match rich_colors.get(row.index) {
            Some(row_colors) => row_colors
            None => {
              let row_colors : Map[Int32, Array[@sheet.GridRichColorRun]] = Map([],
              )
              rich_colors[row.index] = row_colors
              row_colors
            }
          }
          row_colors[cell.column] = segments
        }
        entries.push({
          column: cell.column,
          cell: { text, number: cell.kind == 1, },
          center: horizontal == "center" ||
          horizontal == "centerContinuous" ||
          (horizontal == "general" && (cell.kind == 3 || cell.kind == 4)),
          visible: !(cell.kind == 1 && cell.number == 0.0 && !geo.show_zero),
          occupied: cell.kind != 0 && !(cell.kind == 2 && cell.text == ""),
          color: match formatted.color {
            Some(rgb) => (rgb << 8) | 255U
            None =>
              match color_cache.get(cell.style) {
                Some(cached) => cached
                None => {
                  let color = xlsx_plain_font_color(
                    styles,
                    cell.style,
                    theme_colors,
                  )
                  color_cache[cell.style] = color
                  color
                }
              }
          },
        })
      }
    }
    cells.push({ index: row.index, cells: entries, })
  }
  let draw_cells = if base_fills || base_borders {
    xlsx_plain_base_paint(
      rows, cells, geo, styles, theme_colors, spans, region_rows, fills, borders,
      border_colors, diagonals, border_colors_by_weight, row_count, col_count, base_borders,
    )
  } else {
    cells
  }
  let table_headers = workbook
    .read_sheet_tables(ref.part)
    .map(table => {
      (
        table.range.row_start.to_int(),
        table.range.row_end.to_int(),
        table.range.column_start,
        table.range.column_end,
        table.header_rows,
      )
    })
  let drawn = @sheet.draw_sized_grid_no_fonts(
    draw_cells,
    geometry,
    all_columns,
    locale.language,
    doc_language,
    verticals~,
    horizontals~,
    bolds~,
    fills~,
    sizes~,
    borders~,
    spans~,
    border_colors~,
    merge_regions~,
    east_asian_fonts~,
    wraps~,
    diagonals~,
    font_families~,
    italics~,
    decorations~,
    scripts~,
    shrink_scales~,
    indents~,
    center_across~,
    links~,
    auto_filter=match filter_range {
      Some(range) if range.row_start >= 0L &&
        range.row_start < row_count.to_int64() =>
        Some((range.row_start.to_int(), range.column_start, range.column_end))
      _ => None
    },
    notes~,
    rich_colors~,
    rich_base_sizes=run_base_sizes,
    table_headers~,
    table_filters~,
  ) catch {
    @sheet.InvalidArgument(message) => raise InvalidXlsxInput(message)
    error => raise error
  }
  (drawn, geo, parsed.missing_formula_values)
}

///|
fn xlsx_plain_base_paint(
  rows : Array[XlsxRow],
  cells : Array[@sheet.SizedGridRow],
  geo : XlsxSheetGeometry,
  styles : XlsxStyles,
  theme_colors : Map[Int32, XlsxRgb],
  spans : Map[Int32, Map[Int32, Int32]],
  region_rows : Map[Int32, Map[Int32, @sheet.GridMergeRegion]],
  fills : Map[Int32, Map[Int32, @sheet.GridSolidFill]],
  borders : Map[Int32, Map[Int32, @sheet.GridCellBorder]],
  border_colors : Map[Int32, Map[Int32, Array[UInt32]]],
  diagonals : Map[Int32, Map[Int32, @sheet.GridCellDiagonal]],
  border_colors_by_weight : Map[Int32, XlsxRgb],
  row_count : Int32,
  col_count : Int32,
  base_borders : Bool,
) -> Array[@sheet.SizedGridRow] raise {
  // Materializing missing formatted cells must stay bounded for huge views.
  if row_count.to_int64() * col_count.to_int64() > 1000000L {
    raise InvalidXlsxInput(
      "xlsx: row or column fill exceeds the supported view size",
    )
  }
  if base_borders && row_count.to_int64() * col_count.to_int64() > 200000L {
    raise InvalidXlsxInput(
      "xlsx: row or column border exceeds the supported view size",
    )
  }
  let column_base = Array::make(col_count, -1)
  let column_last = Array::make(col_count, -1)
  for column in geo.columns {
    let first = Int32::max(column.first, 0)
    let last = Int32::min(column.last, col_count - 1)
    if first <= last {
      for c in first..<=last {
        column_last[c] = column.style
        if column.style >= 0 {
          column_base[c] = column.style
        }
      }
    }
  }
  let by_row : Map[Int32, XlsxRow] = Map([])
  let drawn_by_row : Map[Int32, @sheet.SizedGridRow] = Map([])
  for row in rows {
    by_row[row.index] = row
  }
  for row in cells {
    drawn_by_row[row.index] = row
  }
  let result : Array[@sheet.SizedGridRow] = []
  let black : XlsxRgb = { red: 0.0, green: 0.0, blue: 0.0, }
  for r in 0..<row_count {
    let source = by_row.get(r)
    let explicit : Map[Int32, Bool] = Map([])
    let row_style = if source is Some(row) {
      for cell in row.cells {
        explicit[cell.column] = true
      }
      row.style
    } else {
      -1
    }
    for c in 0..<col_count {
      if explicit.contains(c) {
        continue
      }
      let region = xlsx_plain_region_at(spans, region_rows, r, c)
      let style = if row_style >= 0 {
        row_style
      } else if region is Some(_) {
        column_last[c]
      } else {
        column_base[c]
      }
      if style < 0 {
        continue
      }
      let index = if style >= styles.cell_formats.length() { 0 } else { style }
      if base_borders {
        xlsx_put_base_border(
          styles, index, theme_colors, r, c, region, borders, border_colors, diagonals,
          border_colors_by_weight,
        )
      }
      let fill_index = styles.cell_formats[index].fill
      if fill_index < 0 || fill_index >= styles.fills.length() {
        continue
      }
      let fill = styles.fills[fill_index]
      if fill.pattern != "solid" {
        continue
      }
      let columns = match fills.get(r) {
        Some(columns) => columns
        None => {
          let columns : Map[Int32, @sheet.GridSolidFill] = Map([])
          fills[r] = columns
          columns
        }
      }
      columns[c] = {
        key: xlsx_solid_fill_key(fill),
        color: styles.resolve_color(fill.foreground, black, theme_colors).rgba(),
      }
    }
    match drawn_by_row.get(r) {
      Some(row) => result.push(row)
      None =>
        if fills.contains(r) || borders.contains(r) || diagonals.contains(r) {
          result.push({ index: r, cells: [], })
        }
    }
  }
  result
}

///|
fn xlsx_put_base_border(
  styles : XlsxStyles,
  format : Int32,
  theme : Map[Int32, XlsxRgb],
  row : Int32,
  col : Int32,
  region : @sheet.GridMergeRegion?,
  borders : Map[Int32, Map[Int32, @sheet.GridCellBorder]],
  colors_by_row : Map[Int32, Map[Int32, Array[UInt32]]],
  diagonals : Map[Int32, Map[Int32, @sheet.GridCellDiagonal]],
  colors_by_weight : Map[Int32, XlsxRgb],
) -> Unit raise {
  let (border, colors) = xlsx_plain_border(styles, format, theme)
  let weights = [border.top, border.bottom, border.left, border.right]
  if weights.any(weight => weight != 0) {
    for i, weight in weights {
      if weight != 0 {
        xlsx_check_border_color(colors_by_weight, weight, colors[i])
      }
    }
    let columns = match borders.get(row) {
      Some(columns) => columns
      None => {
        let columns : Map[Int32, @sheet.GridCellBorder] = Map([])
        borders[row] = columns
        columns
      }
    }
    columns[col] = if region is Some(region) {
      {
        top: if row == region.row_start {
          border.top
        } else {
          0
        },
        bottom: if row == region.row_end {
          border.bottom
        } else {
          0
        },
        left: if col == region.column_start {
          border.left
        } else {
          0
        },
        right: if col == region.column_end {
          border.right
        } else {
          0
        },
      }
    } else {
      border
    }
    let row_colors = match colors_by_row.get(row) {
      Some(row_colors) => row_colors
      None => {
        let row_colors : Map[Int32, Array[UInt32]] = Map([])
        colors_by_row[row] = row_colors
        row_colors
      }
    }
    row_colors[col] = colors.map(color => color.rgba())
  }
  let id = styles.cell_formats[format].border
  if id >= 0 && id < styles.borders.length() {
    let source = styles.borders[id]
    if source.diagonal_up || source.diagonal_down {
      let (weight, color) = xlsx_plain_border_side(
        styles,
        source.diagonal,
        theme,
      )
      if weight != 0 {
        xlsx_check_border_color(colors_by_weight, weight, color)
        let columns = match diagonals.get(row) {
          Some(columns) => columns
          None => {
            let columns : Map[Int32, @sheet.GridCellDiagonal] = Map([])
            diagonals[row] = columns
            columns
          }
        }
        columns[col] = {
          weight,
          color: color.rgba(),
          up: source.diagonal_up,
          down: source.diagonal_down,
        }
      }
    }
  }
}

///|
fn xlsx_check_base_style(
  styles : XlsxStyles,
  style : Int32,
) -> (Bool, Bool) raise {
  let index = if style < 0 || style >= styles.cell_formats.length() {
    0
  } else {
    style
  }
  let format = styles.cell_formats[index]
  let mut solid = false
  if format.fill >= 0 && format.fill < styles.fills.length() {
    let fill = styles.fills[format.fill]
    if (fill.pattern != "" && fill.pattern != "solid") ||
      fill.gradient is Some(_) {
      raise InvalidXlsxInput(
        "xlsx: row or column styles with fills are not supported",
      )
    }
    solid = fill.pattern == "solid"
  }
  let mut has_border = false
  if format.border >= 0 && format.border < styles.borders.length() {
    let border = styles.borders[format.border]
    if border.vertical.style != "" || border.horizontal.style != "" {
      raise InvalidXlsxInput(
        "xlsx: row or column styles with complex borders are not supported",
      )
    }
    has_border = border.left.style != "" ||
      border.right.style != "" ||
      border.top.style != "" ||
      border.bottom.style != "" ||
      (
        border.diagonal.style != "" &&
        (border.diagonal_up || border.diagonal_down)
      )
  }
  (solid, has_border)
}

///|
fn xlsx_check_border_color(
  colors : Map[Int32, XlsxRgb],
  weight : Int32,
  color : XlsxRgb,
) -> Unit raise {
  if colors.get(weight) is Some(previous) {
    if (
        previous.red != color.red ||
        previous.green != color.green ||
        previous.blue != color.blue
      ) &&
      (!xlsx_plain_byte_color(previous) || !xlsx_plain_byte_color(color)) {
      raise InvalidXlsxInput(
        "xlsx: mixed border colors require 8-bit RGB components",
      )
    }
  } else {
    colors[weight] = color
  }
}

///|
fn xlsx_plain_byte_color(color : XlsxRgb) -> Bool {
  for value in [color.red, color.green, color.blue] {
    let scaled = value * 255.0
    if (scaled - scaled.round()).abs() > 1.0e-9 {
      return false
    }
  }
  true
}

///|
fn xlsx_plain_border(
  styles : XlsxStyles,
  format : Int32,
  theme : Map[Int32, XlsxRgb],
) -> (@sheet.GridCellBorder, Array[XlsxRgb]) raise {
  let id = styles.cell_formats[format].border
  if id < 0 || id >= styles.borders.length() {
    let black : XlsxRgb = { red: 0.0, green: 0.0, blue: 0.0, }
    return (
      { top: 0, bottom: 0, left: 0, right: 0, },
      [black, black, black, black],
    )
  }
  let border = styles.borders[id]
  let (top, top_color) = xlsx_plain_border_side(styles, border.top, theme)
  let (bottom, bottom_color) = xlsx_plain_border_side(
    styles,
    border.bottom,
    theme,
  )
  let (left, left_color) = xlsx_plain_border_side(styles, border.left, theme)
  let (right, right_color) = xlsx_plain_border_side(styles, border.right, theme)
  (
    { top, bottom, left, right, },
    [top_color, bottom_color, left_color, right_color],
  )
}

///|
fn xlsx_plain_border_side(
  styles : XlsxStyles,
  side : XlsxBorderSide,
  theme : Map[Int32, XlsxRgb],
) -> (Int32, XlsxRgb) raise {
  let weight = match side.style {
    "" => 0
    "hair" => 1
    "dotted" => 2
    "dashDotDot" => 3
    "dashDot" => 4
    "dashed" => 5
    "thin" => 6
    "mediumDashDotDot" => 7
    "slantDashDot" => 8
    "mediumDashDot" => 9
    "mediumDashed" => 10
    "medium" => 11
    "double" => 12
    "thick" => 13
    _ =>
      raise InvalidXlsxInput(
        "xlsx: plain conversion does not support this border style",
      )
  }
  let black : XlsxRgb = { red: 0.0, green: 0.0, blue: 0.0, }
  (weight, styles.resolve_color(side.color, black, theme))
}

///|
fn xlsx_plain_spans(
  ranges : Array[XlsxRange],
) -> (
  Map[Int32, Map[Int32, Int32]],
  Map[Int32, Map[Int32, @sheet.GridMergeRegion]],
  Array[@sheet.GridMergeRegion],
) raise {
  let spans : Map[Int32, Map[Int32, Int32]] = Map([])
  let region_rows : Map[Int32, Map[Int32, @sheet.GridMergeRegion]] = Map([])
  let regions : Array[@sheet.GridMergeRegion] = []
  let mut room = 4194304L
  for range in ranges {
    if range.row_start < 0L ||
      range.row_end >= 1048576L ||
      range.row_start > range.row_end ||
      range.column_start < 0 ||
      range.column_end >= 16384 ||
      range.column_start > range.column_end {
      raise InvalidXlsxInput("xlsx: merged cells are outside the sheet")
    }
    let length = (range.column_end - range.column_start + 1).to_int64() *
      (range.row_end - range.row_start + 1L)
    if length > room {
      raise InvalidXlsxInput("xlsx: too many merged cells for plain conversion")
    }
    room -= length
    let region : @sheet.GridMergeRegion = {
      row_start: range.row_start.to_int(),
      row_end: range.row_end.to_int(),
      column_start: range.column_start,
      column_end: range.column_end,
    }
    regions.push(region)
    for row in region.row_start..<=region.row_end {
      let columns = match spans.get(row) {
        Some(columns) => columns
        None => {
          let columns : Map[Int32, Int32] = Map([])
          spans[row] = columns
          columns
        }
      }
      for start, end in columns {
        if range.column_start <= end && range.column_end >= start {
          raise InvalidXlsxInput(
            "xlsx: plain conversion does not support overlapping merges",
          )
        }
      }
      columns[range.column_start] = range.column_end
      let row_regions = match region_rows.get(row) {
        Some(columns) => columns
        None => {
          let columns : Map[Int32, @sheet.GridMergeRegion] = Map([])
          region_rows[row] = columns
          columns
        }
      }
      row_regions[range.column_start] = region
    }
  }
  (spans, region_rows, regions)
}

///|
fn xlsx_plain_region_at(
  spans : Map[Int32, Map[Int32, Int32]],
  region_rows : Map[Int32, Map[Int32, @sheet.GridMergeRegion]],
  row : Int32,
  column : Int32,
) -> @sheet.GridMergeRegion? {
  if xlsx_plain_span_at(spans, row, column) is Some((start, _)) &&
    region_rows.get(row) is Some(columns) {
    return columns.get(start)
  }
  None
}

///|
fn xlsx_plain_span_at(
  spans : Map[Int32, Map[Int32, Int32]],
  row : Int32,
  column : Int32,
) -> (Int32, Int32)? {
  if spans.get(row) is Some(columns) {
    for start, end in columns {
      if column >= start && column <= end {
        return Some((start, end))
      }
    }
  }
  None
}

///|
fn xlsx_plain_center_end(
  cells : Map[Int32, Map[Int32, Bool]],
  row : Int32,
  start : Int32,
  count : Int32,
) -> Int32 {
  let mut last = start
  if cells.get(row) is Some(columns) {
    while last + 1 < count && columns.get(last + 1) == Some(true) {
      last += 1
    }
  }
  last
}

///|
fn xlsx_shown_segments(
  segments : Array[XlsxRunSegment],
  wrap : Bool,
) -> Array[XlsxRunSegment] {
  let result : Array[XlsxRunSegment] = []
  let mut shown = 0
  for segment in segments {
    if shown >= 1024 {
      break
    }
    let text = StringBuilder()
    for ch in segment.text {
      if ch == '\n' {
        shown += 1
        if wrap {
          text.write_char(ch)
        }
      } else if ch == '\t' || ch.to_int() >= 0x20 {
        shown += 1
        text.write_char(ch)
      }
      if shown >= 1024 {
        break
      }
    }
    let visible = text.to_string()
    if visible != "" {
      result.push({ ..segment, text: visible, })
    }
  }
  result
}

///|
fn xlsx_rich_base_sizes(
  rows : Array[XlsxRow],
  styles : XlsxStyles,
  rich_cells : Map[Int32, Map[Int32, XlsxPlainRun]],
) -> Map[Int32, Map[Int32, Double]] {
  let result : Map[Int32, Map[Int32, Double]] = Map([])
  for row in rows {
    for cell in row.cells {
      if rich_cells.get(row.index) is Some(columns) &&
        columns.get(cell.column) is Some(run) &&
        (run.font is Some(_) || !run.segments.is_empty()) {
        let index = if cell.style < 0 ||
          cell.style >= styles.cell_formats.length() {
          0
        } else {
          cell.style
        }
        let id = styles.cell_formats[index].font
        let id = if id < 0 || id >= styles.fonts.length() { 0 } else { id }
        let sizes = match result.get(row.index) {
          Some(sizes) => sizes
          None => {
            let sizes : Map[Int32, Double] = Map([])
            result[row.index] = sizes
            sizes
          }
        }
        sizes[cell.column] = styles.fonts[id].size
      }
    }
  }
  result
}

///|
fn xlsx_apply_plain_run_fonts(
  rows : Array[XlsxRow],
  styles : XlsxStyles,
  rich_cells : Map[Int32, Map[Int32, XlsxPlainRun]],
) -> Array[XlsxRow] {
  rows.map(row => {
    let cells = row.cells.map(cell => {
      let run = match rich_cells.get(row.index) {
        Some(columns) => columns.get(cell.column)
        None => None
      }
      match run {
        Some({ font: Some(font), .. }) => {
          let index = if cell.style < 0 ||
            cell.style >= styles.cell_formats.length() {
            0
          } else {
            cell.style
          }
          let format = styles.cell_formats[index]
          let font_index = if format.font < 0 ||
            format.font >= styles.fonts.length() {
            0
          } else {
            format.font
          }
          let base = styles.fonts[font_index]
          let next : XlsxFont = {
            ..base,
            name: if font.name != "" {
              font.name
            } else {
              base.name
            },
            size: if font.size > 0.0 {
              font.size
            } else {
              base.size
            },
            bold: font.bold,
            italic: font.italic,
            underline: font.underline,
            strike: font.strike,
            vertical: font.vertical,
            color: if font.color.kind != 0 {
              font.color
            } else {
              base.color
            },
            scheme: if font.name != "" {
              font.scheme
            } else {
              base.scheme
            },
          }
          let new_font = styles.fonts.length()
          styles.fonts.push(next)
          let new_style = styles.cell_formats.length()
          styles.cell_formats.push({ ..format, font: new_font, })
          { ..cell, style: new_style, }
        }
        Some({ segments, .. }) if !segments.is_empty() => {
          let index = if cell.style < 0 ||
            cell.style >= styles.cell_formats.length() {
            0
          } else {
            cell.style
          }
          let format = styles.cell_formats[index]
          let font_index = if format.font < 0 ||
            format.font >= styles.fonts.length() {
            0
          } else {
            format.font
          }
          let base = styles.fonts[font_index]
          let mut size = 0.0
          let mut uniform = true
          let mut max_size = 0.0
          let visible_segments = xlsx_shown_segments(
            segments,
            format.alignment.wrap,
          )
          for segment in visible_segments {
            if segment.text == "" {
              continue
            }
            let effective = match segment.font {
              Some(font) if font.size > 0.0 => font.size
              _ => base.size
            }
            max_size = Double::max(max_size, effective)
            if size == 0.0 {
              size = effective
            } else if size != effective {
              uniform = false
            }
          }
          let al = format.alignment
          let safe_varying = !uniform &&
            (
              al.horizontal == "general" ||
              al.horizontal == "left" ||
              al.horizontal == "right" ||
              al.horizontal == "center" ||
              al.horizontal == "centerContinuous"
            ) &&
            run is Some(_)

          let target_size = if uniform {
            size
          } else if safe_varying {
            max_size
          } else {
            0.0
          }
          if target_size > 0.0 && target_size != base.size {
            let new_font = styles.fonts.length()
            styles.fonts.push({ ..base, size: target_size, })
            let new_style = styles.cell_formats.length()
            styles.cell_formats.push({ ..format, font: new_font, })
            { ..cell, style: new_style, }
          } else {
            cell
          }
        }
        _ => cell
      }
    })
    { ..row, cells, }
  })
}

///|
fn xlsx_plain_run_format(text : String) -> XlsxFormatted {
  { pieces: [{ kind: 0, text, }], color: None, general: false, number: false, }
}

///|
fn xlsx_plain_format_cell(
  styles : XlsxStyles,
  cell : XlsxCell,
  row : Int32,
  rich_cells : Map[Int32, Map[Int32, XlsxPlainRun]],
  date1904 : Bool,
  locale : String,
) -> XlsxFormatted? {
  if cell.kind == 2 &&
    rich_cells.get(row) is Some(columns) &&
    columns.get(cell.column) is Some(text) {
    Some(xlsx_plain_run_format(text.text))
  } else {
    styles.format_cell(cell, date1904, locale)
  }
}

///|
fn xlsx_plain_fitted_rows(
  rows : Array[XlsxRow],
  styles : XlsxStyles,
  geometry : XlsxSheetGeometry,
  spans : Map[Int32, Map[Int32, Int32]],
  widths : Array[Double],
  date1904 : Bool,
  locale : String,
  default_size : Double,
  rich_cells : Map[Int32, Map[Int32, XlsxPlainRun]],
  layout_base_sizes : Map[Int32, Map[Int32, Double]],
) -> Map[Int32, Double] {
  let result : Map[Int32, Double] = Map([])
  for row in rows {
    if row.hidden || row.height >= 0.0 {
      continue
    }
    let mut best = 0.0
    for cell in row.cells {
      if cell.kind == 0 ||
        (cell.kind == 1 && cell.number == 0.0 && !geometry.show_zero) ||
        xlsx_plain_span_at(spans, row.index, cell.column) is Some(_) {
        continue
      }
      let format_index = if cell.style < 0 ||
        cell.style >= styles.cell_formats.length() {
        0
      } else {
        cell.style
      }
      let font_id = styles.cell_formats[format_index].font
      let font_index = if font_id < 0 || font_id >= styles.fonts.length() {
        0
      } else {
        font_id
      }
      let size = styles.fonts[font_index].size
      let indent = xlsx_plain_indent(
        styles.cell_formats[format_index].alignment,
        cell.kind,
      )
      if styles.cell_formats[format_index].alignment.wrap {
        if xlsx_plain_format_cell(
            styles,
            cell,
            row.index,
            rich_cells,
            date1904,
            locale,
          )
          is Some(formatted) {
          let text = xlsx_plain_wrap_text(formatted.text())
          let width = if cell.column >= 0 && cell.column < widths.length() {
            Double::max(widths[cell.column] - 3.75 - indent, 0.0)
          } else {
            0.0
          }
          let bold = styles.fonts[font_index].bold
          let drawn_size = if styles.fonts[font_index].vertical == "" ||
            (
              rich_cells.get(row.index) is Some(cols) &&
              cols.get(cell.column) is Some(r) &&
              !r.segments.is_empty()
            ) {
            size
          } else {
            size * (2.0 / 3.0)
          }
          let advance = (c : Char, b : Bool) => {
            @sheet.sized_fallback_advance(c, b, drawn_size)
          }
          let rich_measure : Array[@sheet.RichMeasureRun] = []
          let mut varying = false
          if rich_cells.get(row.index) is Some(columns) &&
            columns.get(cell.column) is Some(run) &&
            !run.segments.is_empty() {
            let base_size = match layout_base_sizes.get(row.index) {
              Some(values) => values.get(cell.column).unwrap_or(size)
              None => size
            }
            let mut first = 0.0
            for segment in run.segments {
              if segment.text == "" {
                continue
              }
              let actual = match segment.font {
                Some(font) if font.size > 0.0 => font.size
                _ => base_size
              }
              if first == 0.0 {
                first = actual
              } else if first != actual {
                varying = true
              }
              let vertical = match segment.font {
                Some(f) => f.vertical
                None => styles.fonts[font_index].vertical
              }
              if vertical != "" {
                varying = true
              }
              rich_measure.push({ text: segment.text, size: actual, vertical, })
            }
          }
          let mut text_height = 0.0
          if varying {
            let base_size = match layout_base_sizes.get(row.index) {
              Some(values) => values.get(cell.column).unwrap_or(size)
              None => size
            }
            for line in @sheet.wrap_rich_text(rich_measure, width, base_size) {
              text_height += 0.9 * line.size + 0.25 * line.size
            }
          } else {
            let lines = @sheet.wrap_text(text, width, bold~, advance~)
            for _ in lines {
              text_height += 0.9 * size + 0.25 * size
            }
          }
          text_height = text_height + 1.5 - 1.5
          best = Double::max(best, text_height)
        }
      } else if (0.9 + 0.25) * size > (0.9 + 0.25) * default_size + 0.01 {
        let mut actual_size = size
        if styles.cell_formats[format_index].alignment.shrink && cell.kind != 1 {
          if xlsx_plain_format_cell(
              styles,
              cell,
              row.index,
              rich_cells,
              date1904,
              locale,
            )
            is Some(formatted) {
            let width = if cell.column >= 0 && cell.column < widths.length() {
              Double::max(widths[cell.column] - 3.75 - indent, 0.0)
            } else {
              0.0
            }
            let drawn_size = if styles.fonts[font_index].vertical == "" {
              size
            } else {
              size * (2.0 / 3.0)
            }
            let scale = if rich_cells.get(row.index) is Some(columns) &&
              columns.get(cell.column) is Some(run) &&
              !run.segments.is_empty() {
              let base_size = match layout_base_sizes.get(row.index) {
                Some(sizes) => sizes.get(cell.column).unwrap_or(drawn_size)
                None => drawn_size
              }
              xlsx_rich_shrink_scale(
                run.segments,
                base_size,
                styles.fonts[font_index].vertical,
                width,
              )
            } else {
              xlsx_plain_shrink_scale(formatted.text(), width, drawn_size)
            }
            let fallback = match layout_base_sizes.get(row.index) {
              Some(values) => values.get(cell.column).unwrap_or(size)
              None => size
            }
            actual_size = if scale == 0.0 { fallback } else { size * scale }
          }
        }
        let text_height = 0.9 * actual_size + 0.25 * actual_size + 1.5 - 1.5
        best = Double::max(best, text_height)
      }
    }
    if best > 0.0 {
      result[row.index] = ((best / 0.75 - 0.05).ceil() + 2.0) * 0.75
    }
  }
  result
}

///|
fn xlsx_plain_indent(alignment : XlsxAlignment, kind : Int32) -> Double {
  let horizontal = alignment.horizontal
  if alignment.indent > 0 &&
    (
      horizontal == "left" ||
      horizontal == "right" ||
      (horizontal == "general" && (kind == 1 || kind == 2))
    ) {
    alignment.indent.to_double() * 7.5
  } else {
    0.0
  }
}

///|
fn xlsx_rich_shrink_scale(
  segments : Array[XlsxRunSegment],
  base_size : Double,
  base_vertical : String,
  available : Double,
) -> Double {
  let mut width = 0.0
  for segment in xlsx_shown_segments(segments, false) {
    let size = match segment.font {
      Some(font) if font.size > 0.0 => font.size
      _ => base_size
    }
    let vertical = match segment.font {
      Some(f) => f.vertical
      None => base_vertical
    }
    let measure_size = if vertical != "" { size * (2.0 / 3.0) } else { size }
    for ch in segment.text {
      let character = if ch == '\t' { ' ' } else { ch }
      width += @sheet.sized_fallback_advance(character, false, measure_size)
    }
  }
  if width > available + 0.01 && width > 0.0 {
    available / width
  } else {
    1.0
  }
}

///|
fn xlsx_plain_shrink_scale(
  text : String,
  available : Double,
  size : Double,
) -> Double {
  let mut width = 0.0
  let mut shown = 0
  for c in text {
    if c == '\n' {
      shown += 1
    } else {
      let ch = if c == '\t' { ' ' } else { c }
      if ch.to_int() < 0x20 {
        continue
      }
      width += @sheet.sized_fallback_advance(ch, false, size)
      shown += 1
    }
    if shown >= 1024 {
      break
    }
  }
  if width > available + 0.01 && width > 0.0 {
    available / width
  } else {
    1.0
  }
}

///|
fn xlsx_plain_wrap_text(text : String) -> String {
  let output = StringBuilder()
  let mut shown = 0
  for c in text {
    let ch = if c == '\t' { ' ' } else { c }
    if ch == '\n' || ch.to_int() >= 0x20 {
      output.write_char(ch)
      shown += 1
      if shown >= 1024 {
        break
      }
    }
  }
  output.to_string()
}

///|
fn xlsx_solid_fill_key(fill : XlsxFill) -> String {
  let fg = fill.foreground
  let bg = fill.background
  fg.kind.to_string() +
  ":" +
  fg.rgb.to_string() +
  ":" +
  fg.index.to_string() +
  ":" +
  fg.tint.to_string() +
  ":" +
  bg.kind.to_string() +
  ":" +
  bg.rgb.to_string() +
  ":" +
  bg.index.to_string() +
  ":" +
  bg.tint.to_string()
}

///|
fn xlsx_fit_plain_number(
  value : Double,
  available : Double,
  size : Double,
) -> String {
  for n = 10; n >= 1; n = n - 1 {
    let candidate = xlsx_format_general(value, n)
    if candidate == "" {
      continue
    }
    let mut width = 0.0
    for c in candidate {
      width += @sheet.sized_fallback_advance(c, false, size)
    }
    if width <= available + 0.01 {
      return candidate
    }
  }
  let n = (available /
  Double::max(@sheet.sized_fallback_advance('#', false, size), 0.01)).to_int()
  "#".repeat(n)
}

///|
fn xlsx_plain_font_color(
  styles : XlsxStyles,
  style : Int32,
  theme : Map[Int32, XlsxRgb],
) -> UInt32 raise {
  let index = if style < 0 || style >= styles.cell_formats.length() {
    0
  } else {
    style
  }
  let raw_font = styles.cell_formats[index].font
  let font_index = if raw_font < 0 || raw_font >= styles.fonts.length() {
    0
  } else {
    raw_font
  }
  let black : XlsxRgb = { red: 0.0, green: 0.0, blue: 0.0, }
  let color = styles.fonts[font_index].color
  if color.kind == 2 &&
    color.index >= 0 &&
    color.index < 12 &&
    !theme.contains(color.index) {
    raise InvalidXlsxInput(
      "xlsx: plain conversion does not support this theme color",
    )
  }
  styles.resolve_color(color, black, theme).rgba()
}
