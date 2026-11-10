///|
/// The fields of the tags of a PowerPoint presentation, with the part each
/// tag is in. The tags are read as the fill reads them: a tag that markup
/// splits is one tag.
pub fn inspect(data : Bytes) -> Array[@tag.Field] raise PptxFormError {
  @ooxml.inspect_zip(data) catch {
    @ooxml.OoxmlError(message) => raise PptxFormError(message)
  }
}
