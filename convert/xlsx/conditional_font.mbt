///|
priv struct XlsxConditionalFont {
  mut bold : Bool?
  mut italic : Bool?
  mut strike : Bool?
  mut underline : String?
  mut color : XlsxColor?
  mut fill : XlsxFill?
}

///|
fn XlsxWorkbook::xlsx_conditional_font(
  self : XlsxWorkbook,
  wanted : Int32,
) -> XlsxConditionalFont raise {
  let part = match self.package.relationship_of_type(self.part, "/styles") {
    Some(rel) => rel.target
    None =>
      raise InvalidXlsxInput(
        "xlsx: plain conversion does not support conditional formatting",
      )
  }
  let bytes = self.package.read(part) catch {
    _ =>
      raise InvalidXlsxInput(
        "xlsx: plain conversion does not support conditional formatting",
      )
  }
  let text = @utf8.decode_lossy(bytes[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    raise InvalidXlsxInput("xlsx: the part declares entities")
  }
  let reader = @xml.NamespaceReader::from_string(text)
  let result : XlsxConditionalFont = {
    bold: None,
    italic: None,
    strike: None,
    underline: None,
    color: None,
    fill: None,
  }
  let mut depth = 0
  let mut dxfs_depth = -1
  let mut dxf_depth = -1
  let mut font_depth = -1
  let mut index = 0
  let mut found_font = false
  let mut found_fill = false
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        if depth == 1 && name == "dxfs" && event.kind is Start(_) {
          dxfs_depth = depth + 1
        } else if depth == dxfs_depth && name == "dxf" {
          if index == wanted {
            if event.kind is Empty(_) {
              xlsx_reject_conditional()
            }
            dxf_depth = depth + 1
          }
          index += 1
        } else if depth == dxf_depth {
          if name == "font" {
            if found_font {
              xlsx_reject_conditional()
            }
            found_font = true
            if event.kind is Start(_) {
              font_depth = depth + 1
            }
          } else if name == "fill" {
            if found_fill {
              xlsx_reject_conditional()
            }
            found_fill = true
            let fill = xlsx_read_fill(reader, event.kind is Empty(_))
            if fill.gradient is Some(_) {
              xlsx_reject_conditional()
            }
            if fill.pattern == "" &&
              (fill.foreground.kind != 0 || fill.background.kind != 0) {
              fill.pattern = "solid"
            }
            if fill.pattern == "solid" && fill.background.kind != 0 {
              fill.foreground = fill.background
            }
            if fill.pattern != "" && fill.pattern != "solid" {
              xlsx_reject_conditional()
            }
            result.fill = if fill.pattern == "" { None } else { Some(fill) }
            continue
          } else {
            xlsx_reject_conditional()
          }
        } else if depth == font_depth {
          if event.kind is Start(_) {
            xlsx_reject_conditional()
          }
          match name {
            "b" => result.bold = Some(xlsx_bool_or(element, "val", true))
            "i" => result.italic = Some(xlsx_bool_or(element, "val", true))
            "strike" => result.strike = Some(xlsx_bool_or(element, "val", true))
            "u" => {
              let value = xlsx_attr(element, "val", "single")
              if value != "single" && value != "double" && value != "none" {
                xlsx_reject_conditional()
              }
              result.underline = Some(if value == "none" { "" } else { value })
            }
            "color" => {
              let color = xlsx_color(element)
              result.color = if color.kind != 0 { Some(color) } else { None }
            }
            _ => xlsx_reject_conditional()
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
        if depth + 1 == font_depth {
          font_depth = -1
        }
        if depth + 1 == dxf_depth {
          if !found_font && !found_fill {
            xlsx_reject_conditional()
          }
          return result
        }
        if depth + 1 == dxfs_depth {
          dxfs_depth = -1
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
  raise InvalidXlsxInput(
    "xlsx: plain conversion does not support conditional formatting",
  )
}

///|
// Invalid source style indices mean style zero even after synthetic formats are
// appended for conditional fonts.
fn xlsx_normalize_conditional_styles(
  rows : Array[XlsxRow],
  format_count : Int32,
) -> Array[XlsxRow] {
  rows.map(row => {
    let cells = row.cells.map(cell => {
      if cell.style < 0 || cell.style >= format_count {
        { ..cell, style: 0, }
      } else {
        cell
      }
    })
    { ..row, cells, }
  })
}

///|
fn xlsx_apply_conditional_font(
  rows : Array[XlsxRow],
  styles : XlsxStyles,
  matched : Map[Int32, Map[Int32, Bool]],
  diff : XlsxConditionalFont,
) -> Array[XlsxRow] {
  let new_formats : Map[Int32, Int32] = Map([])
  let conditional_fill = match diff.fill {
    Some(fill) => {
      let index = styles.fills.length()
      styles.fills.push(fill)
      Some(index)
    }
    None => None
  }
  let result : Array[XlsxRow] = []
  for row in rows {
    let columns = matched.get(row.index).unwrap_or(Map([]))
    let cells : Array[XlsxCell] = []
    for cell in row.cells {
      if !columns.contains(cell.column) {
        cells.push(cell)
        continue
      }
      let old_index = if cell.style < 0 ||
        cell.style >= styles.cell_formats.length() {
        0
      } else {
        cell.style
      }
      let new_index = match new_formats.get(old_index) {
        Some(index) => index
        None => {
          let format = styles.cell_formats[old_index]
          let font_index = if format.font < 0 ||
            format.font >= styles.fonts.length() {
            0
          } else {
            format.font
          }
          let old = styles.fonts[font_index]
          let font : XlsxFont = {
            name: old.name,
            size: old.size,
            bold: diff.bold.unwrap_or(old.bold),
            italic: diff.italic.unwrap_or(old.italic),
            underline: diff.underline.unwrap_or(old.underline),
            strike: diff.strike.unwrap_or(old.strike),
            color: diff.color.unwrap_or(old.color),
            vertical: old.vertical,
            scheme: old.scheme,
            family: old.family,
          }
          let new_font = styles.fonts.length()
          styles.fonts.push(font)
          let index = styles.cell_formats.length()
          styles.cell_formats.push({
            ..format,
            font: new_font,
            fill: conditional_fill.unwrap_or(format.fill),
          })
          new_formats[old_index] = index
          index
        }
      }
      cells.push({ ..cell, style: new_index, })
    }
    result.push({ ..row, cells, })
  }
  result
}
