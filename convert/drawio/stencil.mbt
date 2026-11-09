///|
/// The draw.io stencil library and stencil rendering, a port of the
/// upstream converter's stencil.go and stencil_registry.go. mxStencil XML
/// shapes (the `<shapes>` files draw.io loads for `mxgraph.*` names) are
/// parsed once, then baked into a @cad.Drawing per cell style and
/// appended to the page drawing with the cell's aspect transform.

///|
/// A parsed `<shape>` element of a stencil library.
priv struct DrawioStencil {
  name : String
  w0 : Double
  h0 : Double
  ///| "fixed" keeps the proportions, "variable" stretches.
  aspect : String
  strokewidth : String
  bg : DrawioNode?
  fg : DrawioNode?
}

///|
/// file name -> (registry name -> stencil). Files are parsed lazily.
let drawio_stencil_files : Map[String, Map[String, DrawioStencil]] = Map([])

///|
/// Baked drawings, keyed by stencil name and the cell style that colors it.
let drawio_stencil_baked : Map[String, @cad.Drawing] = Map([])

///|
/// The library files embedded for stencil lookup, the subset of the
/// upstream registry this converter ships (aws4 for the AWS samples).
fn drawio_stencil_file_for(base : String) -> String? {
  match base {
    "aws4" | "aws4b" => Some("aws4")
    _ => None
  }
}

///|
/// The stencil behind a `mxgraph.*` shape name, or None (lookupStencil).
fn drawio_stencil_lookup(name : String) -> DrawioStencil? {
  if name.has_prefix("stencil(") {
    return None
  }
  let mut last = -1
  let mut index = 0
  while index < name.length() {
    if name[index].unsafe_to_char() == '.' {
      last = index
    }
    index += 1
  }
  if !name.has_prefix("mxgraph.") || last <= 8 || last + 1 >= name.length() {
    return None
  }
  let base = name[8:last].to_owned()
  let file = match drawio_stencil_file_for(base) {
    Some(f) => f
    None => return None
  }
  let shapes = drawio_stencil_load(file)
  match shapes.get(name) {
    Some(st) => Some(st)
    None => None
  }
}

///|
/// Parse the embedded library file (aws4.xml.gz) into its shapes.
fn drawio_stencil_load(file : String) -> Map[String, DrawioStencil] {
  match drawio_stencil_files.get(file) {
    Some(shapes) => return shapes
    None => ()
  }
  let out : Map[String, DrawioStencil] = Map([])
  let xml = match file {
    "aws4" => @gzip.decompress(drawio_aws4_stencil_gz()[:]) catch { _ => b"" }
    _ => b""
  }
  if xml.length() > 0 {
    let text = @utf8.decode_lossy(xml[:].to_owned())
    let root = drawio_parse(text) catch { _ => {
      name: "", attrs: Map([]), children: [], text: StringBuilder(),
    } }
    drawio_stencil_collect(root, out)
  }
  drawio_stencil_files[file] = out
  out
}

///|
/// Register the `<shape>` children of a `<shapes>`/`<stencils>` element
/// under their registry names (parseStencilSet).
fn drawio_stencil_collect(node : DrawioNode, out : Map[String, DrawioStencil]) -> Unit {
  if node.name == "stencils" {
    for child in node.children {
      if child.name == "shapes" {
        drawio_stencil_collect(child, out)
      }
    }
    return
  }
  if node.name != "shapes" {
    return
  }
  let pkg = drawio_attr(node, "name", "").to_lower() + "."
  for child in node.children {
    if child.name != "shape" {
      continue
    }
    let shape_name = drawio_attr(child, "name", "")
    if shape_name == "" {
      continue
    }
    let registry = pkg + shape_name.to_lower().replace_all(old=" ", new="_")
    let mut w0 = 100.0
    let mut h0 = 100.0
    if drawio_attr(child, "w", "") != "" {
      w0 = drawio_number_js(drawio_attr(child, "w", ""))
    }
    if drawio_attr(child, "h", "") != "" {
      h0 = drawio_number_js(drawio_attr(child, "h", ""))
    }
    out[registry] = {
      name: shape_name,
      w0,
      h0,
      aspect: drawio_attr(child, "aspect", "variable"),
      strokewidth: drawio_attr(child, "strokewidth", "1"),
      bg: drawio_find(child, "background"),
      fg: drawio_find(child, "foreground"),
    }
  }
}

///|
/// What a stencil bake needs from the cell: the resolved style, the cell's
/// paint colors and the label-related flags.
priv struct DrawioStencilContext {
  style : Map[String, String]
  ///| Raw style string, for "key=none" lookups.
  style_str : String
  stroke : String
  fill : String
  font_color : String
  stroke_width : Double
  fill_opacity : Double
  stroke_opacity : Double
  outline : Bool
  warn : DrawioWarn
}

