///|
/// The graphics state that Canvas save/restore keeps.
struct PdfGState {
  mut matrix : @render.Matrix
  mut fill_color : Int32
  mut stroke_color : Int32
  mut fill_paint : Int32?
  mut stroke_paint : Int32?
  mut line_width : Double
  mut line_cap : Int32
  mut line_join : Int32
  mut miter : Double
  mut dash : String
  mut alpha : Double
  mut font_index : Int32
  mut font_size : Double
  mut align : Int32
}

///|
fn PdfGState::new() -> PdfGState {
  {
    matrix: (1.0, 0.0, 0.0, 1.0, 0.0, 0.0),
    fill_color: 0xff000000U.reinterpret_as_int(),
    stroke_color: 0xff000000U.reinterpret_as_int(),
    fill_paint: None,
    stroke_paint: None,
    line_width: 1.0,
    line_cap: 0,
    line_join: 0,
    miter: 10.0,
    dash: "[] 0 d",
    alpha: 1.0,
    font_index: -1,
    font_size: 12.0,
    align: 0,
  }
}

///|
struct ContentState {
  out : StringBuilder
  document : @core.Document
  resources : PdfResources
  height : Double
  annots : Array[Int32]
  mut gs : PdfGState
  stack : Array[PdfGState]
  warnings : Array[String]
  mut gradient_warned : Bool
  mut mask_warned : Bool
  mut masking : Int32
}

///|
fn pdf_mul(a : @render.Matrix, b : @render.Matrix) -> @render.Matrix {
  let (a0, a1, a2, a3, a4, a5) = a
  let (b0, b1, b2, b3, b4, b5) = b
  (
    a0 * b0 + a2 * b1,
    a1 * b0 + a3 * b1,
    a0 * b2 + a2 * b3,
    a1 * b2 + a3 * b3,
    a0 * b4 + a2 * b5 + a4,
    a1 * b4 + a3 * b5 + a5,
  )
}

///|
fn pdf_point(m : @render.Matrix, x : Double, y : Double) -> (Double, Double) {
  let (a, b, c, d, e, f) = m
  (a * x + c * y + e, b * x + d * y + f)
}

///|
fn ContentState::op(self : ContentState, text : String) -> Unit {
  self.out.write_string(text)
  self.out.write_string("\n")
}

///|
fn ContentState::save(self : ContentState) -> Unit {
  self.stack.push(self.gs)
  self.op("q")
}

///|
fn ContentState::restore(self : ContentState) -> Unit {
  if self.stack.length() > 0 {
    self.gs = self.stack.pop().unwrap()
  }
  self.op("Q")
}

///|
fn ContentState::alpha_prefix(self : ContentState) -> String {
  if self.gs.alpha < 0.999 {
    let name = self.resources.alpha_gs(self.gs.alpha)
    "q\n/" + name + " gs\n"
  } else {
    ""
  }
}

///|
fn ContentState::alpha_suffix(self : ContentState) -> String {
  if self.gs.alpha < 0.999 {
    "Q\n"
  } else {
    ""
  }
}

///|
fn paint_first_color(paint : @core.Paint) -> Int32? {
  match paint {
    @core.Gradient(_, _, stops) =>
      if stops.length() == 0 {
        None
      } else {
        Some(stops[0].color)
      }
    @core.Pattern(_, _, _) => None
  }
}

///|
fn paint_last_color(paint : @core.Paint) -> Int32? {
  match paint {
    @core.Gradient(_, _, stops) =>
      if stops.length() == 0 {
        None
      } else {
        let mut best = stops[0].color
        let mut best_luminance = 4.0
        for stop in stops {
          let value = stop.color.reinterpret_as_uint()
          let alpha = (value & 0xffU).to_int()
          if alpha == 0 {
            continue
          }
          let r = ((value >> 24) & 0xffU).to_double()
          let g = ((value >> 16) & 0xffU).to_double()
          let b = ((value >> 8) & 0xffU).to_double()
          let luminance = (r * 0.299 + g * 0.587 + b * 0.114) / 255.0
          if luminance < best_luminance {
            best_luminance = luminance
            best = stop.color
          }
        }
        Some(best)
      }
    @core.Pattern(_, _, _) => None
  }
}

