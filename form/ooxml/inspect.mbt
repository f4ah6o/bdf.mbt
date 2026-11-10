///|
// The fields of the tags of an OOXML package, read as the fill reads them
// (form/ooxml of upstream): a tag split by markup is one tag, and a
// control tag opens or closes a section.

///|
fn inspect_put(
  out : Array[@tag.Field],
  index : Map[String, Int],
  field : @tag.Field,
  at : String,
) -> Unit {
  let key = field.kind +
    "\u{0}" +
    field.in_sections.join("\u{0}") +
    "\u{0}" +
    field.name
  match index.get(key) {
    Some(i) => {
      let old = out[i]
      if old.format == "" {
        old.format = field.format
      }
      if old.mode == "" {
        old.mode = field.mode
      }
      if old.code == "" {
        old.code = field.code
      }
      if old.input == "" {
        old.input = field.input
      }
      old.inverted = old.inverted || field.inverted
      if old.at.length() < 16 && !old.at.contains(at) {
        old.at.push(at)
      }
    }
    None => {
      if field.at.is_empty() {
        field.at.push(at)
      }
      index[key] = out.length()
      out.push(field)
    }
  }
}

///|
/// The fields of the tags of an XML part, in the order of the tags. A tag
/// that markup splits is one tag, as the fill reads it; a tag that is not
/// closed is an error.
pub fn inspect_tags(xml : String) -> Array[@tag.Field] raise OoxmlError {
  let tokens : Array[@tag.TagToken] = []
  let mut pos = 0
  while pos < xml.length() {
    let rest = xml[pos:]
    let start = match rest.find("{{") {
      Some(index) => pos + index
      None => break
    }
    let after = xml[start + 2:]
    let end = match after.find("}}") {
      Some(index) => start + 2 + index
      None => raise OoxmlError("ooxml: a tag has no closing braces")
    }
    let name = visible_tag(xml[start + 2:end])
    let parsed = @tag.parse("{{" + name + "}}") catch {
      @tag.TagError(message, _) => raise OoxmlError("ooxml: " + message)
    }
    for token in parsed {
      tokens.push(token)
    }
    pos = end + 2
  }
  @tag.fields(tokens) catch {
    @tag.TagError(message, _) => raise OoxmlError("ooxml: " + message)
  }
}

///|
/// The fields of the tags of every XML part of an OOXML package, with the
/// part each tag is in. The parts are read as the fill reads them.
pub fn inspect_zip(data : Bytes) -> Array[@tag.Field] raise OoxmlError {
  let archive = @zip.open_zip(data) catch {
    _ => raise OoxmlError("ooxml: the package is not a ZIP")
  }
  let out : Array[@tag.Field] = []
  let index : Map[String, Int] = Map([])
  for entry in archive.entries {
    if entry.name.has_suffix("/") {
      continue
    }
    if !(entry.name.has_suffix(".xml") || entry.name.has_suffix(".rels")) {
      continue
    }
    let raw = archive.read(entry, 268435456) catch {
      _ => raise OoxmlError("ooxml: a part cannot be read")
    }
    let text = @utf8.decode_lossy(raw[:])
    let fields = inspect_tags(text) catch {
      OoxmlError(message) => raise OoxmlError(entry.name + ": " + message)
    }
    for field in fields {
      inspect_put(out, index, field, entry.name)
    }
  }
  out
}
