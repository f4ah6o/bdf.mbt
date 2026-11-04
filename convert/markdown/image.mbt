///|
fn md_percent_decode(text : String) -> Bytes {
  let bytes : Array[Byte] = []
  let chars = text.to_array()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == '%' && i + 2 < chars.length() {
      let high = md_hex_value(chars[i + 1])
      let low = md_hex_value(chars[i + 2])
      if high >= 0 && low >= 0 {
        bytes.push((high * 16 + low).to_byte())
        i += 3
        continue
      }
    }
    if c == '+' {
      bytes.push(b' ')
      i += 1
      continue
    }
    for byte in @utf8.encode(c.to_string()) {
      bytes.push(byte)
    }
    i += 1
  }
  Bytes::from_array(bytes)
}

///|
fn md_hex_value(c : Char) -> Int {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 'A'.to_int() + 10
  } else {
    -1
  }
}

///|
/// Decode a data: URL into its bytes and media type.
fn md_data_url(url : String) -> (Bytes, String)? {
  if !url.has_prefix("data:") {
    return None
  }
  let comma = match url.find(",") {
    Some(index) => index
    None => return None
  }
  let header = url[:comma].to_owned().to_lower()
  let payload = url[comma + 1:].to_owned()
  let bytes = if header.contains(";base64") {
    @base64.decode(payload[:], ignore_whitespace=true) catch { _ => return None }
  } else {
    md_percent_decode(payload)
  }
  let mime = {
    let rest = header[5:].to_owned()
    match rest.find(";") {
      Some(index) => rest[:index].to_owned()
      None => rest
    }
  }
  Some((bytes, mime))
}

///|
fn md_png_size(data : Bytes) -> (Double, Double)? {
  if data.length() < 24 || data[:8] != b"\x89PNG\r\n\x1a\n"[:] {
    return None
  }
  let width = (data[16].to_int() << 24) |
    (data[17].to_int() << 16) |
    (data[18].to_int() << 8) |
    data[19].to_int()
  let height = (data[20].to_int() << 24) |
    (data[21].to_int() << 16) |
    (data[22].to_int() << 8) |
    data[23].to_int()
  if width <= 0 || height <= 0 {
    None
  } else {
    Some((width.to_double(), height.to_double()))
  }
}

///|
fn md_gif_size(data : Bytes) -> (Double, Double)? {
  if data.length() < 10 || data[:6] != b"GIF87a"[:] && data[:6] != b"GIF89a"[:] {
    return None
  }
  let width = data[6].to_int() | (data[7].to_int() << 8)
  let height = data[8].to_int() | (data[9].to_int() << 8)
  if width <= 0 || height <= 0 {
    None
  } else {
    Some((width.to_double(), height.to_double()))
  }
}

///|
fn md_jpeg_size(data : Bytes) -> (Double, Double)? {
  if data.length() < 4 || data[0] != b'\xFF' || data[1] != b'\xD8' {
    return None
  }
  let mut at = 2
  while at + 9 < data.length() {
    if data[at] != b'\xFF' {
      at += 1
      continue
    }
    let marker = data[at + 1].to_int()
    if marker == 0xD8 || marker == 0xD9 || marker == 0x01 ||
      (marker >= 0xD0 && marker <= 0xD7) || marker == 0xFF {
      at += if marker == 0xFF { 1 } else { 2 }
      continue
    }
    if at + 3 >= data.length() {
      return None
    }
    let length = (data[at + 2].to_int() << 8) | data[at + 3].to_int()
    if length < 2 {
      return None
    }
    let start_of_frame = (marker >= 0xC0 && marker <= 0xC3) ||
      (marker >= 0xC5 && marker <= 0xC7) ||
      (marker >= 0xC9 && marker <= 0xCB) ||
      (marker >= 0xCD && marker <= 0xCF)
    if start_of_frame {
      if at + 9 >= data.length() {
        return None
      }
      let height = (data[at + 5].to_int() << 8) | data[at + 6].to_int()
      let width = (data[at + 7].to_int() << 8) | data[at + 8].to_int()
      if width <= 0 || height <= 0 {
        return None
      }
      return Some((width.to_double(), height.to_double()))
    }
    at += 2 + length
  }
  None
}

