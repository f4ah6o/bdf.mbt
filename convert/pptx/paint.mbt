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
priv struct PptxArrow {
  kind : String
  w : Double
  l : Double
}

///|
priv struct PptxLineStyle {
  width : Double
  color : UInt32
  cap : Byte
  join : Byte
  miter : Double
  dash : Array[Double]
  head : PptxArrow
  tail : PptxArrow
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
fn pptx_arrow_size(value : String) -> Double {
  match value {
    "sm" => 2.0
    "lg" => 5.0
    _ => 3.0
  }
}

///|
fn pptx_parse_arrow(node : PptxXmlNode) -> PptxArrow {
  let kind = pptx_attribute(node.element, "type", "none")
  {
    kind: if kind == "none" { "" } else { kind },
    w: pptx_arrow_size(pptx_attribute(node.element, "w", "med")),
    l: pptx_arrow_size(pptx_attribute(node.element, "len", "med")),
  }
}

///|
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
  let mut head : PptxArrow = { kind: "", w: 3.0, l: 3.0 }
  let mut tail : PptxArrow = { kind: "", w: 3.0, l: 3.0 }
  let mut have_head = false
  let mut have_tail = false
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
    if !have_head {
      match pptx_child(Some(line), "headEnd") {
        Some(value) => {
          head = pptx_parse_arrow(value)
          have_head = true
        }
        None => ()
      }
    }
    if !have_tail {
      match pptx_child(Some(line), "tailEnd") {
        Some(value) => {
          tail = pptx_parse_arrow(value)
          have_tail = true
        }
        None => ()
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
  Some({ width, color, cap, join, miter, dash, head, tail, })
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
fn pptx_path_ends(
  path : @core.Path,
) -> ((Double, Double), (Double, Double), (Double, Double), (Double, Double))? {
  let verbs = path.verbs.to_array()
  let coordinates = path.coordinates
  let mut index = 0
  let mut first_x = 0.0
  let mut first_y = 0.0
  let mut prev_x = 0.0
  let mut prev_y = 0.0
  let mut start_dx = 0.0
  let mut start_dy = 0.0
  let mut end_dx = 0.0
  let mut end_dy = 0.0
  let mut have = false
  let mut closed = false
  for verb in verbs {
    match verb.to_int() {
      0 => {
        if index + 1 < coordinates.length() {
          prev_x = coordinates[index]
          prev_y = coordinates[index + 1]
          if !have {
            first_x = prev_x
            first_y = prev_y
            have = true
          }
        }
        index += 2
      }
      1 => {
        if index + 1 < coordinates.length() {
          let x = coordinates[index]
          let y = coordinates[index + 1]
          if start_dx == 0.0 && start_dy == 0.0 {
            start_dx = x - prev_x
            start_dy = y - prev_y
          }
          end_dx = x - prev_x
          end_dy = y - prev_y
          prev_x = x
          prev_y = y
        }
        index += 2
      }
      2 => {
        if index + 5 < coordinates.length() {
          let c1x = coordinates[index]
          let c1y = coordinates[index + 1]
          let c2x = coordinates[index + 2]
          let c2y = coordinates[index + 3]
          let x = coordinates[index + 4]
          let y = coordinates[index + 5]
          if start_dx == 0.0 && start_dy == 0.0 {
            start_dx = c1x - prev_x
            start_dy = c1y - prev_y
          }
          end_dx = x - c2x
          end_dy = y - c2y
          prev_x = x
          prev_y = y
        }
        index += 6
      }
      3 => {
        if index + 3 < coordinates.length() {
          let cx = coordinates[index]
          let cy = coordinates[index + 1]
          let x = coordinates[index + 2]
          let y = coordinates[index + 3]
          if start_dx == 0.0 && start_dy == 0.0 {
            start_dx = cx - prev_x
            start_dy = cy - prev_y
          }
          end_dx = x - cx
          end_dy = y - cy
          prev_x = x
          prev_y = y
        }
        index += 4
      }
      4 => closed = true
      5 => {
        closed = true
        index += 4
      }
      _ => ()
    }
  }
  if !have || closed || (start_dx == 0.0 && start_dy == 0.0) {
    None
  } else {
    Some(
      ((first_x, first_y), (start_dx, start_dy), (prev_x, prev_y), (end_dx, end_dy)),
    )
  }
}

///|
fn pptx_draw_arrow(
  object : @core.ObjectBuilder,
  line : PptxLineStyle,
  arrow : PptxArrow,
  x : Double,
  y : Double,
  dx : Double,
  dy : Double,
) -> Unit raise {
  let length = (dx * dx + dy * dy).sqrt()
  if arrow.kind == "" || length == 0.0 {
    return
  }
  let ux = dx / length
  let uy = dy / length
  let px = -uy
  let py = ux
  let line_width = Double::max(line.width, 1.0)
  let half_width = arrow.w * line_width / 2.0
  let head_length = arrow.l * line_width
  let point = fn(along : Double, across : Double) -> (Double, Double) {
    (x + ux * along + px * across, y + uy * along + py * across)
  }
  object.fill_color(line.color)
  object.stroke_color(line.color)
  match arrow.kind {
    "arrow" => {
      let a = point(-head_length, half_width)
      let b = point(-head_length, -half_width)
      let path = @core.Inline({
        verbs: b"\x00\x01\x01",
        coordinates: [a.0, a.1, x, y, b.0, b.1],
      })
      pptx_set_line(object, line)
      object.stroke_path(object.add_path(path))
    }
    "oval" => {
      let rx = head_length / 2.0
      let ry = half_width
      let coordinates : Array[Double] = []
      for i in 0..<8 {
        let angle = 6.283185307179586 * i.to_double() / 8.0
        let p = point(rx * @math.cos(angle), ry * @math.sin(angle))
        coordinates.push(p.0)
        coordinates.push(p.1)
      }
      let path = @core.Inline({
        verbs: b"\x00\x01\x01\x01\x01\x01\x01\x01\x04",
        coordinates,
      })
      object.fill_path(object.add_path(path), 0)
    }
    "diamond" => {
      let tip = point(head_length / 2.0, 0.0)
      let right = point(0.0, half_width)
      let back = point(-head_length / 2.0, 0.0)
      let left = point(0.0, -half_width)
      let path = @core.Inline({
        verbs: b"\x00\x01\x01\x01\x04",
        coordinates: [tip.0, tip.1, right.0, right.1, back.0, back.1, left.0, left.1],
      })
      object.fill_path(object.add_path(path), 0)
    }
    "stealth" => {
      let tip = (x, y)
      let a = point(-head_length, half_width)
      let mid = point(-head_length * 0.6, 0.0)
      let b = point(-head_length, -half_width)
      let path = @core.Inline({
        verbs: b"\x00\x01\x01\x01\x04",
        coordinates: [tip.0, tip.1, a.0, a.1, mid.0, mid.1, b.0, b.1],
      })
      object.fill_path(object.add_path(path), 0)
    }
    _ => {
      let a = point(-head_length, half_width)
      let b = point(-head_length, -half_width)
      let path = @core.Inline({
        verbs: b"\x00\x01\x01\x04",
        coordinates: [x, y, a.0, a.1, b.0, b.1],
      })
      object.fill_path(object.add_path(path), 0)
    }
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
  match pptx_path_ends(path) {
    Some((start, start_dir, finish, end_dir)) => {
      if line.head.kind != "" {
        pptx_draw_arrow(
          object, line, line.head, start.0, start.1, -start_dir.0, -start_dir.1,
        )
      }
      if line.tail.kind != "" {
        pptx_draw_arrow(
          object, line, line.tail, finish.0, finish.1, end_dir.0, end_dir.1,
        )
      }
    }
    None => ()
  }
}

///|
/// The geometry a shape or the placeholder it inherits from names, as
/// upstream shape.geometry reads it: the first spPr with a:prstGeom or
/// a:custGeom, with the preset preferred inside one spPr.
fn pptx_shape_geometry_node(
  shape : PptxXmlNode,
  inherited : Array[PptxXmlNode],
) -> PptxGeometryNode? {
  let own = shape.element.name.local_name
  let sp_pr = if own == "grpSp" || own == "wgp" {
    pptx_child(Some(shape), "grpSpPr")
  } else {
    pptx_child(Some(shape), "spPr")
  }
  let properties : Array[PptxXmlNode?] = [sp_pr]
  for node in inherited {
    properties.push(pptx_child(Some(node), "spPr"))
  }
  for sp in properties {
    match pptx_child(sp, "prstGeom") {
      Some(value) => return Some(PptxPresetGeometry(value))
      None => ()
    }
    match pptx_child(sp, "custGeom") {
      Some(value) => return Some(PptxCustomGeometry(value))
      None => ()
    }
  }
  None
}
