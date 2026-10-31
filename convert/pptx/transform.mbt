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

///|
fn pptx_matrix_fma(a : Double, b : Double, c : Double) -> Double {
  if a == 0.0 || b == 0.0 {
    a * b + c
  } else {
    @core.fused_multiply_add(a, b, c)
  }
}

///|
fn pptx_matrix_mul(
  first : (Double, Double, Double, Double, Double, Double),
  second : (Double, Double, Double, Double, Double, Double),
) -> (Double, Double, Double, Double, Double, Double) {
  let (a, b, c, d, e, f) = first
  let (g, h, i, j, k, l) = second
  (
    pptx_matrix_fma(a, g, c * h),
    pptx_matrix_fma(b, g, d * h),
    pptx_matrix_fma(a, i, c * j),
    pptx_matrix_fma(b, i, d * j),
    pptx_matrix_fma(a, k, c * l) + e,
    pptx_matrix_fma(b, k, d * l) + f,
  )
}

///|
fn PptxTransform::matrix(
  self : PptxTransform,
  text : Bool,
) -> (Double, Double, Double, Double, Double, Double) {
  let rotation = if text && self.flip_v {
    self.rotation + 180.0
  } else {
    self.rotation
  }
  if rotation == 0.0 && (text || (!self.flip_h && !self.flip_v)) {
    return (1.0, 0.0, 0.0, 1.0, self.x, self.y)
  }
  let radians = rotation * 3.141592653589793 / 180.0
  let sine = @math.sin(radians)
  let cosine = @math.cos(radians)
  let center = (
    1.0,
    0.0,
    0.0,
    1.0,
    self.x + self.width / 2.0,
    self.y + self.height / 2.0,
  )
  let rotate = (cosine, sine, -sine, cosine, 0.0, 0.0)
  let horizontal = if !text && self.flip_h { -1.0 } else { 1.0 }
  let vertical = if !text && self.flip_v { -1.0 } else { 1.0 }
  let flip = (horizontal, 0.0, 0.0, vertical, 0.0, 0.0)
  let origin = (1.0, 0.0, 0.0, 1.0, -self.width / 2.0, -self.height / 2.0)
  let placed = pptx_matrix_mul(center, rotate)
  let placed = if text { placed } else { pptx_matrix_mul(placed, flip) }
  pptx_matrix_mul(placed, origin)
}
