///|
fn pdf_dc_value(
  fields : Map[String, Json],
  key : String,
  value : String,
) -> Unit {
  if value != "" {
    fields[key] = Json::string(value)
  }
}

///|
// A bounded internal path for evaluating the graphics renderer end to end.
// It rejects features whose appearance or content is not implemented yet.
fn pdf_graphics_document(
  data : Bytes,
  box~ : String = "crop",
  title~ : String = "",
) -> Bytes raise PdfStreamError {
  if !["", "crop", "media", "bleed", "trim", "art"].contains(box) {
    raise InvalidStream("unknown PDF page box")
  }
  let file = pdf_open_file(data)
  match file.trailer_entry(b"Encrypt") {
    Some(value) if value != PdfNull =>
      raise InvalidStream("encrypted PDF is not supported yet")
    _ => ()
  }
  let catalog = file.page_deref(file.trailer_entry(b"Root"))
  match pdf_dict_get(catalog, b"OCProperties") {
    Some(value) if value != PdfNull =>
      raise InvalidStream("PDF optional content is not supported yet")
    _ => ()
  }
  match pdf_dict_get(catalog, b"StructTreeRoot") {
    Some(value) if value != PdfNull =>
      raise InvalidStream("PDF tagged structure is not supported yet")
    _ => ()
  }
  let (pages, left) = file.page_leaves()
  if left != 0 {
    raise InvalidStream("PDF page tree has omitted repetitions")
  }
  let metadata = file.metadata()
  let document_title = if title == "" { metadata.title } else { title }
  let fields : Map[String, Json] = Map([])
  pdf_dc_value(fields, "title", document_title)
  pdf_dc_value(fields, "creator", metadata.creator)
  if metadata.subjects.length() == 1 {
    fields["subject"] = Json::string(metadata.subjects[0])
  } else if metadata.subjects.length() > 1 {
    fields["subject"] = Json::array(
      metadata.subjects.map(fn(value) { Json::string(value) }),
    )
  }
  pdf_dc_value(fields, "description", metadata.description)
  pdf_dc_value(
    fields,
    "language",
    file.metadata_text(pdf_dict_get(catalog, b"Lang")).trim().to_owned(),
  )
  pdf_dc_value(fields, "created", metadata.created)
  pdf_dc_value(fields, "modified", metadata.modified)
  let meta : Map[String, Json] = Map([])
  if !fields.is_empty() {
    meta["dc"] = Json::object(fields)
  }
  meta["source"] = Json::string("pdf")
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let output_pages : Array[Json] = []
  for page in pages {
    let (geometry, object, children) = file.graphics_page_parts(page, box)
    for child in children {
      ignore(writer.add_part("obj", child)) catch {
        _ => raise InvalidStream("PDF BDF child output failed")
      }
    }
    let hash = writer.add_part("obj", object) catch {
      _ => raise InvalidStream("PDF BDF object output failed")
    }
    let width = Float::from_double(geometry.width)
    let height = Float::from_double(geometry.height)
    let layer = Json::object({
      "role": Json::string("body"),
      "obj": Json::string(hash),
    })
    output_pages.push(
      Json::object({
        "w": Json::number(width.to_double(), repr=width.to_string()),
        "h": Json::number(height.to_double(), repr=height.to_string()),
        "layers": Json::array([layer]),
      }),
    )
  }
  let view : Map[String, Json] = {
    "id": Json::string("pages"),
    "kind": Json::string("fixed"),
  }
  if document_title != "" {
    view["title"] = Json::string(document_title)
  }
  if !output_pages.is_empty() {
    view["pages"] = Json::array(output_pages)
  }
  writer.add_view(Json::object(view))
  writer.write_single() catch {
    _ => raise InvalidStream("PDF BDF document output failed")
  }
}
