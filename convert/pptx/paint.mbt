///|
// Shape fills and outlines: the spPr chain of a shape and its placeholders,
// the p:style references and the theme's fill and line style matrices.

///|
/// A resolved shape fill.
priv enum PptxPaint {
  PptxPaintNone
  /// A solid fill and its optional alpha.
  PptxPaintSolid(UInt32, Double?)
  /// A gradient fill with the theme (including phClr) it resolves against.
  PptxPaintGradient(PptxXmlNode, Map[String, UInt32])
}

///|
/// A resolved shape outline.
priv struct PptxLineStyle {
  width : Double
  color : UInt32
  cap : Byte
  join : Byte
  miter : Double
  dash : Array[Double]
}

///|
/// The fill choice element among a node's children, or nil.
fn pptx_fill_element(node : PptxXmlNode?) -> PptxXmlNode? {
  for child in pptx_children(node) {
    match child.element.name.local_name {
      "noFill"
      | "solidFill"
      | "gradFill"
      | "blipFill"
      | "pattFill"
      | "grpFill" => return Some(child)
      _ => ()
    }
  }
  None
}

///|
/// The alpha of a solid fill color, whatever color child it holds.
fn pptx_solid_alpha(solid : PptxXmlNode?) -> Double? {
  let color = match pptx_child(solid, "srgbClr") {
    Some(value) => Some(value)
    None => pptx_child(solid, "schemeClr")
  }
  match pptx_child(color, "alpha") {
    Some(value) =>
      match pptx_attribute(value.element, "val", "") {
        "" => None
        text =>
          Some((@string.parse_double(text) catch { _ => 100000.0 }) / 100000.0)
      }
    None => None
  }
}

///|
/// The theme with a phClr entry, the color a p:style reference supplies to
/// the theme style it names.
fn pptx_theme_with_ph(
  theme : Map[String, UInt32],
  ph : UInt32?,
) -> Map[String, UInt32] {
  match ph {
    Some(color) => {
      let copy = theme.copy()
      copy["phClr"] = color
      copy
    }
    None => theme
  }
}

///|
fn pptx_resolve_paint(
  fill : PptxXmlNode,
  theme : Map[String, UInt32],
  ph : UInt32?,
) -> PptxPaint {
  match fill.element.name.local_name {
    "solidFill" => {
      let resolved = pptx_theme_with_ph(theme, ph)
      match pptx_solid_color(Some(fill), resolved) {
        Some(color) => PptxPaintSolid(color, pptx_solid_alpha(Some(fill)))
        None => PptxPaintNone
      }
    }
    "gradFill" => PptxPaintGradient(fill, pptx_theme_with_ph(theme, ph))
    _ => PptxPaintNone
  }
}

///|
/// The p:style element of a shape or of the placeholder it inherits from.
fn pptx_shape_style(
  shape : PptxXmlNode,
  inherited : Array[PptxXmlNode],
) -> PptxXmlNode? {
  match pptx_child(Some(shape), "style") {
    Some(value) => Some(value)
    None => {
      for node in inherited {
        match pptx_child(Some(node), "style") {
          Some(value) => return Some(value)
          None => ()
        }
      }
      None
    }
  }
}

///|
fn pptx_style_ref_index(reference : PptxXmlNode) -> Int32 {
  @string.parse_int(pptx_attribute(reference.element, "idx", "0")) catch {
    _ => 0
  }
}

///|
/// The solid color a p:style reference names for its theme entry.
fn pptx_style_ref_color(
  reference : PptxXmlNode,
  theme : Map[String, UInt32],
) -> UInt32? {
  pptx_solid_color(Some(reference), theme)
}

///|
fn pptx_theme_style_entry(
  list : Array[PptxXmlNode],
  index : Int32,
) -> PptxXmlNode? {
  if index < 0 || index >= list.length() {
    None
  } else {
    Some(list[index])
  }
}

///|
/// Resolve a shape's fill through its own properties, its placeholders and
/// then its p:style fill reference.
fn pptx_shape_paint(
  ctx : PptxShapeContext,
  shape : PptxXmlNode,
  inherited : Array[PptxXmlNode],
) -> PptxPaint {
  let own = shape.element.name.local_name
  let sp_pr = if own == "grpSp" || own == "wgp" {
    pptx_child(Some(shape), "grpSpPr")
  } else {
    pptx_child(Some(shape), "spPr")
  }
  let chain : Array[PptxXmlNode?] = [sp_pr]
  for node in inherited {
    chain.push(pptx_child(Some(node), "spPr"))
  }
  for sp in chain {
    match pptx_fill_element(sp) {
      Some(fill) => return pptx_resolve_paint(fill, ctx.theme, None)
      None => ()
    }
  }
  let style = pptx_shape_style(shape, inherited)
  let reference = match style {
    Some(value) => pptx_child(Some(value), "fillRef")
    None => None
  }
  let reference = match reference {
    Some(value) => value
    None => return PptxPaintNone
  }
  let index = pptx_style_ref_index(reference)
  if index <= 0 {
    return PptxPaintNone
  }
  let ph = pptx_style_ref_color(reference, ctx.theme)
  let entry = if index >= 1001 {
    pptx_theme_style_entry(ctx.theme_bg_fills, index - 1001)
  } else {
    pptx_theme_style_entry(ctx.theme_fills, index - 1)
  }
  match entry {
    Some(fill) => pptx_resolve_paint(fill, ctx.theme, ph)
    None =>
      match ph {
        Some(color) => PptxPaintSolid(color, None)
        None => PptxPaintNone
      }
  }
}

