///|
/// Detect an OOXML workbook by its ZIP signature and workbook part.
pub fn detect_xlsx(head : Bytes, data : Bytes) -> Bool {
  if !head.has_prefix(b"PK\x03\x04") {
    return false
  }
  let package = @ooxml.open_ooxml(data) catch { _ => return false }
  package.has("xl/workbook.xml")
}
