///|
let svg_namespace = "http://www.w3.org/2000/svg"

///|
fn svg_decode(data : Bytes, lossy : Bool) -> (String, Bool)? {
  if data.length() >= 2 &&
    (
      (data[0] == 0xff && data[1] == 0xfe) ||
      (data[0] == 0xfe && data[1] == 0xff)
    ) {
    return Some(
      (
        "\u{feff}" +
        metadata_utf16_raw(data[2:].to_bytes(), data[0] == 0xff, false),
        true,
      ),
    )
  }
  if lossy {
    return Some((@utf8.decode_lossy(data, ignore_bom=true), false))
  }
  let text = @utf8.decode(data, ignore_bom=true) catch { _ => return None }
  Some((text, false))
}

///|
fn svg_candidate(data : Bytes) -> Bool {
  let size = if data.length() < 65536 { data.length() } else { 65536 }
  guard svg_decode(data[:size].to_bytes(), true) is Some((text, _)) else {
    return false
  }
  let reader = @xml.NamespaceReader::from_string(text)
  while true {
    let event = reader.read_event() catch { _ => return false }
    match event.kind {
      Start(element) | Empty(element) => return element.name.local_name == "svg"
      Eof => return false
      _ => ()
    }
  }
  false
}

///|
fn svg_all_text(node : XmpNode, output : StringBuilder) -> Unit {
  output.write_string(node.text.to_string())
  for child in node.children {
    output.write_char(' ')
    svg_all_text(child, output)
  }
}

///|
// A complete SVG followed by other content is not detected as an image by
// the upstream converter. Errors before the root closes are handled as SVG.
fn svg_has_trailing_content(text : String) -> Bool {
  let reader = @xml.NamespaceReader::from_string(text)
  let mut depth = 0
  let mut closed = false
  while true {
    let event = reader.read_event() catch { _ => return closed }
    match event.kind {
      Start(_) => {
        if closed {
          return true
        }
        depth += 1
      }
      Empty(_) => {
        if closed {
          return true
        }
        if depth == 0 {
          closed = true
        }
      }
      End(_) => {
        depth -= 1
        if depth == 0 {
          closed = true
        }
      }
      Text(value) | CData(value) =>
        if closed && xmp_trim_space(value) != "" {
          return true
        }
      Eof => return false
      _ => ()
    }
  }
  false
}

///|
// Accept a partial tree only for an end-of-input error. Other XML errors can
// have different recovery rules upstream and must not silently lose metadata.
fn svg_is_truncated(text : String) -> Bool {
  let reader = @xml.NamespaceReader::from_string(text)
  while true {
    let event = reader.read_event() catch {
      @xml.At(error~, span~) =>
        match error {
          @xml.UnexpectedEof => return true
          @xml.InvalidSyntax(message) =>
            return message.has_prefix("unclosed element: <") ||
              (
                span.end.offset == text.length() &&
                message == "expected '>' or '/>' at end of start tag"
              )
          _ => return false
        }
      _ => return false
    }
    if event.kind is Eof {
      return false
    }
  }
  false
}

///|
fn read_svg(data : Bytes) -> Picture raise {
  guard svg_decode(data, false) is Some((text, utf16)) else {
    raise ImageFailure("image: SVG encoding is not yet supported")
  }
  let (root, complete) = xmp_tree_checked(
    text,
    utf16~,
    entire=data.length() <= 8388608,
  )
  if !complete {
    if data.length() <= 8388608 && svg_has_trailing_content(text) {
      raise ImageFailure(
        "image: input is not a supported BMP, ICO, JPEG, PNG, GIF, WebP, AVIF or SVG image",
      )
    }
    // The upstream parser keeps the root and any children read before EOF.
    if root is None || !svg_is_truncated(text) {
      raise ImageFailure("image: malformed SVG is not yet supported")
    }
  }
  guard root is Some(root) && root.name == "svg" else {
    raise ImageFailure("image: SVG: the SVG document has no root element")
  }
  let (width, height) = svg_dimensions(
    root.attribute("", "width"),
    root.attribute("", "height"),
    root.attribute("", "viewBox"),
  )
  if width.is_inf() ||
    width.is_nan() ||
    height.is_inf() ||
    height.is_nan() ||
    Float::from_double(width * 0.75).is_inf() ||
    Float::from_double(height * 0.75).is_inf() {
    raise ImageFailure("image: SVG size is out of range")
  }
  let warnings : Array[String] = []
  if root.space != svg_namespace {
    warnings.push(
      "the root svg element is not in the SVG namespace (xmlns=\"http://www.w3.org/2000/svg\"): browsers do not draw it",
    )
  }
  let native : Map[String, Array[String]] = Map([])
  let language = root.attribute(xmp_xml, "lang")
  xmp_add(native, "language", [
    if language != "" {
      language
    } else {
      root.attribute("", "lang")
    },
  ])
  let mut metadata : XmpNode? = None
  for child in root.children {
    if child.space != svg_namespace && child.space != "" {
      continue
    }
    if child.name == "title" || child.name == "desc" {
      let output = StringBuilder()
      svg_all_text(child, output)
      png_set_text(
        native,
        if child.name == "title" {
          "title"
        } else {
          "description"
        },
        xmp_collapse(output.to_string()),
      )
    } else if child.name == "metadata" && metadata is None {
      metadata = Some(child)
    }
  }
  let dc : Map[String, Array[String]] = Map([])
  if metadata is Some(node) {
    metadata_merge(dc, xmp_metadata(node))
  }
  metadata_merge(dc, native)
  { format: "svg", width, height, dc, animated: false, warnings, }
}
