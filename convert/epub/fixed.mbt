///|
/// A manifest item of an EPUB package document.
priv struct EpubItem {
  href : String
  media : String
  properties : String
}

///|
/// A spine item reference of an EPUB package document.
priv struct EpubSpineRef {
  idref : String
  linear : Bool
  properties : String
}

///|
/// A page of a fixed-layout book: one picture and the page size in CSS pixels.
priv struct EpubFixedPage {
  width : Double
  height : Double
  image : Bytes
  image_width : Double
  image_height : Double
  alt : String
}

///|
/// Read the value of a package document meta element: its content attribute,
/// or the text of its element. Unknown properties are empty.
fn epub_meta_value(opf : String, property : String) -> String {
  let mut pos = 0
  while true {
    match epub_find_tag(opf, pos, "meta") {
      Some((start, end)) => {
        let tag = opf[start:end + 1].to_owned()
        let name = {
          let value = epub_attr_in_tag(tag, "property")
          if value != "" {
            value
          } else {
            epub_attr_in_tag(tag, "name")
          }
        }
        if name.to_lower() == property.to_lower() {
          let content = epub_attr_in_tag(tag, "content")
          if content != "" {
            return content
          }
          if tag.trim().to_owned().has_suffix("/>") {
            return ""
          }
          let after = opf[end + 1:].to_owned()
          let close = match after.find("</") {
            Some(value) => value
            None => after.length()
          }
          return after[:close].trim().to_owned()
        }
        pos = end + 1
      }
      None => break
    }
  }
  ""
}

///|
/// Tell whether the package document declares a pre-paginated publication.
fn epub_is_pre_paginated(opf : String) -> Bool {
  if epub_meta_value(opf, "rendition:layout").to_lower() == "pre-paginated" {
    return true
  }
  epub_meta_value(opf, "fixed-layout").to_lower() == "true"
}

///|
/// Tell whether the spine reads right to left.
fn epub_spine_is_rtl(opf : String) -> Bool {
  epub_attr(opf, "spine", "page-progression-direction").to_lower() == "rtl"
}

///|
/// Read the manifest of a package document: id to item.
fn epub_manifest_items(opf : String) -> Map[String, EpubItem] {
  let items : Map[String, EpubItem] = Map([])
  let mut pos = 0
  while true {
    match epub_find_tag(opf, pos, "item") {
      Some((start, end)) => {
        let tag = opf[start:end + 1].to_owned()
        let id = epub_attr_in_tag(tag, "id")
        let href = epub_attr_in_tag(tag, "href")
        if id != "" && href != "" {
          items[id] = {
            href,
            media: epub_attr_in_tag(tag, "media-type"),
            properties: epub_attr_in_tag(tag, "properties"),
          }
        }
        pos = end + 1
      }
      None => break
    }
  }
  items
}

///|
/// Read the spine of a package document in reading order.
fn epub_spine_refs(opf : String) -> Array[EpubSpineRef] {
  let refs : Array[EpubSpineRef] = []
  let mut pos = 0
  while true {
    match epub_find_tag(opf, pos, "itemref") {
      Some((start, end)) => {
        let tag = opf[start:end + 1].to_owned()
        let idref = epub_attr_in_tag(tag, "idref")
        if idref != "" {
          refs.push({
            idref,
            linear: epub_attr_in_tag(tag, "linear").to_lower() != "no",
            properties: epub_attr_in_tag(tag, "properties"),
          })
        }
        pos = end + 1
      }
      None => break
    }
  }
  refs
}

///|
/// Count the elements of a name in a document, ignoring comments.
fn epub_count_tag(text : String, tag : String) -> Int32 {
  let mut count = 0
  let mut pos = 0
  while true {
    match epub_find_tag(text, pos, tag) {
      Some((_, end)) => {
        count += 1
        pos = end + 1
      }
      None => break
    }
  }
  count
}