///|
fn path_of(
  state : ContentState,
  resources : @core.ObjectResources,
  index : Int32,
) -> @core.Path? {
  if index < 0 || index >= resources.paths.length() {
    return None
  }
  match resources.paths[index] {
    @core.Inline(path) => Some(path)
    @core.External(hash, at) => {
      let bytes = state.document.part(hash) catch { _ => return None }
      let paths = @core.decode_path_collection(bytes) catch { _ => return None }
      if at < 0 || at >= paths.length() {
        None
      } else {
        Some(paths[at])
      }
    }
  }
}

///|
fn path_ops(path : @core.Path) -> String {
  let out = StringBuilder()
  let a = path.coordinates
  let mut i = 0
  let mut cx = 0.0
  let mut cy = 0.0
  let mut sx = 0.0
  let mut sy = 0.0
  for verb in path.verbs {
    match verb.to_int() {
      0 => {
        cx = a[i]
        cy = a[i + 1]
        sx = cx
        sy = cy
        out.write_string(num(cx) + " " + num(cy) + " m\n")
        i += 2
      }
      1 => {
        cx = a[i]
        cy = a[i + 1]
        out.write_string(num(cx) + " " + num(cy) + " l\n")
        i += 2
      }
      2 => {
        let qx = a[i]
        let qy = a[i + 1]
        let x = a[i + 2]
        let y = a[i + 3]
        let c1x = cx + (qx - cx) * 2.0 / 3.0
        let c1y = cy + (qy - cy) * 2.0 / 3.0
        let c2x = x + (qx - x) * 2.0 / 3.0
        let c2y = y + (qy - y) * 2.0 / 3.0
        out.write_string(
          num(c1x) +
          " " +
          num(c1y) +
          " " +
          num(c2x) +
          " " +
          num(c2y) +
          " " +
          num(x) +
          " " +
          num(y) +
          " c\n",
        )
        cx = x
        cy = y
        i += 4
      }
      3 => {
        out.write_string(
          num(a[i]) +
          " " +
          num(a[i + 1]) +
          " " +
          num(a[i + 2]) +
          " " +
          num(a[i + 3]) +
          " " +
          num(a[i + 4]) +
          " " +
          num(a[i + 5]) +
          " c\n",
        )
        cx = a[i + 4]
        cy = a[i + 5]
        i += 6
      }
      4 => {
        out.write_string("h\n")
        cx = sx
        cy = sy
      }
      5 => {
        let x = a[i]
        let y = a[i + 1]
        let w = a[i + 2]
        let h = a[i + 3]
        out.write_string(
          num(x) + " " + num(y) + " " + num(w) + " " + num(h) + " re\n",
        )
        cx = x
        cy = y
        i += 4
      }
      6 => {
        let cx0 = a[i]
        let cy0 = a[i + 1]
        let rx = a[i + 2].abs()
        let ry = a[i + 3].abs()
        let k = 0.5522847498307936
        out.write_string(num(cx0 + rx) + " " + num(cy0) + " m\n")
        out.write_string(
          num(cx0 + rx) +
          " " +
          num(cy0 + k * ry) +
          " " +
          num(cx0 + k * rx) +
          " " +
          num(cy0 + ry) +
          " " +
          num(cx0) +
          " " +
          num(cy0 + ry) +
          " c\n",
        )
        out.write_string(
          num(cx0 - k * rx) +
          " " +
          num(cy0 + ry) +
          " " +
          num(cx0 - rx) +
          " " +
          num(cy0 + k * ry) +
          " " +
          num(cx0 - rx) +
          " " +
          num(cy0) +
          " c\n",
        )
        out.write_string(
          num(cx0 - rx) +
          " " +
          num(cy0 - k * ry) +
          " " +
          num(cx0 - k * rx) +
          " " +
          num(cy0 - ry) +
          " " +
          num(cx0) +
          " " +
          num(cy0 - ry) +
          " c\n",
        )
        out.write_string(
          num(cx0 + k * rx) +
          " " +
          num(cy0 - ry) +
          " " +
          num(cx0 + rx) +
          " " +
          num(cy0 - k * ry) +
          " " +
          num(cx0 + rx) +
          " " +
          num(cy0) +
          " c\n",
        )
        out.write_string("h\n")
        cx = cx0 + rx
        cy = cy0
        sx = cx
        sy = cy
        i += 8
      }
      7 => {
        let x = a[i + 2]
        let y = a[i + 3]
        out.write_string(num(x) + " " + num(y) + " l\n")
        cx = x
        cy = y
        i += 5
      }
      8 => {
        let x = a[i]
        let y = a[i + 1]
        let w = a[i + 2]
        let h = a[i + 3]
        out.write_string(
          num(x) + " " + num(y) + " " + num(w) + " " + num(h) + " re\n",
        )
        cx = x
        cy = y
        i += 5
      }
      _ => ()
    }
  }
  out.to_string()
}

