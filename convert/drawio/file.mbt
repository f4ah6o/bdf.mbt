///|
priv struct DrawioPage {
  id : String
  name : String
  model : DrawioNode
}

///|
const DRAWIO_MAX_DECOMPRESSED : Int = 67108864

///|
fn drawio_trim(text : String) -> String {
  let mut start = 0
  let mut end = text.length()
  while start < end {
    let c = text[start].unsafe_to_char()
    if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      start += 1
    } else {
      break
    }
  }
  while end > start {
    let c = text[end - 1].unsafe_to_char()
    if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      end -= 1
    } else {
      break
    }
  }
  text[start:end].to_owned()
}

///|
fn drawio_utf8_byte(out : Array[Byte], c : Char) -> Unit {
  for byte in @utf8.encode(c.to_string()) {
    out.push(byte)
  }
}

///|
fn drawio_percent_decode(text : String) -> String {
  if !text.contains("%") {
    return text
  }
  let out : Array[Byte] = []
  let mut index = 0
  while index < text.length() {
    let c = text[index].unsafe_to_char()
    if c == '%' && index + 2 < text.length() {
      let high = drawio_hex(text[index + 1].unsafe_to_char())
      let low = drawio_hex(text[index + 2].unsafe_to_char())
      if high >= 0 && low >= 0 {
        out.push(((high << 4) | low).to_byte())
        index += 3
        continue
      }
    }
    drawio_utf8_byte(out, c)
    index += 1
  }
  @utf8.decode_lossy(Bytes::from_array(out))
}

///|
fn drawio_hex(c : Char) -> Int {
  if c >= '0' && c <= '9' {
    c.to_int() - 48
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 87
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 55
  } else {
    -1
  }
}

///|
fn drawio_inflate(data : Bytes, max : Int) -> Bytes raise {
  let decoder = @deflate.Decoder(until=EndOfMember)
  let output = @buffer.Buffer()
  let mut offset = 0
  while true {
    let remaining = max - output.length()
    if remaining <= 0 {
      return output.to_bytes()
    }
    let size = if remaining < 65536 { remaining } else { 65536 }
    let chunk : FixedArray[Byte] = FixedArray::make(size, b'\x00')
    let state = decoder.step_into(data[offset:], chunk, end=false)
    let consumed = decoder.last_consumed()
    let produced = decoder.last_produced()
    output.write_bytesview(Bytes::from_array(chunk[:produced])[:])
    offset += consumed
    if state is Done || state is NeedMoreInput {
      return output.to_bytes()
    }
    if consumed == 0 && produced == 0 {
      raise Failure("drawio: truncated deflate stream")
    }
  }
  output.to_bytes()
}

///|
fn drawio_zlib_inflate(data : Bytes, max : Int) -> Bytes raise {
  let decoder = @zlib.Decoder(until=EndOfMember)
  let output = @buffer.Buffer()
  let mut offset = 0
  while true {
    let remaining = max - output.length()
    if remaining <= 0 {
      return output.to_bytes()
    }
    let size = if remaining < 65536 { remaining } else { 65536 }
    let chunk : FixedArray[Byte] = FixedArray::make(size, b'\x00')
    let state = decoder.step_into(data[offset:], chunk, end=false)
    let consumed = decoder.last_consumed()
    let produced = decoder.last_produced()
    output.write_bytesview(Bytes::from_array(chunk[:produced])[:])
    offset += consumed
    if state is Done || state is NeedMoreInput {
      return output.to_bytes()
    }
    if consumed == 0 && produced == 0 {
      raise Failure("drawio: truncated zlib stream")
    }
  }
  output.to_bytes()
}

///|
fn drawio_base64(text : String) -> Bytes raise {
  let cleaned = drawio_trim(text).replace(old="\n", new="").replace(old="\r", new="").replace(old="\t", new="").replace(old=" ", new="")
  let raw = @base64.decode(cleaned[:], ignore_whitespace=true) catch {
    _ => {
      let mut value = cleaned
      while value.has_suffix("=") {
        value = value[:value.length() - 1].to_owned()
      }
      @base64.decode(value[:], ignore_whitespace=true) catch {
        _ => raise Failure("drawio: invalid base64 diagram")
      }
    }
  }
  raw
}

///|
fn drawio_decompress(text : String) -> String raise {
  let raw = drawio_base64(text)
  let inflated = drawio_inflate(raw, DRAWIO_MAX_DECOMPRESSED) catch {
    _ => drawio_zlib_inflate(raw, DRAWIO_MAX_DECOMPRESSED) catch {
      _ => raise Failure("drawio: invalid compressed diagram")
    }
  }
  drawio_percent_decode(@utf8.decode_lossy(inflated))
}

///|
fn drawio_empty_model() -> DrawioNode {
  {
    name: "mxGraphModel",
    attrs: Map([]),
    children: [],
    text: StringBuilder(),
  }
}

///|
fn drawio_page_from_model(id : String, name : String, model : DrawioNode) -> DrawioPage {
  { id, name, model }
}