///|
fn epub_svg_space(byte : Byte) -> Bool {
  byte == b' ' ||
  byte == b'\t' ||
  byte == b'\r' ||
  byte == b'\n' ||
  byte == b'\x0c'
}

///|
fn epub_svg_digit(byte : Byte) -> Bool {
  byte >= b'0' && byte <= b'9'
}

///|
/// Read a CSS length the way the project's SVG helpers do.
fn epub_svg_length(value : String) -> Double {
  let data = @utf8.encode(value)
  let mut at = 0
  while at < data.length() && epub_svg_space(data[at]) {
    at += 1
  }
  let start = at
  if at < data.length() && (data[at] == b'+' || data[at] == b'-') {
    at += 1
  }
  let mut digits = 0
  while at < data.length() && epub_svg_digit(data[at]) {
    at += 1
    digits += 1
  }
  if at < data.length() && data[at] == b'.' {
    at += 1
    while at < data.length() && epub_svg_digit(data[at]) {
      at += 1
      digits += 1
    }
  }
  if digits == 0 {
    return 0.0
  }
  if at < data.length() && (data[at] == b'e' || data[at] == b'E') {
    let marker = at
    at += 1
    if at < data.length() && (data[at] == b'+' || data[at] == b'-') {
      at += 1
    }
    let exponent = at
    while at < data.length() && epub_svg_digit(data[at]) {
      at += 1
    }
    if at == exponent {
      at = marker
    }
  }
  let number = @utf8.decode(data[start:at]) catch {
    _ => return 0.0
  }
  let magnitude = @string.parse_double(number) catch {
    _ => return 0.0
  }
  if magnitude <= 0.0 || magnitude.is_inf() || magnitude.is_nan() {
    return 0.0
  }
  while at < data.length() && epub_svg_space(data[at]) {
    at += 1
  }
  let unit_start = at
  while at < data.length() &&
        (
          (data[at] >= b'a' && data[at] <= b'z') ||
          (data[at] >= b'A' && data[at] <= b'Z') ||
          data[at] == b'%'
        ) {
    at += 1
  }
  let unit = @utf8.decode(data[unit_start:at]) catch {
    _ => return 0.0
  }
  while at < data.length() && epub_svg_space(data[at]) {
    at += 1
  }
  if at != data.length() {
    return 0.0
  }
  match unit.to_lower() {
    "" | "px" => magnitude
    "pt" => magnitude * (96.0 / 72.0)
    "pc" | "em" => magnitude * 16.0
    "in" => magnitude * 96.0
    "cm" => magnitude * (96.0 / 2.54)
    "mm" => magnitude * (96.0 / 25.4)
    "q" => magnitude * (96.0 / 101.6)
    "ex" => magnitude * 8.0
    _ => 0.0
  }
}

///|
/// Read the width and height of an SVG view box.
fn epub_svg_viewbox(value : String) -> (Double, Double) {
  let fields : Array[String] = []
  let word = StringBuilder()
  for ch in value {
    if ch == ',' || ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      let text = word.to_string()
      if text != "" {
        fields.push(text)
        word.reset()
      }
    } else {
      word.write_char(ch)
    }
  }
  let last = word.to_string()
  if last != "" {
    fields.push(last)
  }
  if fields.length() == 4 {
    let width = @string.parse_double(fields[2]) catch {
      _ => 0.0
    }
    let height = @string.parse_double(fields[3]) catch {
      _ => 0.0
    }
    if width > 0.0 &&
      height > 0.0 &&
      !width.is_nan() &&
      !height.is_nan() &&
      !width.is_inf() &&
      !height.is_inf() {
      return (width, height)
    }
  }
  (0.0, 0.0)
}