///|
fn md_webp_size(data : Bytes) -> (Double, Double)? {
  if data.length() < 30 || data[:4] != b"RIFF"[:] || data[8:12] != b"WEBP"[:] {
    return None
  }
  let chunk = data[12:16]
  if chunk == b"VP8X"[:] {
    let width = 1 +
      (data[24].to_int() | (data[25].to_int() << 8) | (data[26].to_int() << 16))
    let height = 1 +
      (data[27].to_int() | (data[28].to_int() << 8) | (data[29].to_int() << 16))
    Some((width.to_double(), height.to_double()))
  } else if chunk == b"VP8 "[:] && data.length() >= 30 &&
    data[23] == b'\x9D' && data[24] == b'\x01' && data[25] == b'\x2A' {
    let width = (data[26].to_int() | (data[27].to_int() << 8)) & 0x3FFF
    let height = (data[28].to_int() | (data[29].to_int() << 8)) & 0x3FFF
    if width > 0 && height > 0 {
      Some((width.to_double(), height.to_double()))
    } else {
      None
    }
  } else if chunk == b"VP8L"[:] && data.length() >= 25 && data[20] == b'\x2F' {
    let bits = data[21].to_int() | (data[22].to_int() << 8) |
      (data[23].to_int() << 16) | (data[24].to_int() << 24)
    let width = (bits & 0x3FFF) + 1
    let height = ((bits >> 14) & 0x3FFF) + 1
    Some((width.to_double(), height.to_double()))
  } else {
    None
  }
}

///|
fn md_image_dimensions(data : Bytes) -> (Double, Double) {
  match md_png_size(data) {
    Some(size) => size
    None =>
      match md_gif_size(data) {
        Some(size) => size
        None =>
          match md_jpeg_size(data) {
            Some(size) => size
            None =>
              match md_webp_size(data) {
                Some(size) => size
                None => (200.0, 150.0)
              }
          }
      }
  }
}

///|
fn md_svg_image(data : Bytes) -> MdImage? {
  let text = @utf8.decode_lossy(data[:], ignore_bom=true)
  let lower = text.to_lower()
  let start = match lower.find("<svg") {
    Some(index) => index
    None => return None
  }
  let raw = text[start:].to_owned()
  let open_end = match raw.find(">") {
    Some(index) => index
    None => return None
  }
  let tag = raw[:open_end + 1].to_owned()
  let (width, height, fill) = md_svg_size(tag)
  let normalized = md_svg_document(raw, "")
  Some({ data: normalized, width, height, fill })
}

///|
fn md_image_from_bytes(data : Bytes, mime : String) -> MdImage {
  if mime.contains("svg") {
    match md_svg_image(data) {
      Some(image) => return image
      None => ()
    }
  }
  let text = @utf8.decode_lossy(data[:data.length().min(512)], ignore_bom=true)
    .trim()
    .to_lower()
  if text.has_prefix("<svg") || text.has_prefix("<?xml") && text.contains("<svg") {
    match md_svg_image(data) {
      Some(image) => return image
      None => ()
    }
  }
  let (width, height) = md_image_dimensions(data)
  { data, width, height, fill: false }
}

///|
fn md_resolve_image(url : String) -> MdImage? {
  match md_data_url(url) {
    Some(entry) => {
      let (data, mime) = entry
      if data.length() == 0 {
        None
      } else {
        Some(md_image_from_bytes(data, mime))
      }
    }
    None => None
  }
}

///|
fn md_short_url(url : String) -> String {
  if url.length() <= 80 {
    url
  } else {
    url[:77].to_owned() + "..."
  }
}

///|
fn md_warn_image(warnings : Array[String], url : String) -> Unit {
  let name = md_short_url(url)
  let message = if url == "" {
    "image: no address"
  } else if url.has_prefix("http://") || url.has_prefix("https://") {
    "image " + name + ": remote references are not fetched"
  } else if url.has_prefix("data:") {
    "image " + name + ": data URL could not be decoded"
  } else if url.has_prefix("#") {
    "image " + name + ": fragment reference of the document"
  } else {
    "image " + name + ": relative reference with no directory to resolve it in"
  }
  if !warnings.contains(message) {
    warnings.push(message)
  }
}