///|
fn drawio_pages_from_root(root : DrawioNode) -> Array[DrawioPage] raise {
  match root.name {
    "mxGraphModel" => [drawio_page_from_model("", "", root)]
    "mxfile" => {
      let pages : Array[DrawioPage] = []
      for child in root.children {
        if child.name != "diagram" {
          continue
        }
        let id = drawio_attr(child, "id", "")
        let name = drawio_attr(child, "name", "")
        let model = match drawio_find(child, "mxGraphModel") {
          Some(value) => value
          None => {
            let text = drawio_trim(child.text.to_string())
            if text == "" {
              drawio_empty_model()
            } else {
              let decoded = drawio_decompress(text)
              drawio_parse(decoded) catch {
                Failure(message) => raise Failure(message)
                _ => raise Failure("drawio: invalid compressed page")
              }
            }
          }
        }
        pages.push(drawio_page_from_model(id, name, model))
      }
      if pages.is_empty() {
        raise Failure("drawio: the mxfile has no diagram")
      }
      pages
    }
    _ => raise Failure("drawio: unexpected root element")
  }
}

///|
fn drawio_read_payload(text : String) -> Array[DrawioPage] raise {
  let trimmed = drawio_percent_decode(drawio_trim(text))
  if trimmed == "" {
    raise Failure("drawio: empty embedded diagram")
  }
  let xml = if trimmed.has_prefix("<") {
    trimmed
  } else {
    drawio_decompress(trimmed)
  }
  let root = drawio_parse(xml) catch {
    Failure(message) => raise Failure(message)
    _ => raise Failure("drawio: invalid embedded XML")
  }
  drawio_pages_from_root(root)
}

///|
fn drawio_png_keyword(data : Bytes, start : Int, end : Int) -> (String, Int) {
  let mut index = start
  while index < end && data[index] != 0 {
    index += 1
  }
  if index >= end {
    return ("", index)
  }
  (@utf8.decode_lossy(data[start:index]), index + 1)
}

///|
fn drawio_png_pages(data : Bytes) -> Array[DrawioPage] raise {
  if data.length() < 8 || !data.has_prefix(b"\x89PNG\r\n\x1a\n") {
    raise Failure("drawio: invalid PNG")
  }
  let mut pos = 8
  let mut payload : Bytes? = None
  while pos + 12 <= data.length() {
    let length = (data[pos].to_int() << 24) |
      (data[pos + 1].to_int() << 16) |
      (data[pos + 2].to_int() << 8) |
      data[pos + 3].to_int()
    if length < 0 || pos + 12 + length > data.length() {
      break
    }
    let kind = @utf8.decode_lossy(data[pos + 4:pos + 8])
    let body_start = pos + 8
    let body_end = body_start + length
    if kind == "tEXt" {
      let (keyword, text_start) = drawio_png_keyword(data, body_start, body_end)
      if keyword == "mxfile" || keyword == "mxGraphModel" {
        payload = Some(data[text_start:body_end].to_owned())
      }
    } else if kind == "zTXt" {
      let (keyword, text_start) = drawio_png_keyword(data, body_start, body_end)
      if (keyword == "mxfile" || keyword == "mxGraphModel") &&
        text_start < body_end && data[text_start] == 0 {
        let inflated = drawio_zlib_inflate(
          data[text_start + 1:body_end].to_owned(),
          DRAWIO_MAX_DECOMPRESSED,
        ) catch {
          _ => raise Failure("drawio: invalid PNG zTXt")
        }
        payload = Some(inflated)
      }
    } else if kind == "iTXt" {
      let (keyword, text_start) = drawio_png_keyword(data, body_start, body_end)
      if keyword == "mxfile" || keyword == "mxGraphModel" {
        if text_start + 2 > body_end {
          raise Failure("drawio: invalid PNG iTXt")
        }
        let compressed = data[text_start] == 1
        let mut start = text_start + 2
        // language tag and translated keyword
        for _ in 0..<2 {
          while start < body_end && data[start] != 0 {
            start += 1
          }
          start += 1
        }
        if start > body_end {
          raise Failure("drawio: invalid PNG iTXt")
        }
        let value = if compressed {
          drawio_zlib_inflate(data[start:body_end].to_owned(), DRAWIO_MAX_DECOMPRESSED) catch {
            _ => raise Failure("drawio: invalid PNG iTXt")
          }
        } else {
          data[start:body_end].to_owned()
        }
        payload = Some(value)
      }
    }
    pos = body_end + 4
  }
  match payload {
    Some(value) => drawio_read_payload(@utf8.decode_lossy(value))
    None => raise Failure("drawio: the PNG has no embedded diagram")
  }
}

///|
fn drawio_svg_content(root : DrawioNode) -> String raise {
  match root.attrs.get("content") {
    Some(value) => value
    None => raise Failure("drawio: the SVG has no embedded diagram")
  }
}

///|
fn drawio_read_file(data : Bytes) -> Array[DrawioPage] raise {
  if data.length() > 268435456 {
    raise Failure("drawio: the file is larger than 268435456 bytes")
  }
  if data.has_prefix(b"\x89PNG\r\n\x1a\n") {
    return drawio_png_pages(data)
  }
  let text = @utf8.decode_lossy(data)
  let root = drawio_parse(text) catch {
    Failure(message) => raise Failure(message)
    _ => raise Failure("drawio: invalid XML")
  }
  if root.name == "svg" {
    return drawio_read_payload(drawio_svg_content(root))
  }
  drawio_pages_from_root(root)
}