///|
/// Read the intrinsic size of an SVG root tag in CSS pixels.
fn epub_svg_size(tag : String) -> (Double, Double) {
  let mut width = epub_svg_length(epub_attr_in_tag(tag, "width"))
  let mut height = epub_svg_length(epub_attr_in_tag(tag, "height"))
  let viewbox = {
    let value = epub_attr_in_tag(tag, "viewBox")
    if value != "" {
      value
    } else {
      epub_attr_in_tag(tag, "viewbox")
    }
  }
  let (view_width, view_height) = epub_svg_viewbox(viewbox)
  if view_width > 0.0 && view_height > 0.0 {
    if width > 0.0 && height <= 0.0 {
      height = width * view_height / view_width
    } else if height > 0.0 && width <= 0.0 {
      width = height * view_width / view_height
    } else if width <= 0.0 && height <= 0.0 {
      width = view_width
      height = view_height
    }
  }
  (width, height)
}

///|
/// Read the root tag of an SVG document.
fn epub_svg_root_tag(text : String) -> String {
  match epub_find_tag(text, 0, "svg") {
    Some((start, end)) => text[start:end + 1].to_owned()
    None => ""
  }
}

///|
/// Read the alternative text of an SVG document: its aria-label, else its
/// title element.
fn epub_svg_alt(text : String, tag : String) -> String {
  let aria = epub_attr_in_tag(tag, "aria-label")
  if aria != "" {
    return aria
  }
  match epub_find_tag(text, 0, "title") {
    Some((_, end)) => {
      let after = text[end + 1:].to_owned()
      let close = match after.find("</") {
        Some(value) => value
        None => return ""
      }
      after[:close].trim().to_owned()
    }
    None => ""
  }
}

///|
/// Read the picture an SVG document is: when it fits exactly one image into
/// its view box and draws nothing else, the image's reference.
fn epub_svg_single_image(text : String) -> String? {
  if epub_count_tag(text, "image") != 1 {
    return None
  }
  for tag in [
    "rect", "circle", "ellipse", "line", "polyline", "polygon", "path", "text",
    "use", "foreignObject",
  ] {
    if epub_count_tag(text, tag) > 0 {
      return None
    }
  }
  match epub_find_tag(text, 0, "image") {
    Some((start, end)) => {
      let tag = text[start:end + 1].to_owned()
      let mut href = epub_attr_in_tag(tag, "href")
      if href == "" {
        href = epub_attr_in_tag(tag, "xlink:href")
      }
      if href == "" {
        None
      } else {
        Some(href)
      }
    }
    None => None
  }
}

///|
/// Return the inline svg element of a content document, if it has one.
fn epub_inline_svg(text : String) -> String? {
  let (start, _) = match epub_find_tag(text, 0, "svg") {
    Some(value) => value
    None => return None
  }
  let rest = text[start:].to_owned()
  let close = match rest.find("</svg") {
    Some(value) => value
    None => return None
  }
  let mut end = start + close + 5
  while end < text.length() && text[end] != 0x3e {
    end += 1
  }
  if end >= text.length() {
    return None
  }
  Some(text[start:end + 1].to_owned())
}

///|
/// Read a CSS pixel count from the start of a viewport token.
fn epub_css_pixels(value : String) -> Double {
  let data = @utf8.encode(value)
  let mut at = 0
  while at < data.length() && epub_svg_space(data[at]) {
    at += 1
  }
  let start = at
  if at < data.length() && (data[at] == b'+' || data[at] == b'-') {
    at += 1
  }
  let mut digits = 0
  while at < data.length() && epub_svg_digit(data[at]) {
    at += 1
    digits += 1
  }
  if at < data.length() && data[at] == b'.' {
    at += 1
    while at < data.length() && epub_svg_digit(data[at]) {
      at += 1
      digits += 1
    }
  }
  if digits == 0 {
    return 0.0
  }
  let number = @utf8.decode(data[start:at]) catch {
    _ => return 0.0
  }
  let magnitude = @string.parse_double(number) catch {
    _ => return 0.0
  }
  if magnitude <= 0.0 || magnitude.is_inf() || magnitude.is_nan() {
    return 0.0
  }
  magnitude
}

