///|
// The fields of the tags of a workbook, read from its cells: the names
// that data for the template has, and where each tag is ("Sheet1!B5").

///|
fn xlsx_inspect_put(
  out : Array[@tag.Field],
  index : Map[String, Int],
  field : @tag.Field,
) -> Unit {
  let key = field.kind +
    "\u{0}" +
    field.in_sections.join("\u{0}") +
    "\u{0}" +
    field.name
  match index.get(key) {
    Some(i) => {
      let old = out[i]
      if old.format == "" {
        old.format = field.format
      }
      if old.mode == "" {
        old.mode = field.mode
      }
      if old.code == "" {
        old.code = field.code
      }
      if old.input == "" {
        old.input = field.input
      }
      old.inverted = old.inverted || field.inverted
      for at in field.at {
        if old.at.length() < 16 && !old.at.contains(at) {
          old.at.push(at)
        }
      }
    }
    None => {
      index[key] = out.length()
      out.push(field)
    }
  }
}

///|
/// The fields of the tags of the cells of a workbook, in the order of the
/// cells, with the cell each tag is in ("Sheet1!B5"). A section may open
/// in one cell and close in another, as the fill reads it.
pub fn inspect(data : Bytes) -> Array[@tag.Field] raise XlsxFormError {
  let workbook = @xlsx.read_xlsx_workbook(data) catch {
    _ => raise XlsxFormError("form/xlsx: the workbook cannot be read")
  }
  let out : Array[@tag.Field] = []
  let index : Map[String, Int] = Map([])
  for sheet in workbook.sheets {
    if sheet.chart {
      continue
    }
    let cells = workbook.read_sheet_cells(sheet.part) catch {
      _ => continue
    }
    let tokens : Array[@tag.TagToken] = []
    let ats : Array[String] = []
    for row in cells.rows {
      for cell in row.cells {
        if cell.text == "" {
          continue
        }
        let at = sheet.name +
          "!" +
          @xlsx.xlsx_col_name(cell.column) +
          (row.index + 1).to_string()
        let parsed = @tag.parse(cell.text) catch {
          @tag.TagError(message, _) =>
            raise XlsxFormError("form/xlsx: " + at + ": " + message)
        }
        for token in parsed {
          tokens.push(token)
          ats.push(at)
        }
      }
    }
    let fields = @tag.fields_at(tokens, ats) catch {
      @tag.TagError(message, _) =>
        raise XlsxFormError("form/xlsx: sheet " + sheet.name + ": " + message)
    }
    for field in fields {
      xlsx_inspect_put(out, index, field)
    }
  }
  out
}
