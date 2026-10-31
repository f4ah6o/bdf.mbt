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
  no_text_index~ : Bool = false,
) -> Bytes raise PdfStreamError {
  let (document, _) = pdf_graphics_document_result(
    data,
    box~,
    title~,
    no_text_index~,
  )
  document
}

///|
fn pdf_graphics_document_result(
  data : Bytes,
  box~ : String = "crop",
  title~ : String = "",
  no_text_index~ : Bool = false,
) -> (Bytes, Array[String]) raise PdfStreamError {
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
  let objects : Map[String, @core.ObjectResources] = Map([])
  let index : Array[@core.IndexRun] = []
  let budget = @render.TextExtractionBudget::new()
  let mut index_error : String? = None
  for page in pages {
    let (geometry, object, children) = file.graphics_page_parts(page, box)
    for child in children {
      let hash = writer.add_part("obj", child) catch {
        _ => raise InvalidStream("PDF BDF child output failed")
      }
      if !no_text_index {
        objects[hash] = @core.decode_object_resources(child) catch {
          _ => raise InvalidStream("PDF BDF child decoding failed")
        }
      }
    }
    let hash = writer.add_part("obj", object) catch {
      _ => raise InvalidStream("PDF BDF object output failed")
    }
    if !no_text_index && index_error is None {
      index_error = pdf_collect_index(
        index,
        objects,
        object,
        budget,
        output_pages.length(),
      )
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
  let warnings = pdf_write_index(
    writer, view, index, index_error, no_text_index,
  )
  if document_title != "" {
    view["title"] = Json::string(document_title)
  }
  if !output_pages.is_empty() {
    view["pages"] = Json::array(output_pages)
  }
  writer.add_view(Json::object(view))
  let document = writer.write_single() catch {
    _ => raise InvalidStream("PDF BDF document output failed")
  }

  (document, warnings)
}

///|
fn pdf_collect_index(
  index : Array[@core.IndexRun],
  objects : Map[String, @core.ObjectResources],
  object : Bytes,
  budget : @render.TextExtractionBudget,
  page : Int32,
) -> String? {
  let content = try {
    let resources = @core.decode_object_resources(object)
    @render.extract_text_with_budget(
      resources,
      fn(hash) { objects.get(hash) },
      budget,
    )
  } catch {
    @render.InvalidOperands(message) => return Some(message)
    error => return Some(error.to_string())
  }
  for i, run in content.runs {
    index.push({
      a: page,
      b: 0,
      ordinal: run.ordinal,
      separator: if i == 0 {
        2
      } else {
        run.separator
      },
      text: run.text,
    })
  }
  None
}

///|
fn pdf_write_index(
  writer : @core.DocumentWriter,
  view : Map[String, Json],
  index : Array[@core.IndexRun],
  failure : String?,
  disabled : Bool,
) -> Array[String] raise PdfStreamError {
  if disabled {
    return []
  }
  match failure {
    Some(message) => ["text index: bdf: " + message]
    None => {
      let encoded = @core.encode_text_index(index) catch {
        _ => raise InvalidStream("PDF BDF text index encoding failed")
      }
      let hash = writer.add_part("idx", encoded) catch {
        _ => raise InvalidStream("PDF BDF text index output failed")
      }
      view["textIndex"] = Json::string(hash)
      []
    }
  }
}
