///|
pub suberror DocxFormError {
  DocxFormError(String)
}

///|
/// Fill {{name}} tags in a Word document and convert it to BDF. Tags split
/// by markup and control tags are reported, not filled. `pages` selects
/// 1-based pages of the page view, as `1-3,5,8-`.
pub fn fill(
  template : Bytes,
  data : Bytes,
  title~ : String = "",
  views~ : String = "both",
  pages~ : String = "",
  strict~ : Bool = false,
) -> @docx.DocxResult raise {
  let values = @json.parse(@utf8.decode_lossy(data[:])) catch {
    _ => raise DocxFormError("form/docx: the data is not JSON")
  }
  let (filled, warnings) = @ooxml.fill_zip(template, values, strict~) catch {
    @ooxml.OoxmlError(message) => raise DocxFormError(message)
  }
  let result = @docx.convert(filled, title~, views~, pages~)
  for warning in warnings {
    result.warnings.push(warning)
  }
  result
}

///|
/// Fill a Word document and return the filled .docx.
pub fn fill_bytes(
  template : Bytes,
  data : Bytes,
  strict~ : Bool = false,
) -> Bytes raise {
  let values = @json.parse(@utf8.decode_lossy(data[:])) catch {
    _ => raise DocxFormError("form/docx: the data is not JSON")
  }
  let (filled, _) = @ooxml.fill_zip(template, values, strict~) catch {
    @ooxml.OoxmlError(message) => raise DocxFormError(message)
  }
  filled
}
