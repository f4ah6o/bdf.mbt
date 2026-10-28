///|
/// Load a view's BTXT part when present, otherwise rebuild a paginated index.
pub fn page_text_index(
  view : @core.View,
  read_part : (String) -> Bytes raise,
  resolve : (String) -> @core.ObjectResources? raise,
) -> Array[@core.IndexRun] raise {
  match view.text_index {
    Some(hash) => @core.decode_text_index(read_part(hash))
    None => build_page_text_index(view, resolve)
  }
}

///|
/// Extract an index from a paginated view when the document has no BTXT part.
/// Each layer starts a new paragraph, as in the upstream BDF reader.
pub fn build_page_text_index(
  view : @core.View,
  resolve : (String) -> @core.ObjectResources? raise,
) -> Array[@core.IndexRun] raise {
  if view.kind == "sheet" {
    raise InvalidOperands("sheet text index requires tiles")
  }
  let index : Array[@core.IndexRun] = []
  for a, page in view.pages {
    for b, layer in page.layers {
      let object = match resolve(layer.object) {
        Some(object) => object
        None => raise InvalidOperands("text index object missing")
      }
      let content = extract_text(object, resolve)
      for i, run in content.runs {
        index.push({
          a,
          b,
          ordinal: run.ordinal,
          separator: if i == 0 {
            2
          } else {
            run.separator
          },
          text: run.text,
        })
      }
    }
  }
  index
}