///|
/// The preset dash pattern, in multiples of the line width.
fn pptx_preset_dash(value : String) -> Array[Double] {
  match value {
    "dot" => [1.0, 3.0]
    "dash" => [4.0, 3.0]
    "lgDash" => [8.0, 3.0]
    "dashDot" => [4.0, 3.0, 1.0, 3.0]
    "lgDashDot" => [8.0, 3.0, 1.0, 3.0]
    "lgDashDotDot" => [8.0, 3.0, 1.0, 3.0, 1.0, 3.0]
    "sysDash" => [3.0, 1.0]
    "sysDot" => [1.0, 1.0]
    "sysDashDot" => [3.0, 1.0, 1.0, 1.0]
    "sysDashDotDot" => [3.0, 1.0, 1.0, 1.0, 1.0, 1.0]
    _ => []
  }
}

///|
/// Merge a:ln elements (most specific first) and the theme's line style a
/// p:style lnRef names, as upstream resolveLine does. nil when the shape has
/// no visible outline.
fn pptx_shape_line(
  ctx : PptxShapeContext,
  shape : PptxXmlNode,
  inherited : Array[PptxXmlNode],
) -> PptxLineStyle? {
  let own = shape.element.name.local_name
  let sp_pr = if own == "grpSp" || own == "wgp" {
    pptx_child(Some(shape), "grpSpPr")
  } else {
    pptx_child(Some(shape), "spPr")
  }
  let lines : Array[PptxXmlNode] = []
  let chain : Array[PptxXmlNode?] = [sp_pr]
  for node in inherited {
    chain.push(pptx_child(Some(node), "spPr"))
  }
  for sp in chain {
    match pptx_child(sp, "ln") {
      Some(line) => lines.push(line)
      None => ()
    }
  }
  let mut theme_index = -1
  let mut ref_ph : UInt32? = None
  let style = pptx_shape_style(shape, inherited)
  match style {
    Some(value) =>
      match pptx_child(Some(value), "lnRef") {
        Some(reference) => {
          let index = pptx_style_ref_index(reference)
          if index > 0 {
            match pptx_theme_style_entry(ctx.theme_lines, index - 1) {
              Some(line) => {
                theme_index = lines.length()
                lines.push(line)
                ref_ph = pptx_style_ref_color(reference, ctx.theme)
              }
              None => ()
            }
          }
        }
        None => ()
      }
    None => ()
  }
  if lines.is_empty() {
    return None
  }
  let mut width = -1.0
  let mut paint : PptxPaint = PptxPaintNone
  let mut have_fill = false
  let mut cap : Byte = 0
  let mut join : Byte = 0
  let mut miter = 8.0
  let mut dash : Array[Double] = []
  let mut have_dash = false
  let mut have_cap = false
  let mut have_join = false
  for i, line in lines {
    if width < 0.0 {
      match pptx_attribute(line.element, "w", "") {
        "" => ()
        value =>
          width = (@string.parse_double(value) catch { _ => 0.0 }) / 12700.0
      }
    }
    let ph = if i == theme_index { ref_ph } else { None }
    if !have_fill {
      match pptx_fill_element(Some(line)) {
        Some(fill) => {
          paint = pptx_resolve_paint(fill, ctx.theme, ph)
          have_fill = true
        }
        None => ()
      }
    }
    if !have_cap {
      match pptx_attribute(line.element, "cap", "") {
        "" => ()
        value => {
          have_cap = true
          cap = if value == "rnd" { 1 } else if value == "sq" { 2 } else { 0 }
        }
      }
    }
    if !have_join {
      if pptx_child(Some(line), "round") is Some(_) {
        join = 1
        have_join = true
      } else if pptx_child(Some(line), "bevel") is Some(_) {
        join = 2
        have_join = true
      } else if pptx_child(Some(line), "miter") is Some(_) {
        join = 0
        have_join = true
        miter = match pptx_child(Some(line), "miter") {
          Some(value) =>
            (@string.parse_double(pptx_attribute(value.element, "lim", "0")) catch {
              _ => 0.0
            }) /
            100000.0
          None => 8.0
        }
        if miter <= 0.0 {
          miter = 8.0
        }
      }
    }
    if !have_dash {
      match pptx_child(Some(line), "prstDash") {
        Some(value) => {
          dash = pptx_preset_dash(pptx_attribute(value.element, "val", "solid"))
          have_dash = true
        }
        None =>
          match pptx_child(Some(line), "custDash") {
            Some(value) => {
              have_dash = true
              for segment in pptx_children(pptx_child(Some(value), "ds")) {
                dash.push(
                  (@string.parse_double(
                    pptx_attribute(segment.element, "d", "1"),
                  ) catch {
                    _ => 1.0
                  }) /
                  100000.0,
                )
                dash.push(
                  (@string.parse_double(
                    pptx_attribute(segment.element, "sp", "1"),
                  ) catch {
                    _ => 1.0
                  }) /
                  100000.0,
                )
              }
            }
            None => ()
          }
      }
    }
  }
  let color = match paint {
    PptxPaintSolid(color, _) => color
    _ => return None
  }
  if width < 0.0 {
    width = 0.75
  }
  if width == 0.0 {
    width = 0.5
  }
  Some({ width, color, cap, join, miter, dash, })
}

