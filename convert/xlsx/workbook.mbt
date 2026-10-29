///|
/// A worksheet or chart sheet in workbook order.
pub(all) struct XlsxSheetRef {
  name : String
  part : String
  chart : Bool
  hidden : Bool
  index : Int32
}

///|
/// Basic workbook properties and resolved sheet references.
pub(all) struct XlsxWorkbook {
  package : @ooxml.OoxmlPackage
  part : String
  date1904 : Bool
  sheets : Array[XlsxSheetRef]
  warnings : Array[String]
}

///|
pub suberror XlsxInputError {
  InvalidXlsxInput(String)
}

///|
fn xlsx_attr(
  element : @xml.NamespaceElement,
  name : String,
  default : String,
) -> String {
  for attr in element.attributes {
    if attr.name.local_name == name &&
      !attr.name.namespace_uri.unwrap_or("").has_suffix("relationships") {
      return attr.value
    }
  }
  default
}

///|
fn xlsx_rel_id(element : @xml.NamespaceElement, name : String) -> String {
  for attr in element.attributes {
    if attr.name.local_name == name &&
      attr.name.namespace_uri.unwrap_or("").has_suffix("relationships") {
      return attr.value
    }
  }
  ""
}

///|
fn xlsx_trim(value : String) -> String {
  let out = StringBuilder()
  let pending = StringBuilder()
  let mut started = false
  for c in value {
    if c.is_whitespace() {
      if started {
        pending.write_char(c)
      }
    } else {
      if started {
        out.write_string(pending.to_string())
        pending.reset()
      }
      out.write_char(c)
      started = true
    }
  }
  out.to_string()
}

///|
/// Read the workbook part, date system and worksheet/chart references.
pub fn read_xlsx_workbook(data : Bytes) -> XlsxWorkbook raise XlsxInputError {
  let pkg = @ooxml.open_ooxml(data) catch {
    @ooxml.InvalidOoxml(message) => raise InvalidXlsxInput("xlsx: " + message)
  }
  let part = match pkg.relationship_of_type("", "/officeDocument") {
    Some(rel) => rel.target
    None => "xl/workbook.xml"
  }
  let bytes = pkg.read(part) catch {
    @ooxml.InvalidOoxml(message) => raise InvalidXlsxInput("xlsx: " + message)
  }
  let reader = @xml.NamespaceReader::from_string(
    @utf8.decode_lossy(bytes[:], ignore_bom=true),
  )
  let sheets : Array[XlsxSheetRef] = []
  let warnings : Array[String] = []
  let seen : Map[String, Bool] = Map([])
  let mut date1904 = false
  let mut seen_properties = false
  let mut depth = 0
  let mut sheet_depth = -1
  let mut sheet_index = 0
  let mut saw_sheets = false
  let mut saw_root = false
  while true {
    let event = reader.read_event() catch {
      _ => raise InvalidXlsxInput("xlsx: invalid workbook XML")
    }
    match event.kind {
      Start(element) | Empty(element) => {
        if depth == 0 {
          saw_root = true
        }
        if depth == 1 &&
          element.name.local_name == "workbookPr" &&
          !seen_properties {
          seen_properties = true
          date1904 = ["1", "true", "on"].contains(
            xlsx_trim(xlsx_attr(element, "date1904", "")),
          )
        } else if depth == 1 &&
          element.name.local_name == "sheets" &&
          !saw_sheets {
          saw_sheets = true
          if event.kind is Start(_) {
            sheet_depth = depth + 1
          }
        } else if depth == sheet_depth && element.name.local_name == "sheet" {
          let index = sheet_index
          sheet_index += 1
          let id = xlsx_rel_id(element, "id")
          match pkg.target(part, id) {
            None => ()
            Some(rel) => {
              let name = xlsx_attr(element, "name", "")
              let state = xlsx_attr(element, "state", "visible")
              if rel.kind.has_suffix("/worksheet") ||
                rel.kind.has_suffix("/chartsheet") {
                sheets.push({
                  name,
                  part: rel.target,
                  chart: rel.kind.has_suffix("/chartsheet"),
                  hidden: state != "visible",
                  index,
                })
              } else if !seen.contains(rel.kind) {
                seen[rel.kind] = true
                let mut type_name = ""
                for value in rel.kind.split("/") {
                  type_name = value.to_owned()
                }
                warnings.push(
                  "sheet " +
                  Json::string(name).stringify() +
                  ": " +
                  type_name +
                  " sheets are not supported",
                )
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
        if depth + 1 == sheet_depth {
          sheet_depth = -1
        }
        if depth == 0 {
          break
        }
      }
      Eof =>
        if !saw_root {
          raise InvalidXlsxInput("xlsx: unexpected EOF")
        } else {
          break
        }
      _ => ()
    }
  }
  { package: pkg, part, date1904, sheets, warnings, }
}