///|
/// Read the viewport meta element of a content document: its width and height
/// in CSS pixels.
fn epub_viewport(text : String) -> (Double, Double)? {
  let mut pos = 0
  while true {
    match epub_find_tag(text, pos, "meta") {
      Some((start, end)) => {
        let tag = text[start:end + 1].to_owned()
        if epub_attr_in_tag(tag, "name").to_lower() == "viewport" {
          let content = epub_attr_in_tag(tag, "content")
          let mut width = 0.0
          let mut height = 0.0
          for piece in content.split(",") {
            for part in piece.to_owned().split(";") {
              let token = part.to_owned()
              match token.find("=") {
                Some(at) => {
                  let key = token[:at].trim().to_lower()
                  let value = token[at + 1:].to_owned()
                  if key == "width" {
                    width = epub_css_pixels(value)
                  } else if key == "height" {
                    height = epub_css_pixels(value)
                  }
                }
                None => ()
              }
            }
          }
          if width > 0.0 && height > 0.0 {
            return Some((width, height))
          }
        }
        pos = end + 1
      }
      None => break
    }
  }
  None
}

///|
/// Tell the picture format of image data; empty when unsupported.
fn epub_image_format(data : Bytes) -> String {
  if data.length() >= 8 &&
    data[0] == 0x89 &&
    data[1] == b'P' &&
    data[2] == b'N' &&
    data[3] == b'G' {
    return "png"
  }
  if data.length() >= 3 &&
    data[0] == 0xff &&
    data[1] == 0xd8 &&
    data[2] == 0xff {
    return "jpeg"
  }
  if data.length() >= 6 &&
    (data[:6] == b"GIF87a"[:] || data[:6] == b"GIF89a"[:]) {
    return "gif"
  }
  if data.length() >= 12 &&
    data[:4] == b"RIFF"[:] &&
    data[8:12] == b"WEBP"[:] {
    return "webp"
  }
  if data.length() >= 12 && data[4:8] == b"ftyp"[:] {
    let brand = data[8:12]
    if brand == b"avif"[:] || brand == b"avis"[:] {
      return "avif"
    }
  }
  let head = @utf8.decode_lossy(
    data[:data.length().min(1024)],
    ignore_bom=true,
  )
  if head.trim().to_owned().has_prefix("<") && head.to_lower().contains("<svg") {
    return "svg"
  }
  ""
}

///|
fn epub_be16(data : Bytes, at : Int32) -> Int32 {
  (data[at].to_int() << 8) | data[at + 1].to_int()
}

///|
fn epub_le16(data : Bytes, at : Int32) -> Int32 {
  data[at].to_int() | (data[at + 1].to_int() << 8)
}

///|
fn epub_be32(data : Bytes, at : Int32) -> Int32 {
  (data[at].to_int() << 24) |
  (data[at + 1].to_int() << 16) |
  (data[at + 2].to_int() << 8) |
  data[at + 3].to_int()
}

///|
fn epub_le24(data : Bytes, at : Int32) -> Int32 {
  data[at].to_int() |
  (data[at + 1].to_int() << 8) |
  (data[at + 2].to_int() << 16)
}