///|
fn fill_solid(
  state : ContentState,
  color : Int32,
  path : String,
  rule : String,
) -> Unit {
  let prefix = state.alpha_prefix()
  if prefix != "" {
    state.out.write_string(prefix)
  }
  state.op(color_text(color) + " rg")
  state.out.write_string(path)
  state.op(rule)
  let suffix = state.alpha_suffix()
  if suffix != "" {
    state.out.write_string(suffix)
  }
}

///|
fn stroke_solid(state : ContentState, color : Int32, path : String) -> Unit {
  let prefix = state.alpha_prefix()
  if prefix != "" {
    state.out.write_string(prefix)
  }
  state.op(color_text(color) + " RG")
  state.out.write_string(path)
  state.op("S")
  let suffix = state.alpha_suffix()
  if suffix != "" {
    state.out.write_string(suffix)
  }
}

///|
fn fill_path(
  state : ContentState,
  resources : @core.ObjectResources,
  index : Int32,
  rule : Int32,
) -> Unit {
  let path = match path_of(state, resources, index) {
    Some(path) => path_ops(path)
    None => {
      state.warnings.push("a path could not be read")
      return
    }
  }
  let paint = state.gs.fill_paint
  if paint is Some(p) && p >= 0 && p < resources.paints.length() {
    match resources.paints[p] {
      @core.Gradient(_, _, _) =>
        if !state.gradient_warned {
          state.warnings.push("gradients are approximated with a solid colour")
          state.gradient_warned = true
        }
      @core.Pattern(_, _, _) =>
        state.warnings.push("a pattern fill is drawn with its solid colour")
    }
  }
  let color = match paint {
    Some(p) if p >= 0 && p < resources.paints.length() =>
      match paint_last_color(resources.paints[p]) {
        Some(color) => color
        None => state.gs.fill_color
      }
    _ => state.gs.fill_color
  }
  fill_solid(state, color, path, if rule == 1 { "f*" } else { "f" })
}

///|
fn fill_rect(
  state : ContentState,
  resources : @core.ObjectResources,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  let path = num(x) + " " + num(y) + " " + num(w) + " " + num(h) + " re\n"
  let paint = state.gs.fill_paint
  if paint is Some(p) && p >= 0 && p < resources.paints.length() {
    match resources.paints[p] {
      @core.Gradient(_, _, _) =>
        if !state.gradient_warned {
          state.warnings.push("gradients are approximated with a solid colour")
          state.gradient_warned = true
        }
      @core.Pattern(_, _, _) => ()
    }
  }
  let color = match paint {
    Some(p) if p >= 0 && p < resources.paints.length() =>
      match paint_last_color(resources.paints[p]) {
        Some(color) => color
        None => state.gs.fill_color
      }
    _ => state.gs.fill_color
  }
  fill_solid(state, color, path, "f")
}

