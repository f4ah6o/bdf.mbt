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
  strict~ : Bool = false,
) -> @pptx.PptxResult raise {
  let values = form_values(data)
  let (filled, warnings) = @ooxml.fill_zip(template, values, strict~) catch {
    @ooxml.OoxmlError(message) => raise PptxFormError(message)
  }
  let result = @pptx.convert(filled, title~, pages~)
  for warning in warnings {
    result.warnings.push(warning)
  }
  result
}

///|
/// Fill a PowerPoint presentation and return the filled .pptx.
pub fn fill_bytes(
  template : Bytes,
  data : Bytes,
  strict~ : Bool = false,
) -> Bytes raise {
  let values = form_values(data)
  let (filled, _) = @ooxml.fill_zip(template, values, strict~) catch {
    @ooxml.OoxmlError(message) => raise PptxFormError(message)
  }
  filled
}
