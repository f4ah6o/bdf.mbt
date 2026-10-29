///|
pub suberror ImageError {
  ImageFailure(String)
}

///|
/// The converted image and the dimensions at which browsers display it.
pub(all) struct ImageResult {
  bdf : Bytes
  format : String
  width : Double
  height : Double
  animated : Bool
  summary : String
  warnings : Array[String]
}

///|
/// Convert a BMP, ICO, JPEG, PNG, GIF or WebP to a single-page BDF. JPEG, PNG
/// and WebP support EXIF and XMP metadata, GIF supports XMP, and JPEG also supports
/// IPTC. Some XMP encodings and PNG Creation Time timezone abbreviations are
/// not yet supported. The optional
/// title overrides the document title, while the
/// file name supplies alternative text when there is no title.
pub fn convert(
  data : Bytes,
  title~ : String = "",
  name~ : String = "",
) -> ImageResult raise {
  if data.length() > 1073741824 {
    raise ImageFailure("image: the file is larger than 1073741824 bytes")
  }
  let picture = read_picture(data)
  let fields = picture.dc
  if title != "" {
    fields["title"] = [title]
  }
  let dc : Map[String, Json] = Map([])
  for key, values in fields {
    if values.length() == 1 {
      dc[key] = Json::string(values[0])
    } else if values.length() > 1 {
      dc[key] = Json::array(values.map(value => Json::string(value)))
    }
  }
  let meta : Map[String, Json] = { "source": Json::string(picture.format) }
  if dc.length() > 0 {
    meta["dc"] = Json::object(dc)
  }
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let image_hash = writer.add_part("img", data)
  let width = Float::from_double(picture.width.to_double() * 0.75)
  let height = Float::from_double(picture.height.to_double() * 0.75)
  let document_title = match fields.get("title") {
    Some(values) if values.length() > 0 => values[0]
    _ => ""
  }
  let description = match fields.get("description") {
    Some(values) if values.length() > 0 => values[0]
    _ => ""
  }
  let alt = if description != "" {
    description
  } else if document_title != "" {
    document_title
  } else {
    name
  }
  let object_hash = writer.add_part(
    "obj",
    image_object(image_hash, width, height, alt),
  )
  let layer = Json::object({
    "role": Json::string("body"),
    "obj": Json::string(object_hash),
  })
  let page = Json::object({
    "w": Json::number(width.to_double()),
    "h": Json::number(height.to_double()),
    "layers": Json::array([layer]),
  })
  let view : Map[String, Json] = {
    "id": Json::string("pages"),
    "kind": Json::string("fixed"),
    "pages": Json::array([page]),
  }
  if document_title != "" {
    view["title"] = Json::string(document_title)
  }
  writer.add_view(Json::object(view))
  let format_name = match picture.format {
    "bmp" => "BMP"
    "ico" => "ICO"
    "jpeg" => "JPEG"
    "gif" => "GIF"
    "webp" => "WebP"
    _ => "PNG"
  }
  let suffix = if picture.animated { ", animated" } else { "" }
  let summary = "1 page (\{picture.width} × \{picture.height} px, \{format_name}\{suffix})"
  let warnings = [ for warning in picture.warnings => warning ]
  if picture.animated {
    warnings.push("animated image: the first frame is drawn")
  }
  {
    bdf: writer.write_single(),
    format: picture.format,
    width: picture.width.to_double(),
    height: picture.height.to_double(),
    animated: picture.animated,
    summary,
    warnings,
  }
}
