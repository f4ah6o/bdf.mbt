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
fn pptx_transform_node(node : PptxXmlNode?) -> PptxTransform? {
  match node {
    Some(value) => {
      let off = pptx_child(Some(value), "off")
      let ext = pptx_child(Some(value), "ext")
      if off is None && ext is None {
        return None
      }
      let (x, y) = match off {
        Some(n) =>
          (
            pptx_measure(pptx_attribute(n.element, "x", ""), 0.0),
            pptx_measure(pptx_attribute(n.element, "y", ""), 0.0),
          )
        None => (0.0, 0.0)
      }
      let (width, height) = match ext {
        Some(n) =>
          (
            pptx_measure(pptx_attribute(n.element, "cx", ""), 0.0),
            pptx_measure(pptx_attribute(n.element, "cy", ""), 0.0),
          )
        None => (0.0, 0.0)
      }
      Some({
        x,
        y,
        width,
        height,
        rotation: pptx_int64(pptx_attribute(value.element, "rot", ""), 0L).to_double() /
        60000.0,
        flip_h: pptx_bool(value.element, "flipH", false),
        flip_v: pptx_bool(value.element, "flipV", false),
      })
    }
    None => None
  }
}

///|
fn pptx_transform(content : String) -> PptxTransform? raise {
  pptx_transform_node(Some(pptx_parse_xml(content)))
}

///|
priv struct PptxShapeTransform {
  kind : String
  transform : PptxTransform?
} derive(Debug, Eq)

///|
fn pptx_shape_transforms(
  package : @ooxml.OoxmlPackage,
  part : String,
) -> Array[PptxShapeTransform] raise {
  let root = pptx_read_xml(package, part)
  let tree = pptx_child(pptx_child(Some(root), "cSld"), "spTree")
  let output : Array[PptxShapeTransform] = []
  for shape in pptx_children(tree) {
    let kind = shape.element.name.local_name
    let transform = if kind == "graphicFrame" {
      pptx_child(Some(shape), "xfrm")
    } else {
      let container = if kind == "grpSp" { "grpSpPr" } else { "spPr" }
      pptx_child(pptx_child(Some(shape), container), "xfrm")
    }
    output.push({ kind, transform: pptx_transform_node(transform), })
  }
  output
}
