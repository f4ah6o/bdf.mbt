///|
pub suberror DocxFormError {
  DocxFormError(String)
}

///|
/// Fill {{name}} tags in a Word document and convert it to BDF. Tags split
/// by markup and control tags are reported, not filled.
pub fn fill(
  template : Bytes,
  data : Bytes,
  title~ : String = "",
  views~ : String = "both",
) -> @docx.DocxResult raise {
  let values = @json.parse(@utf8.decode_lossy(data[:])) catch {
    _ => raise DocxFormError("form/docx: the data is not JSON")
  }
  let (filled, warnings) = @ooxml.fill_zip(template, values) catch {
    @ooxml.OoxmlError(message) => raise DocxFormError(message)
  }
  let result = @docx.convert(filled, title~, views~)
  for warning in warnings {
    result.warnings.push(warning)
  }
  result
}

///|
/// Fill a Word document and return the filled .docx.
pub fn fill_bytes(template : Bytes, data : Bytes) -> Bytes raise {
  let values = @json.parse(@utf8.decode_lossy(data[:])) catch {
    _ => raise DocxFormError("form/docx: the data is not JSON")
  }
  let (filled, _) = @ooxml.fill_zip(template, values) catch {
    @ooxml.OoxmlError(message) => raise DocxFormError(message)
  }
  filled
}
