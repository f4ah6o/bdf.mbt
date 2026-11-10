///|
/// The fields of the tags of a Word document, with the part each tag is
/// in. The tags are read as the fill reads them: a tag that markup splits
/// is one tag.
pub fn inspect(data : Bytes) -> Array[@tag.Field] raise DocxFormError {
  @ooxml.inspect_zip(data) catch {
    @ooxml.OoxmlError(message) => raise DocxFormError(message)
  }
}