///|
/// Read the intrinsic size of raster image data in pixels, when it is known.
fn epub_raster_size(data : Bytes, format : String) -> (Double, Double) {
  if format == "png" {
    if data.length() >= 24 &&
      data[12] == b'I' &&
      data[13] == b'H' &&
      data[14] == b'D' &&
      data[15] == b'R' {
      let width = epub_be32(data, 16)
      let height = epub_be32(data, 20)
      if width > 0 && height > 0 {
        return (width.to_double(), height.to_double())
      }
    }
    return (0.0, 0.0)
  }
  if format == "jpeg" {
    let mut offset = 2
    while offset + 9 < data.length() {
      if data[offset] != 0xff {
        offset += 1
        continue
      }
      let marker = data[offset + 1].to_int()
      if marker == 0xd8 || marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7) {
        offset += 2
        continue
      }
      if marker == 0xd9 || marker == 0xda {
        return (0.0, 0.0)
      }
      let length = epub_be16(data, offset + 2)
      if length < 2 {
        return (0.0, 0.0)
      }
      if marker >= 0xc0 &&
        marker <= 0xcf &&
        marker != 0xc4 &&
        marker != 0xc8 &&
        marker != 0xcc {
        let height = epub_be16(data, offset + 5)
        let width = epub_be16(data, offset + 7)
        if width > 0 && height > 0 {
          return (width.to_double(), height.to_double())
        }
        return (0.0, 0.0)
      }
      offset += 2 + length
    }
    return (0.0, 0.0)
  }
  if format == "gif" {
    if data.length() >= 10 {
      let width = epub_le16(data, 6)
      let height = epub_le16(data, 8)
      if width > 0 && height > 0 {
        return (width.to_double(), height.to_double())
      }
    }
    return (0.0, 0.0)
  }
  if format == "webp" {
    if data.length() >= 16 {
      let chunk = data[12:16]
      if chunk == b"VP8X"[:] {
        if data.length() >= 30 {
          let width = 1 + epub_le24(data, 24)
          let height = 1 + epub_le24(data, 27)
          if width > 1 && height > 1 {
            return (width.to_double(), height.to_double())
          }
        }
      } else if chunk == b"VP8 "[:] {
        if data.length() >= 30 {
          let width = epub_le16(data, 26) & 0x3fff
          let height = epub_le16(data, 28) & 0x3fff
          if width > 0 && height > 0 {
            return (width.to_double(), height.to_double())
          }
        }
      } else if chunk == b"VP8L"[:] {
        if data.length() >= 25 && data[20] == 0x2f {
          let packed = data[21].to_int() |
            (data[22].to_int() << 8) |
            (data[23].to_int() << 16) |
            (data[24].to_int() << 24)
          let width = (packed & 0x3fff) + 1
          let height = ((packed >> 14) & 0x3fff) + 1
          if width > 1 && height > 1 {
            return (width.to_double(), height.to_double())
          }
        }
      }
    }
    return (0.0, 0.0)
  }
  if format == "avif" {
    let mut at = 0
    while at + 16 <= data.length() {
      if data[at] == b'i' &&
        data[at + 1] == b's' &&
        data[at + 2] == b'p' &&
        data[at + 3] == b'e' {
        let width = epub_be32(data, at + 8)
        let height = epub_be32(data, at + 12)
        if width > 0 && height > 0 {
          return (width.to_double(), height.to_double())
        }
      }
      at += 1
    }
  }
  (0.0, 0.0)
}

///|
/// Build the page of an image-only spine item.
fn epub_fixed_picture_item(
  epub_pkg : @ooxml.OoxmlPackage,
  directory : String,
  href : String,
  warnings : Array[String],
) -> EpubFixedPage {
  let path = @ooxml.resolve_ooxml_part(directory, href)
  let data = epub_pkg.read(path) catch {
    _ => {
      warnings.push("EPUB: a fixed-layout page's picture is missing: " + href)
      return epub_fixed_blank_page(0.0, 0.0)
    }
  }
  let format = epub_image_format(data)
  if format == "svg" {
    let text = @utf8.decode_lossy(data[:], ignore_bom=true)
    let tag = epub_svg_root_tag(text)
    let (width, height) = epub_svg_size(tag)
    let alt = epub_svg_alt(text, tag)
    match epub_svg_single_image(text) {
      Some(image_href) => {
        let base = epub_directory_of(path)
        match epub_read_picture(epub_pkg, base, image_href, warnings, href) {
          Some((image, image_width, image_height)) => {
            let (draw_width, draw_height) = if width > 0.0 && height > 0.0 {
              (width, height)
            } else {
              (image_width, image_height)
            }
            {
              width: 0.0,
              height: 0.0,
              image,
              image_width: draw_width,
              image_height: draw_height,
              alt,
            }
          }
          None => epub_fixed_blank_page(width, height)
        }
      }
      None => {
        {
          width: 0.0,
          height: 0.0,
          image: data,
          image_width: width,
          image_height: height,
          alt,
        }
      }
    }
  } else if format == "" {
    warnings.push(
      "EPUB: a fixed-layout page's picture format is not supported: " + href,
    )
    epub_fixed_blank_page(0.0, 0.0)
  } else {
    let (width, height) = epub_raster_size(data, format)
    {
      width: 0.0,
      height: 0.0,
      image: data,
      image_width: width,
      image_height: height,
      alt: "",
    }
  }
}

