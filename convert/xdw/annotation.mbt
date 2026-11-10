///|
/// Whether an object is an annotation rather than page content.
///
/// The page content is the body. A page form is part of the page too, so it
/// stays in the body; everything else placed on the page is an annotation,
/// which a viewer can show or hide as a layer of its own.
fn xdw_is_annotation(kind : Int64) -> Bool {
  kind != K_CONTENT && kind != K_PAGEFORM
}

///|
/// The searchable form of an annotation's stored text.
///
/// A stored text may hold line breaks and runs of spaces. The index keeps one
/// run per drawn line, so a stored text becomes one run with single spaces: a
/// phrase that spans a line stays searchable.
fn xdw_annotation_text(text : String) -> String {
  let out = StringBuilder::new()
  let mut space = false
  let mut wrote = false
  for ch in text {
    if ch == '\r' || ch == '\n' || ch == '\t' || ch == ' ' || ch == '\u{3000}' {
      space = true
      continue
    }
    if space && wrote {
      out.write_char(' ')
    }
    space = false
    wrote = true
    out.write_char(ch)
  }
  out.to_string()
}

///|
/// The text an annotation object's own drawing carries, or `""` when it draws
/// none.
///
/// The drawing is built a second time into a throwaway document. Only the
/// drawing can say whether the text is already there: a text annotation draws
/// its text, while a sticky note may draw only the note and keep the text in
/// its child text object.
fn XdwDocument::xdw_annotation_drawn_text(
  self : XdwDocument,
  obj : XdwObject,
) -> String raise {
  let object = @core.ObjectBuilder::new()
  let writer = @core.DocumentWriter::new()
  let ignored : Array[String] = []
  self.xdw_draw_object(obj, object, writer, ignored)
  let encoded = object.encode()
  let resources = @core.decode_object_resources(encoded)
  let content = @render.extract_text(resources, xdw_no_external_object)
  @render.join_text(content.runs)
}
