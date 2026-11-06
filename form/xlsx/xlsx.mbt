///|
pub suberror XlsxFormError {
  XlsxFormError(String)
}

///|
fn form_values(data : Bytes) -> Json raise XlsxFormError {
  @json.parse(@utf8.decode_lossy(data[:])) catch {
    _ => raise XlsxFormError("form/xlsx: the data is not JSON")
  }
}

///|
/// Fill {{name}} tags in a workbook and convert it to BDF.
pub fn fill(
  template : Bytes,
  data : Bytes,
  data_mode~ : String = "",
  no_text_index~ : Bool = false,
) -> @xlsx.XlsxPlainResult raise {
  let values = form_values(data)
  let (filled, _) = @ooxml.fill_zip(template, values) catch {
    @ooxml.OoxmlError(message) => raise XlsxFormError(message)
  }
  @xlsx.convert_plain_no_fonts(filled, data_mode~, no_text_index~)
}

///|
/// Fill a workbook and return the filled .xlsx.
pub fn fill_bytes(template : Bytes, data : Bytes) -> Bytes raise {
  let values = form_values(data)
  let (filled, _) = @ooxml.fill_zip(template, values) catch {
    @ooxml.OoxmlError(message) => raise XlsxFormError(message)
  }
  filled
}