///|
/// Read a picture of the publication and its intrinsic size.
fn epub_read_picture(
  epub_pkg : @ooxml.OoxmlPackage,
  directory : String,
  href : String,
  warnings : Array[String],
  page : String,
) -> (Bytes, Double, Double)? {
  if href == "" {
    warnings.push(
      "EPUB: a fixed-layout page has no picture reference (" + page + ")",
    )
    return None
  }
  if href.contains(":") {
    warnings.push(
      "EPUB: a fixed-layout picture is outside the publication (" + page + ")",
    )
    return None
  }
  let path = @ooxml.resolve_ooxml_part(directory, href)
  let data = epub_pkg.read(path) catch {
    _ => {
      warnings.push(
        "EPUB: a fixed-layout picture is missing from the publication (" +
        page + ")",
      )
      return None
    }
  }
  let format = epub_image_format(data)
  if format == "" {
    warnings.push(
      "EPUB: a fixed-layout picture format is not supported (" + page + ")",
    )
    return None
  }
  let (width, height) = if format == "svg" {
    epub_svg_size(epub_svg_root_tag(@utf8.decode_lossy(data[:], ignore_bom=true)))
  } else {
    epub_raster_size(data, format)
  }
  Some((data, width, height))
}

///|
fn epub_fixed_blank_page(width : Double, height : Double) -> EpubFixedPage {
  {
    width,
    height,
    image: b"",
    image_width: 0.0,
    image_height: 0.0,
    alt: "",
  }
}

///|
/// The directory a part lives in, with its trailing slash.
fn epub_directory_of(path : String) -> String {
  let data = @utf8.encode(path)
  let mut at = data.length() - 1
  while at >= 0 && data[at] != b'/' {
    at -= 1
  }
  if at < 0 {
    ""
  } else {
    @utf8.decode_lossy(data[:at + 1])
  }
}

///|
/// Build the page of a content document that holds one picture and a viewport.
fn epub_fixed_image_page(
  epub_pkg : @ooxml.OoxmlPackage,
  doc_path : String,
  src : String,
  alt : String,
  viewport : (Double, Double),
  warnings : Array[String],
) -> EpubFixedPage {
  let (view_width, view_height) = viewport
  let base = epub_directory_of(doc_path)
  match epub_read_picture(epub_pkg, base, src, warnings, doc_path) {
    Some((data, width, height)) => {
      {
        width: view_width,
        height: view_height,
        image: data,
        image_width: width,
        image_height: height,
        alt,
      }
    }
    None => epub_fixed_blank_page(view_width, view_height)
  }
}

///|
/// Build the page of a content document that holds one inline svg element.
fn epub_fixed_svg_page(
  epub_pkg : @ooxml.OoxmlPackage,
  doc_path : String,
  svg : String,
  viewport : (Double, Double),
  warnings : Array[String],
) -> EpubFixedPage {
  let (view_width, view_height) = viewport
  let tag = epub_svg_root_tag(svg)
  let (svg_width, svg_height) = epub_svg_size(tag)
  let alt = epub_svg_alt(svg, tag)
  match epub_svg_single_image(svg) {
    Some(href) => {
      let base = epub_directory_of(doc_path)
      match epub_read_picture(epub_pkg, base, href, warnings, doc_path) {
        Some((data, width, height)) => {
          let (draw_width, draw_height) = if svg_width > 0.0 && svg_height > 0.0 {
            (svg_width, svg_height)
          } else {
            (width, height)
          }
          {
            width: view_width,
            height: view_height,
            image: data,
            image_width: draw_width,
            image_height: draw_height,
            alt,
          }
        }
        None => epub_fixed_blank_page(view_width, view_height)
      }
    }
    None => {
      {
        width: view_width,
        height: view_height,
        image: @utf8.encode(svg),
        image_width: svg_width,
        image_height: svg_height,
        alt,
      }
    }
  }
}

