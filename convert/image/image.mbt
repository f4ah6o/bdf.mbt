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
  summary : String
  warnings : Array[String]
}

///|
/// Convert a BMP or ICO to a single-page BDF. Other image formats are not yet
/// implemented. The optional title overrides the document title, while the
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
  let dc : Map[String, Json] = {}
  if title != "" {
    dc["title"] = Json::string(title)
  }
  let meta : Map[String, Json] = { "source": Json::string(picture.format) }
  if title != "" {
    meta["dc"] = Json::object(dc)
  }
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let image_hash = writer.add_part("img", data)
  let width = Float::from_double(picture.width.to_double() * 0.75)
  let height = Float::from_double(picture.height.to_double() * 0.75)
  let alt = if title != "" { title } else { name }
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
  if title != "" {
    view["title"] = Json::string(title)
  }
  writer.add_view(Json::object(view))
  let format_name = if picture.format == "bmp" { "BMP" } else { "ICO" }
  let summary = "1 page (\{picture.width} × \{picture.height} px, \{format_name})"
  {
    bdf: writer.write_single(),
    format: picture.format,
    width: picture.width.to_double(),
    height: picture.height.to_double(),
    summary,
    warnings: [],
  }
}
