///|
// A DrawingML shape box, rotation, and flips in page coordinates.
priv struct PptxTransform {
  x : Double
  y : Double
  width : Double
  height : Double
  rotation : Double
  flip_h : Bool
  flip_v : Bool
} derive(Debug, Eq)

///|
fn pptx_int64(value : String, default : Int64) -> Int64 {
  let text = pptx_trim(value)
  @string.parse_int64(text) catch {
    _ => @string.parse_double(text).to_int64() catch { _ => default }
  }
}

///|
fn pptx_bool(
  element : @xml.NamespaceElement,
  key : String,
  default : Bool,
) -> Bool {
  match pptx_trim(pptx_attribute(element, key, "")) {
    "1" | "true" | "on" => true
    "0" | "false" | "off" => false
    _ => default
  }
}

///|
fn pptx_transform(content : String) -> PptxTransform? raise {
  if content.contains("<!ENTITY") {
    raise InvalidPptx("OOXML part declares entities")
  }
  let reader = @xml.NamespaceReader::from_string(content)
  let mut depth = 0
  let mut have_root = false
  let mut seen_off = false
  let mut seen_ext = false
  let mut x = 0.0
  let mut y = 0.0
  let mut width = 0.0
  let mut height = 0.0
  let mut rotation = 0.0
  let mut flip_h = false
  let mut flip_v = false
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        if depth == 0 && !have_root {
          have_root = true
          rotation = pptx_int64(pptx_attribute(element, "rot", ""), 0L).to_double() /
            60000.0
          flip_h = pptx_bool(element, "flipH", false)
          flip_v = pptx_bool(element, "flipV", false)
        } else if depth == 1 && element.name.local_name == "off" && !seen_off {
          seen_off = true
          x = pptx_measure(pptx_attribute(element, "x", ""), 0.0)
          y = pptx_measure(pptx_attribute(element, "y", ""), 0.0)
        } else if depth == 1 && element.name.local_name == "ext" && !seen_ext {
          seen_ext = true
          width = pptx_measure(pptx_attribute(element, "cx", ""), 0.0)
          height = pptx_measure(pptx_attribute(element, "cy", ""), 0.0)
        }
        if event.kind is Start(_) {
          depth += 1
        }
      }
      End(_) => depth -= 1
      Eof => break
      _ => ()
    }
  }
  if !have_root || (!seen_off && !seen_ext) {
    None
  } else {
    Some({ x, y, width, height, rotation, flip_h, flip_v, })
  }
}