///|
/// Build a fixed page from a spine item: an image, or a content document that
/// holds exactly one picture and a viewport. None when the item is not one.
fn epub_fixed_page(
  epub_pkg : @ooxml.OoxmlPackage,
  directory : String,
  item : EpubItem,
  warnings : Array[String],
) -> EpubFixedPage? {
  let media = item.media.to_lower()
  if media.has_prefix("image/") {
    return Some(epub_fixed_picture_item(epub_pkg, directory, item.href, warnings))
  }
  if item.properties.contains("nav") {
    return None
  }
  if !epub_item_is_content(item.href, item.media) {
    return None
  }
  let path = @ooxml.resolve_ooxml_part(directory, item.href)
  let data = epub_pkg.read(path) catch {
    _ => return None
  }
  let text = @utf8.decode_lossy(data[:], ignore_bom=true)
  let viewport = match epub_viewport(text) {
    Some(value) => value
    None => return None
  }
  let images = epub_count_tag(text, "img")
  let svgs = epub_count_tag(text, "svg")
  if images + svgs != 1 {
    return None
  }
  if images == 1 {
    Some(
      epub_fixed_image_page(
        epub_pkg,
        path,
        epub_attr(text, "img", "src"),
        epub_attr(text, "img", "alt"),
        viewport,
        warnings,
      ),
    )
  } else {
    match epub_inline_svg(text) {
      Some(svg) =>
        Some(epub_fixed_svg_page(epub_pkg, path, svg, viewport, warnings))
      None => None
    }
  }
}

///|
/// Build the pages of a fixed-layout book of pictures. None when the reading
/// order is not made of pictures only.
fn epub_fixed_pages(
  epub_pkg : @ooxml.OoxmlPackage,
  opf : String,
  directory : String,
) -> (Array[EpubFixedPage], Array[String])? {
  let items = epub_manifest_items(opf)
  let refs = epub_spine_refs(opf)
  let pages : Array[EpubFixedPage] = []
  let warnings : Array[String] = []
  let mut outside = false
  for entry in refs {
    if !entry.linear {
      outside = true
      continue
    }
    if entry.properties.contains("rendition:layout-reflowable") {
      return None
    }
    let item = match items.get(entry.idref) {
      Some(item) => item
      None => return None
    }
    match epub_fixed_page(epub_pkg, directory, item, warnings) {
      Some(page) => pages.push(page)
      None => return None
    }
  }
  if pages.is_empty() {
    return None
  }
  if outside {
    warnings.push(
      "EPUB: the fixed-layout pages outside the reading order are left out",
    )
  }
  Some((pages, warnings))
}

///|
/// Fit a picture into a page, centered, as SVG's xMidYMid meet does.
fn epub_fixed_fit(
  image_width : Double,
  image_height : Double,
  page_width : Double,
  page_height : Double,
) -> (Double, Double, Double, Double) {
  if image_width > 0.0 && image_height > 0.0 {
    let scale_x = page_width / image_width
    let scale_y = page_height / image_height
    let scale = if scale_x < scale_y { scale_x } else { scale_y }
    let width = image_width * scale
    let height = image_height * scale
    ((page_width - width) / 2.0, (page_height - height) / 2.0, width, height)
  } else {
    (0.0, 0.0, page_width, page_height)
  }
}

///|
fn epub_fixed_page_json(
  width : Float,
  height : Float,
  layers : Array[Json],
) -> Json {
  Json::object({
    "w": Json::number(width.to_double(), repr=width.to_string()),
    "h": Json::number(height.to_double(), repr=height.to_string()),
    "layers": Json::array(layers),
  })
}