///|
fn stroke_path(
  state : ContentState,
  resources : @core.ObjectResources,
  index : Int32,
) -> Unit {
  let path = match path_of(state, resources, index) {
    Some(path) => path_ops(path)
    None => {
      state.warnings.push("a path could not be read")
      return
    }
  }
  let color = match state.gs.stroke_paint {
    Some(p) if p >= 0 && p < resources.paints.length() =>
      match paint_first_color(resources.paints[p]) {
        Some(color) => color
        None => state.gs.stroke_color
      }
    _ => state.gs.stroke_color
  }
  stroke_solid(state, color, path)
}

///|
fn draw_text_command(
  state : ContentState,
  resources : @core.ObjectResources,
  text : String,
  x : Double,
  y : Double,
  advance : Double,
  stroke : Bool,
) -> Unit {
  if text == "" || state.gs.font_size <= 0.0 {
    return
  }
  let font = if state.gs.font_index >= 0 &&
    state.gs.font_index < resources.fonts.length() {
    Some(resources.fonts[state.gs.font_index])
  } else {
    None
  }
  let (name, encoded) = state.resources.encode_text(state.document, font, text)
  let aligned_x = if state.gs.align == 1 {
    x - advance
  } else if state.gs.align == 2 {
    x - advance / 2.0
  } else {
    x
  }
  let prefix = state.alpha_prefix()
  if prefix != "" {
    state.out.write_string(prefix)
  }
  if stroke {
    state.op(color_text(state.gs.stroke_color) + " RG")
    state.op("1 Tr")
  } else {
    state.op(color_text(state.gs.fill_color) + " rg")
    state.op("0 Tr")
  }
  state.op("BT")
  state.op("/" + name + " " + num(state.gs.font_size) + " Tf")
  state.op("1 0 0 -1 " + num(aligned_x) + " " + num(y) + " Tm")
  state.op(encoded + " Tj")
  state.op("ET")
  let suffix = state.alpha_suffix()
  if suffix != "" {
    state.out.write_string(suffix)
  }
}

