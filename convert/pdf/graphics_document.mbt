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
  no_share_prefix~ : Bool = false,
) -> Bytes raise PdfStreamError {
  let (document, _) = pdf_graphics_document_result(
    data,
    box~,
    title~,
    no_text_index~,
    no_share_prefix~,
  )
  document
}

///|
fn pdf_graphics_document_result(
  data : Bytes,
  box~ : String = "crop",
  title~ : String = "",
  no_text_index~ : Bool = false,
  no_share_prefix~ : Bool = false,
) -> (Bytes, Array[String]) raise PdfStreamError {
  let (data, warnings, _, _) = pdf_graphics_document_full(
    data,
    box~,
    title~,
    no_text_index~,
    no_share_prefix~,
  )
  (data, warnings)
}

///|
fn pdf_graphics_document_full(
  data : Bytes,
  box~ : String = "crop",
  title~ : String = "",
  no_text_index~ : Bool = false,
  no_share_prefix~ : Bool = false,
) -> (Bytes, Array[String], Int32, Int64) raise PdfStreamError {
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
  let pending : Array[PdfPendingObject] = []
  let bodies : Array[Int32] = []
  let geometry : Array[PdfPageGeometry] = []
  for page in pages {
    let (page_geometry, object, children, font_ids) = file.graphics_page_parts(
      page, box,
    )
    let body_id = pending.length()
    let child_ids : Array[Int32] = []
    let child_bounds : Array[(Float, Float, Float, Float)] = []
    for i, child in children {
      child_ids.push(body_id + 1 + i)
      let resource = @core.decode_object_resources(child) catch {
        _ => raise InvalidStream("invalid PDF child object")
      }
      if !resource.object.objects.is_empty() {
        raise InvalidStream("nested PDF pending child unsupported")
      }
      let (x, y, w, h) = resource.object.bbox
      child_bounds.push(
        (
          Float::from_double(x),
          Float::from_double(y),
          Float::from_double(w),
          Float::from_double(h),
        ),
      )
    }
    pending.push(pdf_pending(object, child_ids, child_bounds, font_ids))
    for child in children {
      pending.push(pdf_pending(child, [], [], []))
    }
    bodies.push(body_id)
    geometry.push(page_geometry)
  }
  let original_count = pending.length()
  let mut selected_bodies = bodies.copy()
  let mut replaced : Map[Int32, Bool] = {}
  let mut shared_count = 0
  let mut shared_bytes = 0L
  let warnings : Array[String] = []
  if !no_share_prefix && bodies.length() >= 2 {
    try {
      let (staged, selected, removed, count, saved) = pdf_plan_shared(
        pending, bodies,
      )
      for object in staged {
        pending.push(object)
      }
      selected_bodies = selected
      replaced = removed
      shared_count = count
      shared_bytes = saved
    } catch {
      error => warnings.push("prefix sharing: " + error.to_string())
    }
  }
  let objects : Map[String, @core.ObjectResources] = Map([])
  for i in 0..<pending.length() {
    if i < original_count && replaced.contains(i) {
      continue
    }
    ignore(pdf_finalize_pending(pending, i, writer, objects))
  }
  let output_pages : Array[Json] = []
  let index : Array[@core.IndexRun] = []
  let budget = @render.TextExtractionBudget::new()
  let mut index_error : String? = None
  for i, body in selected_bodies {
    let item = pending[body]
    if !no_text_index && index_error is None {
      let object = @core.encode_object_resources(item.resources) catch {
        _ => raise InvalidStream("PDF object encoding failed")
      }
      index_error = pdf_collect_index(index, objects, object, budget, i)
    }
    let width = Float::from_double(geometry[i].width)
    let height = Float::from_double(geometry[i].height)
    let layer = Json::object({
      "role": Json::string("body"),
      "obj": Json::string(item.hash),
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
  for
    warning in pdf_write_index(writer, view, index, index_error, no_text_index) {
    warnings.push(warning)
  }
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

  (document, warnings, shared_count, shared_bytes)
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
