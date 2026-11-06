///|
pub suberror PptxFormError {
  PptxFormError(String)
}

///|
fn form_values(data : Bytes) -> Json raise PptxFormError {
  @json.parse(@utf8.decode_lossy(data[:])) catch {
    _ => raise PptxFormError("form/pptx: the data is not JSON")
  }
}

///|
/// Fill {{name}} tags in a PowerPoint presentation and convert it to BDF.
pub fn fill(
  template : Bytes,
  data : Bytes,
  title~ : String = "",
  pages~ : String = "",
) -> @pptx.PptxResult raise {
  let values = form_values(data)
  let (filled, _) = @ooxml.fill_zip(template, values) catch {
    @ooxml.OoxmlError(message) => raise PptxFormError(message)
  }
  @pptx.convert(filled, title~, pages~)
}

///|
/// Fill a PowerPoint presentation and return the filled .pptx.
pub fn fill_bytes(template : Bytes, data : Bytes) -> Bytes raise {
  let values = form_values(data)
  let (filled, _) = @ooxml.fill_zip(template, values) catch {
    @ooxml.OoxmlError(message) => raise PptxFormError(message)
  }
  filled
}