///|
fn link_rect(
  state : ContentState,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> String {
  let (x0, y0) = pdf_point(state.gs.matrix, x, y)
  let (x1, y1) = pdf_point(state.gs.matrix, x + w, y)
  let (x2, y2) = pdf_point(state.gs.matrix, x, y + h)
  let (x3, y3) = pdf_point(state.gs.matrix, x + w, y + h)
  let left = Double::min(Double::min(x0, x1), Double::min(x2, x3))
  let right = Double::max(Double::max(x0, x1), Double::max(x2, x3))
  let top = Double::min(Double::min(y0, y1), Double::min(y2, y3))
  let bottom = Double::max(Double::max(y0, y1), Double::max(y2, y3))
  "[" + num(left) + " " + num(top) + " " + num(right) + " " + num(bottom) + "]"
}

///|
fn write_object(
  state : ContentState,
  resources : @core.ObjectResources,
  depth : Int32,
  skip_page_flip : Bool,
) -> Unit {
  if depth > 32 {
    state.warnings.push("objects draw objects too deep")
    return
  }
  let commands = @render.compile_object(resources.object) catch {
    _ => {
      state.warnings.push("an object could not be read")
      return
    }
  }
  let mut first = skip_page_flip
  for command in commands {
    if state.masking > 0 {
      match command {
        @render.MaskBegin(_, _, _) => state.masking += 1
        @render.MaskEnd => {
          state.masking -= 1
          if state.masking == 0 {
            state.restore()
          }
        }
        _ => ()
      }
      continue
    }
    if first {
      first = false
      match command {
        @render.Transform(a, b, c, d, e, f) =>
          if a == 1.0 &&
            b == 0.0 &&
            c == 0.0 &&
            d == -1.0 &&
            e == 0.0 &&
            (f - state.height).abs() < 0.5 {
            continue
          }
        _ => ()
      }
    }
    match command {
      @render.Save => state.save()
      @render.Restore => state.restore()
      @render.Transform(a, b, c, d, e, f) => {
        state.op(
          num(a) +
          " " +
          num(b) +
          " " +
          num(c) +
          " " +
          num(d) +
          " " +
          num(e) +
          " " +
          num(f) +
          " cm",
        )
        state.gs.matrix = pdf_mul(state.gs.matrix, (a, b, c, d, e, f))
      }
      @render.Translate(x, y) => {
        state.op("1 0 0 1 " + num(x) + " " + num(y) + " cm")
        state.gs.matrix = pdf_mul(state.gs.matrix, (1.0, 0.0, 0.0, 1.0, x, y))
      }
      @render.Scale(x, y) => {
        state.op(num(x) + " 0 0 " + num(y) + " 0 0 cm")
        state.gs.matrix = pdf_mul(state.gs.matrix, (x, 0.0, 0.0, y, 0.0, 0.0))
      }
      @render.ClipPath(index, rule) =>
        match path_of(state, resources, index) {
          Some(path) => {
            state.out.write_string(path_ops(path))
            state.op(if rule == 1 { "W* n" } else { "W n" })
          }
          None => state.warnings.push("a clip path could not be read")
        }
      @render.ClipRect(x, y, w, h) =>
        state.op(
          num(x) + " " + num(y) + " " + num(w) + " " + num(h) + " re W n",
        )
      @render.FillColor(color) => {
        state.gs.fill_color = color
        state.gs.fill_paint = None
      }
      @render.StrokeColor(color) => {
        state.gs.stroke_color = color
        state.gs.stroke_paint = None
      }
      @render.FillPaint(index) => state.gs.fill_paint = Some(index)
      @render.StrokePaint(index) => state.gs.stroke_paint = Some(index)
      @render.Line(width, cap, join, miter) => {
        state.gs.line_width = width
        state.gs.line_cap = cap
        state.gs.line_join = join
        state.gs.miter = miter
        state.op(num(width) + " w")
        state.op(cap.to_string() + " J")
        state.op(join.to_string() + " j")
        state.op(num(miter) + " M")
      }
      @render.Dash(values, phase) => {
        let parts : Array[String] = []
        for value in values {
          parts.push(num(value))
        }
        state.gs.dash = "[" + parts.join(" ") + "] " + num(phase) + " d"
        state.op(state.gs.dash)
      }
      @render.Alpha(value) => state.gs.alpha = value
      @render.Blend(_) => ()
      @render.Shadow(_, _, _, _) => state.warnings.push("a shadow is omitted")
      @render.Filter(_) => state.warnings.push("an image filter is omitted")
      @render.Font(index, size) => {
        state.gs.font_index = index
        state.gs.font_size = size
      }
      @render.TextStyle(align, _, _, _) => state.gs.align = align
      @render.FillRect(x, y, w, h) => fill_rect(state, resources, x, y, w, h)
      @render.StrokeRect(x, y, w, h) => {
        let path = num(x) + " " + num(y) + " " + num(w) + " " + num(h) + " re\n"
        stroke_solid(state, state.gs.stroke_color, path)
      }
      @render.FillPath(index, rule) => fill_path(state, resources, index, rule)
      @render.StrokePath(index) => stroke_path(state, resources, index)
      @render.FillPathAt(index, rule, x, y) => {
        state.op("q")
        state.op("1 0 0 1 " + num(x) + " " + num(y) + " cm")
        fill_path(state, resources, index, rule)
        state.op("Q")
      }
      @render.FillPathRun(index, placements) =>
        for placement in placements {
          state.op("q")
          state.op(
            "1 0 0 1 " + num(placement.x) + " " + num(placement.y) + " cm",
          )
          fill_path(state, resources, index, 0)
          state.op("Q")
        }
      @render.ClearRect(x, y, w, h) => {
        state.op("q")
        state.op("1 1 1 rg")
        state.op(num(x) + " " + num(y) + " " + num(w) + " " + num(h) + " re f")
        state.op("Q")
      }
      @render.FillText(text, x, y, advance) =>
        draw_text_command(state, resources, text, x, y, advance, false)
      @render.StrokeText(text, x, y, advance) =>
        draw_text_command(state, resources, text, x, y, advance, true)
      @render.Image(_, _, _, _, _) => state.warnings.push("an image is omitted")
      @render.ImageSub(_, _, _, _, _, _, _, _, _) =>
        state.warnings.push("a cropped image is omitted")
      @render.Smoothing(_, _) => ()
      @render.Use(child) => {
        let child_resources = @core.decode_object_resources(
          state.document.part(child),
        ) catch {
          _ => {
            state.warnings.push("a child object could not be read")
            continue
          }
        }
        state.save()
        write_object(state, child_resources, depth + 1, false)
        state.restore()
      }
      @render.UseAt(child, x, y) => {
        let child_resources = @core.decode_object_resources(
          state.document.part(child),
        ) catch {
          _ => {
            state.warnings.push("a child object could not be read")
            continue
          }
        }
        state.save()
        state.op("1 0 0 1 " + num(x) + " " + num(y) + " cm")
        state.gs.matrix = pdf_mul(state.gs.matrix, (1.0, 0.0, 0.0, 1.0, x, y))
        write_object(state, child_resources, depth + 1, false)
        state.restore()
      }
      @render.GroupBegin(alpha, _, _, _, _, _) => {
        state.save()
        state.gs.alpha = alpha
      }
      @render.GroupEnd => state.restore()
      @render.MaskBegin(_, _, _) => {
        state.save()
        state.masking = 1
        if !state.mask_warned {
          state.warnings.push(
            "a mask is omitted; its mask content is not drawn",
          )
          state.mask_warned = true
        }
      }
      @render.MaskEnd =>
        if state.masking > 0 {
          state.masking = 0
          state.restore()
        }
      @render.Link(x, y, w, h, url) => {
        let rect = link_rect(state, x, y, w, h)
        let id = state.resources.writer.add_string(
          "<< /Type /Annot /Subtype /Link /Rect " +
          rect +
          " /Border [0 0 0] /A << /S /URI /URI " +
          pdf_string(url) +
          " >> >>",
        )
        state.annots.push(id)
      }
      @render.Mark(_, _) => ()
      @render.Ext(_) => ()
    }
  }
}

///|
struct PageContent {
  stream : String
  annots : Array[Int32]
  warnings : Array[String]
}

///|
fn page_content(
  document : @core.Document,
  resources : PdfResources,
  page : @core.Page,
  height : Double,
) -> PageContent {
  let state : ContentState = {
    out: StringBuilder(),
    document,
    resources,
    height,
    annots: [],
    gs: PdfGState::new(),
    stack: [],
    warnings: [],
    gradient_warned: false,
    mask_warned: false,
    masking: 0,
  }
  state.op("q")
  state.op("1 0 0 -1 0 " + num(height) + " cm")
  state.gs.matrix = pdf_mul(state.gs.matrix, (1.0, 0.0, 0.0, -1.0, 0.0, height))
  for layer in page.layers {
    let layer_resources = @core.decode_object_resources(
      document.part(layer.object),
    ) catch {
      _ => {
        state.warnings.push("a layer could not be read")
        continue
      }
    }
    state.op("q")
    write_object(state, layer_resources, 0, false)
    state.op("Q")
  }
  state.op("Q")
  {
    stream: state.out.to_string(),
    annots: state.annots,
    warnings: state.warnings,
  }
}