///|
/// Write a fixed view of picture pages and their Dublin Core metadata.
fn epub_write_fixed(
  pages : Array[EpubFixedPage],
  document_title : String,
  creator : String,
  language : String,
  rtl : Bool,
  warnings : Array[String],
) -> EpubResult raise EpubError {
  let meta : Map[String, Json] = {
    "source": Json::string("epub"),
    "generator": Json::string("bdf-go/0.1"),
  }
  let dc : Map[String, Json] = Map([])
  if document_title != "" {
    dc["title"] = Json::string(document_title)
  }
  if creator != "" {
    dc["creator"] = Json::string(creator)
  }
  if language != "" {
    dc["language"] = Json::string(language)
  }
  if !dc.is_empty() {
    meta["dc"] = Json::object(dc)
  }
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let page_items : Array[Json] = []
  let mut previous_width = 0.0
  let mut previous_height = 0.0
  for page in pages {
    let mut width = page.width
    let mut height = page.height
    if width <= 0.0 || height <= 0.0 {
      width = page.image_width
      height = page.image_height
    }
    if width <= 0.0 || height <= 0.0 {
      width = previous_width
      height = previous_height
    }
    if width <= 0.0 || height <= 0.0 {
      width = 600.0
      height = 800.0
    }
    previous_width = width
    previous_height = height
    let page_width = Float::from_double(width * 0.75)
    let page_height = Float::from_double(height * 0.75)
    if page.image.is_empty() {
      page_items.push(epub_fixed_page_json(page_width, page_height, []))
      continue
    }
    let image_hash = writer.add_part("img", page.image) catch {
      _ => {
        warnings.push(
          "EPUB: a fixed-layout picture could not be stored; the page is left blank",
        )
        page_items.push(epub_fixed_page_json(page_width, page_height, []))
        continue
      }
    }
    let (x, y, draw_width, draw_height) = epub_fixed_fit(
      page.image_width,
      page.image_height,
      page_width.to_double(),
      page_height.to_double(),
    )
    let object = @core.ObjectBuilder::new()
    object.set_bbox(0.0F, 0.0F, page_width, page_height)
    let index = object.add_image(image_hash)
    if page.alt != "" {
      object.mark(10, page.alt)
    }
    object.image(
      index,
      Float::from_double(x),
      Float::from_double(y),
      Float::from_double(draw_width),
      Float::from_double(draw_height),
    ) catch {
      _ => ()
    }
    if page.alt != "" {
      object.mark(11, "")
    }
    let encoded = object.encode() catch {
      _ => {
        warnings.push(
          "EPUB: a fixed-layout page object could not be encoded; the page is left blank",
        )
        page_items.push(epub_fixed_page_json(page_width, page_height, []))
        continue
      }
    }
    let object_hash = writer.add_part("obj", encoded) catch {
      _ => {
        warnings.push(
          "EPUB: a fixed-layout page object could not be stored; the page is left blank",
        )
        page_items.push(epub_fixed_page_json(page_width, page_height, []))
        continue
      }
    }
    page_items.push(
      epub_fixed_page_json(
        page_width,
        page_height,
        [
          Json::object({
            "role": Json::string("body"),
            "obj": Json::string(object_hash),
          }),
        ],
      ),
    )
  }
  let view : Map[String, Json] = {
    "id": Json::string("pages"),
    "kind": Json::string("fixed"),
    "direction": Json::string(if rtl { "rtl" } else { "ltr" }),
    "pages": Json::array(page_items),
  }
  if document_title != "" {
    view["title"] = Json::string(document_title)
  }
  writer.add_view(Json::object(view))
  let bdf = writer.write_single() catch {
    _ => raise EpubInvalid("EPUB document could not be written")
  }
  let count = page_items.length()
  {
    bdf,
    pages: count,
    summary: "\{count} fixed-layout page(s)",
    warnings,
  }
}
