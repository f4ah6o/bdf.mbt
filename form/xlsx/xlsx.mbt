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
  strict~ : Bool = false,
) -> @xlsx.XlsxPlainResult raise {
  let values = form_values(data)
  let (filled, warnings) = @ooxml.fill_zip(template, values, strict~) catch {
    @ooxml.OoxmlError(message) => raise XlsxFormError(message)
  }
  let result = @xlsx.convert_plain_no_fonts(filled, data_mode~, no_text_index~)
  for warning in warnings {
    result.warnings.push(warning)
  }
  result
}

///|
/// Fill a workbook and return the filled .xlsx.
pub fn fill_bytes(
  template : Bytes,
  data : Bytes,
  strict~ : Bool = false,
) -> Bytes raise {
  let values = form_values(data)
  let (filled, _) = @ooxml.fill_zip(template, values, strict~) catch {
    @ooxml.OoxmlError(message) => raise XlsxFormError(message)
  }
  filled
}