///|
/// A color in linear light, so that lighten and darken match upstream.
fn pptx_to_linear(value : Double) -> Double {
  if value <= 0.04045 {
    value / 12.92
  } else {
    @math.pow((value + 0.055) / 1.055, 2.4)
  }
}

///|
fn pptx_from_linear(value : Double) -> Double {
  let clamped = Double::min(1.0, Double::max(0.0, value))
  if clamped <= 0.0031308 {
    clamped * 12.92
  } else {
    1.055 * @math.pow(clamped, 1.0 / 2.4) - 0.055
  }
}

///|
/// Apply a path's lighten or darken fill mode to a solid color.
fn pptx_adjust_fill_color(color : UInt32, mode : String) -> UInt32 {
  match mode {
    "darken" | "darkenLess" | "lighten" | "lightenLess" => ()
    _ => return color
  }
  let factor = if mode == "darken" || mode == "lighten" { 0.6 } else { 0.8 }
  let shade = mode == "darken" || mode == "darkenLess"
  let channel = fn(shift : Int32) -> Double {
    let value = pptx_color_channel(color, shift) / 255.0
    let linear = pptx_to_linear(value)
    let adjusted = if shade {
      linear * factor
    } else {
      1.0 - (1.0 - linear) * factor
    }
    pptx_from_linear(adjusted) * 255.0
  }
  pptx_pack_color(channel(24), channel(16), channel(8))
}

///|
/// The corner radius of a roundRect, from its adjust value.
fn pptx_round_rect_radius(
  geom : PptxXmlNode?,
  width : Double,
  height : Double,
) -> Double {
  let fraction = match pptx_child(pptx_child(geom, "avLst"), "gd") {
    Some(value) => {
      let fmla = pptx_attribute(value.element, "fmla", "val 16667")
      let token = match fmla.split(" ").last() {
        Some(value) => value.to_owned()
        None => "16667"
      }
      (@string.parse_double(token) catch { _ => 16667.0 }) / 100000.0
    }
    None => 0.16667
  }
  fraction * Double::min(width, height)
}

///|
/// A preset path placed at a shape position and turned around a center.
fn pptx_geometry_path_at(
  path : @core.Path,
  x : Double,
  y : Double,
  rotation : Double,
  center_x : Double,
  center_y : Double,
) -> @core.Path {
  pptx_rotate_path(
    pptx_translate_path(path, x, y),
    center_x,
    center_y,
    rotation,
  )
}

///|
fn pptx_set_line(object : @core.ObjectBuilder, line : PptxLineStyle) -> Unit {
  object.line(
    Float::from_double(line.width),
    line.cap,
    line.join,
    Float::from_double(line.miter),
  )
  if !line.dash.is_empty() {
    let segments : Array[Float] = []
    for segment in line.dash {
      segments.push(Float::from_double(segment * line.width))
    }
    object.dash(segments, 0.0F)
  }
  object.stroke_color(line.color)
}

///|
fn pptx_fill_geometry_path(
  object : @core.ObjectBuilder,
  paint : PptxPaint,
  gradient : @core.Paint?,
  path : @core.Path,
) -> Unit raise {
  match paint {
    PptxPaintSolid(color, _) => {
      object.fill_color(color)
      object.fill_path(object.add_path(@core.Inline(path)), 0)
    }
    PptxPaintGradient(_, _) =>
      match gradient {
        Some(value) => {
          object.fill_paint(object.add_paint(value))
          object.fill_path(object.add_path(@core.Inline(path)), 0)
        }
        None => ()
      }
    PptxPaintNone => ()
  }
}

///|
fn pptx_stroke_geometry_path(
  object : @core.ObjectBuilder,
  line : PptxLineStyle,
  path : @core.Path,
) -> Unit raise {
  pptx_set_line(object, line)
  object.stroke_path(object.add_path(@core.Inline(path)))
}

///|
/// The preset geometry a shape or the placeholder it inherits from names.
fn pptx_shape_geometry_node(
  shape : PptxXmlNode,
  inherited : Array[PptxXmlNode],
) -> PptxXmlNode? {
  let own = shape.element.name.local_name
  let sp_pr = if own == "grpSp" || own == "wgp" {
    pptx_child(Some(shape), "grpSpPr")
  } else {
    pptx_child(Some(shape), "spPr")
  }
  match pptx_child(sp_pr, "prstGeom") {
    Some(value) => return Some(value)
    None => ()
  }
  for node in inherited {
    match pptx_child(pptx_child(Some(node), "spPr"), "prstGeom") {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}
