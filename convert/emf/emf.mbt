///|
/// A Windows metafile conversion failure.
pub suberror EmfError {
  EmfInvalid(String)
}

///|
pub(all) struct EmfResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
/// Detect an enhanced metafile or a Windows metafile.
pub fn detect(data : Bytes) -> Bool {
  @metafile.kind(data) != ""
}

///|
/// Convert an EMF or WMF picture into a one-page fixed document.
pub fn convert(data : Bytes, title~ : String = "") -> EmfResult raise EmfError {
  let file_kind = @metafile.kind(data)
  if file_kind == "" {
    raise EmfInvalid("emf: not a Windows metafile")
  }
  let (width, height) = match @metafile.size(data) {
    Some(value) => value
    None => raise EmfInvalid("emf: the picture has no size")
  }
  let meta : Map[String, Json] = {
    "source": Json::string("emf"),
    "generator": Json::string("bdf-go/0.1"),
  }
  if title != "" {
    meta["dc"] = Json::object({ "title": Json::string(title) })
  }
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let object = @core.ObjectBuilder::new()
  object.set_bbox(
    0.0F,
    0.0F,
    Float::from_double(width),
    Float::from_double(height),
  )
  let warnings = @metafile.draw_into(
    object, writer, data, 0.0, 0.0, width, height,
  ) catch {
    @metafile.MetafileInvalid(message) => raise EmfInvalid(message)
  }
  let encoded = object.encode() catch {
    error => raise EmfInvalid("emf: " + error.to_string())
  }
  let object_hash = writer.add_part("obj", encoded) catch {
    error => raise EmfInvalid("emf: " + error.to_string())
  }
  let page = Json::object({
    "w": Json::number(width, repr=width.to_string()),
    "h": Json::number(height, repr=height.to_string()),
    "layers": Json::array([
      Json::object({
        "role": Json::string("body"),
        "obj": Json::string(object_hash),
      }),
    ]),
  })
  let view : Map[String, Json] = {
    "id": Json::string("pages"),
    "kind": Json::string("fixed"),
    "pages": Json::array([page]),
  }
  if title != "" {
    view["title"] = Json::string(title)
  }
  writer.add_view(Json::object(view))
  let bdf = writer.write_single() catch {
    error => raise EmfInvalid("emf: " + error.to_string())
  }
  let rounded_width = width.round().to_int()
  let rounded_height = height.round().to_int()
  {
    bdf,
    pages: 1,
    summary: "1 page (\{rounded_width} × \{rounded_height} pt), 0 embedded font(s)",
    warnings,
  }
}