///|
/// Draw a `mxgraph.*` cell's stencil, or return false when the name is not
/// a stencil we can draw (drawio_stencil_draw + the shape paint's rotate
/// and flip).
fn drawio_stencil_render(
  cell : DrawioCell,
  drawing : @cad.Drawing,
  warn : DrawioWarn,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Bool {
  let name = drawio_shape_name(cell.style)
  if !name.has_prefix("mxgraph.") {
    return false
  }
  let composite = drawio_aws4_is_composite(name)
  let st = if composite {
    None
  } else {
    match drawio_stencil_lookup(name) {
      Some(value) => Some(value)
      None => return false
    }
  }
  if w <= 0.0 || h <= 0.0 {
    return true
  }
  let resolved = drawio_parse_style(cell.style, edge=false)
  let fill = drawio_color_string(drawio_style(cell.style, "fillColor", ""), "#ffffff")
  let stroke = drawio_color_string(drawio_style(cell.style, "strokeColor", ""), "#000000")
  let ctx = {
    style: resolved,
    style_str: cell.style,
    stroke,
    fill,
    font_color: drawio_style(cell.style, "fontColor", "black"),
    stroke_width: drawio_num_from_style(cell.style, "strokeWidth", 1.0),
    fill_opacity: drawio_num_from_style(cell.style, "fillOpacity", 100.0) / 100.0,
    stroke_opacity: drawio_num_from_style(cell.style, "strokeOpacity", 100.0) / 100.0,
    outline: drawio_style(cell.style, "outline", "0") == "1",
    warn,
  }
  if composite {
    return drawio_aws4_composite(cell, drawing, ctx, x, y, w, h)
  }
  let st = match st {
    Some(value) => value
    None => return false
  }
  let baked = drawio_stencil_bake(st, name, ctx)
  // computeAspect: the transform from stencil coordinates into the cell.
  let (x0, y0, sx, sy) = drawio_stencil_aspect(st, ctx.style, x, y, w, h)
  // The cell's rotation and flips about its center (mxShape paint).
  let cx = x + w / 2.0
  let cy = y + h / 2.0
  let rotation = drawio_num_from_style(cell.style, "rotation", 0.0)
  let flip_h = drawio_style(cell.style, "flipH", "0") == "1" ||
    drawio_style(cell.style, "stencilFlipH", "0") == "1"
  let flip_v = drawio_style(cell.style, "flipV", "0") == "1" ||
    drawio_style(cell.style, "stencilFlipV", "0") == "1"
  let mut m = @canvas.Matrix::identity()
  if rotation != 0.0 || flip_h || flip_v {
    m = m.mul(
      @canvas.Matrix::translate(cx, cy).mul(
        @canvas.Matrix::rotate(rotation),
      ).mul(@canvas.Matrix::translate(-cx, -cy)),
    )
    if flip_h || flip_v {
      m = m.mul(
        @canvas.Matrix::translate(cx, cy).mul(
          @canvas.Matrix::scale(if flip_h { -1.0 } else { 1.0 }, if flip_v { -1.0 } else { 1.0 }),
        ).mul(@canvas.Matrix::translate(-cx, -cy)),
      )
    }
  }
  m = m.mul(@canvas.Matrix::translate(x0, y0)).mul(@canvas.Matrix::scale(sx, sy))
  drawing.append(baked, m, None)
  true
}

///|
/// Bake a stencil into a drawing in stencil coordinates. The result is
/// cached on the colors that were baked in.
fn drawio_stencil_bake(
  st : DrawioStencil,
  registry_name : String,
  ctx : DrawioStencilContext,
) -> @cad.Drawing {
  let key = registry_name + "|" + ctx.fill + "|" + ctx.stroke + "|" +
    ctx.font_color + "|" + ctx.fill_opacity.to_string() + "|" +
    ctx.stroke_opacity.to_string() + "|" + ctx.stroke_width.to_string() + "|" +
    ctx.style_str
  match drawio_stencil_baked.get(key) {
    Some(d) => return d
    None => ()
  }
  let drawing = @cad.Drawing::new()
  let canvas = DrawioStencilCanvas::new(drawing, ctx.warn)
  canvas.set_fill_color(ctx.fill)
  canvas.set_stroke_color(ctx.stroke)
  canvas.set_alpha(1.0)
  canvas.set_fill_alpha(ctx.fill_opacity)
  canvas.set_stroke_alpha(ctx.stroke_opacity)
  if st.strokewidth == "inherit" {
    canvas.set_stroke_width(ctx.stroke_width)
  } else {
    canvas.set_stroke_width(drawio_number_js(st.strokewidth))
  }
  let painter = { canvas, base: 0, depth: 0, nest: 0, ctx }
  drawio_stencil_children(st, st.bg, painter, false)
  let disable_shadow = !ctx.outline ||
    drawio_num_from_style(ctx.style_str, "backgroundOutline", 0.0) == 0.0
  drawio_stencil_children(st, st.fg, painter, disable_shadow)
  drawio_stencil_baked[key] = drawing
  drawing
}

///|
fn drawio_stencil_children(
  st : DrawioStencil,
  node : DrawioNode?,
  painter : DrawioStencilPainter,
  disable_shadow : Bool,
) -> Unit {
  match node {
    Some(n) =>
      for child in n.children {
        drawio_stencil_node(st, child, painter, true, disable_shadow)
      }
    None => ()
  }
}

///|
/// The painter state shared while walking a stencil tree.
priv struct DrawioStencilPainter {
  canvas : DrawioStencilCanvas
  base : Int
  mut depth : Int
  mut nest : Int
  ctx : DrawioStencilContext
}

///|
fn drawio_stencil_node(
  st : DrawioStencil,
  node : DrawioNode,
  painter : DrawioStencilPainter,
  paint : Bool,
  disable_shadow : Bool,
) -> Unit {
  let c = painter.canvas
  let name = node.name
  if name == "save" {
    c.save()
    return
  }
  if name == "restore" {
    c.restore(painter.base)
    return
  }
  if !paint {
    return
  }
  if painter.nest >= 256 {
    painter.ctx.warn.once("stencil-deep", "deeply nested stencil shape is truncated")
    return
  }
  painter.nest += 1
  // Coordinates are in stencil units: the aspect transform is applied by
  // the matrix the baked drawing is appended with.
  let num = fn(key : String) -> Double { drawio_number_js(drawio_attr(node, key, "")) }
  match name {
    "path" => {
      c.begin()
      // Compact path data (the `d` attribute) or child step elements.
      let d = drawio_attr(node, "d", "")
      if d != "" {
        drawio_stencil_path_d(c, d)
      } else {
        for child in node.children {
          drawio_stencil_step(c, child)
        }
      }
    }
    "close" => c.close()
    "move" => c.move_to(num("x"), num("y"))
    "line" => c.line_to(num("x"), num("y"))
    "quad" => c.quad_to(num("x1"), num("y1"), num("x2"), num("y2"))
    "curve" => c.curve_to(num("x1"), num("y1"), num("x2"), num("y2"), num("x3"), num("y3"))
    "arc" =>
      c.arc_to(
        num("rx"), num("ry"), num("x-axis-rotation"),
        num("large-arc-flag") != 0.0, num("sweep-flag") != 0.0,
        num("x"), num("y"),
      )
    "rect" => c.rect(num("x"), num("y"), num("w"), num("h"))
    "roundrect" => {
      let arcsize = if num("arcsize") == 0.0 { 30.0 } else { num("arcsize") }
      let w = num("w")
      let h = num("h")
      let r = Double::min(w * arcsize / 100.0, h * arcsize / 100.0)
      c.roundrect(num("x"), num("y"), w, h, r, r)
    }
    "ellipse" => c.ellipse(num("x"), num("y"), num("w"), num("h"))
    "fillstroke" => c.fill_and_stroke()
    "fill" => c.fill()
    "stroke" => c.stroke()
    "strokewidth" => c.set_stroke_width(num("width"))
    "dashed" => c.set_dashed(drawio_attr(node, "dashed", "") == "1", false)
    "dashpattern" => {
      let pattern = drawio_attr(node, "pattern", "")
      if pattern != "" {
        c.set_dash_pattern(pattern)
      }
    }
    "strokecolor" => c.set_stroke_color(drawio_stencil_color(node, painter.ctx))
    "linecap" => c.set_line_cap(drawio_attr(node, "cap", "flat"))
    "linejoin" => c.set_line_join(drawio_attr(node, "join", "miter"))
    "miterlimit" => c.set_miter_limit(num("limit"))
    "fillcolor" => c.set_fill_color(drawio_stencil_color(node, painter.ctx))
    "alpha" | "fillalpha" | "strokealpha" => c.set_alpha(num("alpha"))
    "image" =>
      painter.ctx.warn.once("stencil-image", "images inside stencil shapes are not drawn")
    "text" =>
      painter.ctx.warn.once("stencil-text", "text in stencil shapes is not drawn")
    "include-shape" => {
      let sub = drawio_stencil_lookup(drawio_attr(node, "name", ""))
      match sub {
        Some(sub_st) if painter.depth < 8 => {
          painter.depth += 1
          drawio_stencil_children(sub_st, sub_st.bg, painter, disable_shadow)
          drawio_stencil_children(sub_st, sub_st.fg, painter, disable_shadow)
          painter.depth -= 1
        }
        _ => ()
      }
    }
    _ => ()
  }
  if disable_shadow && (name == "fillstroke" || name == "fill" || name == "stroke") {
    c.set_shadow(false)
  }
  painter.nest -= 1
}

///|
/// One step element of a path (move/line/quad/curve/arc/close).
fn drawio_stencil_step(c : DrawioStencilCanvas, node : DrawioNode) -> Unit {
  let num = fn(key : String) -> Double { drawio_number_js(drawio_attr(node, key, "")) }
  match node.name {
    "close" => c.close()
    "move" => c.move_to(num("x"), num("y"))
    "line" => c.line_to(num("x"), num("y"))
    "quad" => c.quad_to(num("x1"), num("y1"), num("x2"), num("y2"))
    "curve" => c.curve_to(num("x1"), num("y1"), num("x2"), num("y2"), num("x3"), num("y3"))
    "arc" =>
      c.arc_to(
        num("rx"), num("ry"), num("x-axis-rotation"),
        num("large-arc-flag") != 0.0, num("sweep-flag") != 0.0,
        num("x"), num("y"),
      )
    _ => ()
  }
}

///|
/// Parse a compact `d` path: letters M L Q C A Z followed by their
/// space-separated numbers (gen-drawio-stencils' format).
fn drawio_stencil_path_d(c : DrawioStencilCanvas, d : String) -> Unit {
  let arg_count = fn(letter : Char) -> Int {
    match letter {
      'M' | 'L' => 2
      'Q' => 4
      'C' => 6
      'A' => 7
      'Z' => 0
      _ => -1
    }
  }
  let mut i = 0
  while i < d.length() {
    let letter = d[i].unsafe_to_char()
    let count = arg_count(letter)
    if count < 0 {
      i += 1
      continue
    }
    i += 1
    if letter == 'Z' {
      c.close()
      continue
    }
    let args : Array[Double] = []
    while args.length() < count && i < d.length() {
      while i < d.length() &&
        (d[i].unsafe_to_char() == ' ' || d[i].unsafe_to_char() == '\t' ||
         d[i].unsafe_to_char() == '\n') {
        i += 1
      }
      let start = i
      // Numbers end at whitespace or the next command letter; 'e'/'E' stay
      // inside numbers (exponents) and are never path commands.
      while i < d.length() {
        let ch = d[i].unsafe_to_char()
        if ch == ' ' || ch == '\t' || ch == '\n' {
          break
        }
        if ch.is_ascii_alphabetic() && ch != 'e' && ch != 'E' {
          break
        }
        i += 1
      }
      args.push(drawio_number_js(d[start:i].to_owned()))
    }
    if args.length() < count {
      break
    }
    match letter {
      'M' => c.move_to(args[0], args[1])
      'L' => c.line_to(args[0], args[1])
      'Q' => c.quad_to(args[0], args[1], args[2], args[3])
      'C' => c.curve_to(args[0], args[1], args[2], args[3], args[4], args[5])
      'A' =>
        c.arc_to(
          args[0], args[1], args[2], args[3] != 0.0, args[4] != 0.0, args[5], args[6],
        )
      _ => ()
    }
  }
}

///|
/// The color a strokecolor/fillcolor element sets (mxStencil.parseColor):
/// "default" is the theme's white/black, "stroke"/"fill"/"font" the cell's
/// colors, a style key its value, else a CSS color. "" means none.
fn drawio_stencil_color(node : DrawioNode, ctx : DrawioStencilContext) -> String {
  let value = drawio_attr(node, "color", "")
  let result = if value == "default" {
    if node.name == "fillcolor" { "#ffffff" } else { "#000000" }
  } else if value == "stroke" {
    ctx.stroke
  } else if value == "fill" {
    ctx.fill
  } else if value == "font" {
    ctx.font_color
  } else if drawio_color_valid(value) {
    value
  } else {
    // A style key, possibly with a default attribute.
    let has_def = node.attrs.contains("default")
    let def = drawio_attr(node, "default", "")
    let mut resolved : String? = ctx.style.get(value)
    if resolved is None {
      // A "key=none" in the raw style still counts (getStyleWithNone).
      for tok in ctx.style_str.split(";") {
        let eq = tok.find("=")
        if eq is Some(i) && tok[:i].to_owned() == value {
          let v = tok[i + 1:].to_owned()
          resolved = Some(v)
        }
      }
      if resolved is None && has_def {
        resolved = Some(def)
      }
    } else {
      match resolved {
        Some("default") =>
          if has_def && def != "none" {
            resolved = Some(def)
          }
        _ => ()
      }
    }
    match resolved {
      Some(v) => v
      None => ""
    }
  }
  if result == "none" || result == "transparent" {
    ""
  } else {
    result
  }
}

///|
/// A style color string as a CSS color for the stencil canvas (the
/// resolved style already replaced "default" with white/black).
fn drawio_color_string(value : String, fallback : String) -> String {
  let t = sfc_drawio_trim(value)
  if t == "" || t == "none" {
    return fallback
  }
  t
}
