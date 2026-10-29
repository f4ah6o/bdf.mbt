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
/// Convert a BMP, ICO, JPEG, PNG, GIF, WebP, AVIF or SVG to a single-page BDF.
/// JPEG, PNG, WebP and AVIF support EXIF and XMP metadata, GIF supports XMP,
/// and JPEG also supports IPTC. Some malformed SVG, XML character encodings,
/// and PNG Creation Time timezone abbreviations are
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
  let width = Float::from_double(picture.width * 0.75)
  let height = Float::from_double(picture.height * 0.75)
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
    image_object(image_hash, width, height, alt, picture.format != "svg"),
  )
  let layer = Json::object({
    "role": Json::string("body"),
    "obj": Json::string(object_hash),
  })
  let page = Json::object({
    "w": Json::number(width.to_double(), repr=width.to_string()),
    "h": Json::number(height.to_double(), repr=height.to_string()),
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
    "avif" => "AVIF"
    "svg" => "SVG"
    _ => "PNG"
  }
  let suffix = if picture.animated { ", animated" } else { "" }
  let summary = "1 page (\{image_px(picture.width)} × \{image_px(picture.height)} px, \{format_name}\{suffix})"
  let warnings = [ for warning in picture.warnings => warning ]
  if picture.animated {
    warnings.push("animated image: the first frame is drawn")
  }
  {
    bdf: writer.write_single(),
    format: picture.format,
    width: picture.width,
    height: picture.height,
    animated: picture.animated,
    summary,
    warnings,
  }
}

///|
fn image_px(value : Double) -> String {
  let text = ((value * 100.0).round() / 100.0).to_string()
  let bytes = @utf8.encode(text)
  let mut exponent_at = -1
  for i in 0..<bytes.length() {
    if bytes[i] == b'e' || bytes[i] == b'E' {
      exponent_at = i
      break
    }
  }
  if exponent_at < 0 {
    return text
  }
  let exponent_text = @utf8.decode(bytes[exponent_at + 1:]) catch {
    _ => return text
  }
  let exponent = @string.parse_int(exponent_text) catch { _ => return text }
  let digits = @buffer.Buffer()
  let mut decimal_at = exponent_at
  for i in 0..<exponent_at {
    if bytes[i] == b'.' {
      decimal_at = i
    } else {
      digits.write_byte(bytes[i])
    }
  }
  let data = digits.to_bytes()
  decimal_at += exponent
  let result = @buffer.Buffer()
  if decimal_at <= 0 {
    result.write_bytes(b"0.")
    for _ in 0..<-decimal_at {
      result.write_byte(b'0')
    }
    result.write_bytes(data)
  } else if decimal_at >= data.length() {
    result.write_bytes(data)
    for _ in 0..<(decimal_at - data.length()) {
      result.write_byte(b'0')
    }
  } else {
    result.write_bytes(data[:decimal_at])
    result.write_byte(b'.')
    result.write_bytes(data[decimal_at:])
  }
  @utf8.decode(result.to_bytes()) catch {
    _ => text
  }
}
