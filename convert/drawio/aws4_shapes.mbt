///|
/// The composite mxgraph.aws4.* shapes of draw.io's shapes/mxAWS4.js
/// (upstream shapes_aws4.go): resourceIcon and productIcon paint a colored
/// frame and a stencil taken from resIcon/prIcon; group, groupCenter and
/// group2 paint a frame and a grIcon stencil in a corner square. The
/// stencils come from the embedded aws4 library like any other mxStencil.
/// Everything is drawn straight into the page drawing: Drawing::append
/// groups its input and does not transform group children, so a nested
/// intermediate drawing would lose the cell transform.

///|
fn drawio_aws4_is_composite(name : String) -> Bool {
  name == "mxgraph.aws4.resourceIcon" ||
  name == "mxgraph.aws4.productIcon" ||
  name == "mxgraph.aws4.group" ||
  name == "mxgraph.aws4.groupCenter" ||
  name == "mxgraph.aws4.group2"
}

///|
/// A style color as a paint color (0 when absent or unparsable), with the
/// opacity applied like the stencil canvas does.
fn drawio_aws4_paint(value : String, alpha : Double) -> UInt32 {
  if value == "" || value == "none" || value == "transparent" {
    return 0U
  }
  match drawio_parse_color(value) {
    Some(c) => drawio_color_alpha_mul(c, alpha)
    None => 0U
  }
}

///|
/// Fill and/or stroke a rect given in cell-local coordinates, transformed
/// by `m` (cell rotation/flip plus the cell origin); a zero paint color
/// (or a fully transparent one) is skipped.
fn drawio_aws4_rect(
  drawing : @cad.Drawing,
  m : @canvas.Matrix,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  fill : UInt32,
  stroke : UInt32,
  stroke_width : Double,
  dash? : Array[Double]? = None,
) -> Unit {
  if w <= 0.0 || h <= 0.0 {
    return
  }
  let path = @cad.CadPath::new()
  path.move_to(x, y)
  path.line_to(x + w, y)
  path.line_to(x + w, y + h)
  path.line_to(x, y + h)
  path.close()
  let tp = path.transform(m)
  if (fill & 0xffU) != 0U {
    drawing.fill(tp, @cad.Fill::solid(fill), false)
  }
  if (stroke & 0xffU) != 0U {
    drawing.stroke(
      tp,
      @cad.Pen::new(
        color=stroke,
        world_width=Double::max(0.01, stroke_width),
        dash~,
      ),
    )
  }
}

///|
/// The cell's dash pattern in drawing units (mxGraph dashPattern scaled
/// by strokeWidth, or unscaled with fixDash), or None when not dashed.
fn drawio_aws4_dash(cell : DrawioCell, stroke_width : Double) -> Array[Double]? {
  if drawio_style(cell.style, "dashed", "") != "1" {
    return None
  }
  let factor = if drawio_style(cell.style, "fixDash", "0") == "1" {
    1.0
  } else {
    stroke_width
  }
  let out : Array[Double] = []
  for tok in drawio_style(cell.style, "dashPattern", "3 3").split(" ") {
    let t = tok.to_string().trim()
    if t != "" {
      out.push(drawio_number_js(t.to_string()) * factor)
    }
  }
  if out.is_empty() { None } else { Some(out) }
}

///|
/// The cell rotation/flip transform about the cell center (mxShape paint)
/// composed with the translation to the cell origin: cell-local
/// coordinates to page coordinates.
fn drawio_aws4_cell_matrix(
  cell : DrawioCell,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> @canvas.Matrix {
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
  m.mul(@canvas.Matrix::translate(x, y))
}

///|
/// The aspect transform of a stencil into the cell-local box
/// (x,y,w,h): stretched, or centered with the stencil's proportions for a
/// fixed aspect, axes swapped for north/south directions
/// (mxStencil.computeAspect). Shared with the plain stencil path.
fn drawio_stencil_aspect(
  st : DrawioStencil,
  style : Map[String, String],
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> (Double, Double, Double, Double) {
  let direction = match style.get("direction") {
    Some(v) => v
    None => ""
  }
  let inverse = direction == "north" || direction == "south"
  let mut x0 = x
  let mut y0 = y
  let mut sx = w / st.w0
  let mut sy = h / st.h0
  if inverse {
    sy = w / st.h0
    sx = h / st.w0
    let delta = (w - h) / 2.0
    x0 += delta
    y0 -= delta
  }
  if st.aspect == "fixed" {
    sy = Double::min(sx, sy)
    sx = sy
    if inverse {
      x0 += (h - st.w0 * sx) / 2.0
      y0 += (w - st.h0 * sy) / 2.0
    } else {
      x0 += (w - st.w0 * sx) / 2.0
      y0 += (h - st.h0 * sy) / 2.0
    }
  }
  (x0, y0, sx, sy)
}

///|
/// Draw a stencil icon into `drawing`, filled with `icon_fill` (the style
/// color string) and not stroked, in the cell-local box (x,y,w,h) under
/// the cell transform `cm`; `icon_alpha` is the fill alpha mxStencil's
/// drawShape sees (strokeOpacity for the group icons).
fn drawio_aws4_inner(
  drawing : @cad.Drawing,
  ctx : DrawioStencilContext,
  cm : @canvas.Matrix,
  icon_fill : String,
  icon_alpha : Double,
  icon : String,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  if icon == "" || icon == "none" || w <= 0.0 || h <= 0.0 {
    return
  }
  let st = match drawio_stencil_lookup(icon) {
    Some(value) => value
    None => return
  }
  let icon_ctx : DrawioStencilContext = {
    style: ctx.style,
    style_str: ctx.style_str,
    stroke: "",
    fill: icon_fill,
    font_color: ctx.font_color,
    stroke_width: ctx.stroke_width,
    fill_opacity: icon_alpha,
    stroke_opacity: ctx.stroke_opacity,
    outline: ctx.outline,
    warn: ctx.warn,
  }
  let baked = drawio_stencil_bake(st, icon, icon_ctx)
  let (x0, y0, sx, sy) = drawio_stencil_aspect(st, ctx.style, x, y, w, h)
  let m = cm.mul(@canvas.Matrix::translate(x0, y0)).mul(
    @canvas.Matrix::scale(sx, sy),
  )
  drawing.append(baked, m, None)
}

///|
/// Draw one of the composite aws4 shapes into `drawing` at cell-local
/// (0,0,w,h); returns false for names that are not composites.
fn drawio_aws4_composite(
  cell : DrawioCell,
  drawing : @cad.Drawing,
  ctx : DrawioStencilContext,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Bool {
  let name = drawio_shape_name(cell.style)
  if !drawio_aws4_is_composite(name) || w <= 0.0 || h <= 0.0 {
    return false
  }
  let cm = drawio_aws4_cell_matrix(cell, x, y, w, h)
  let raw_fill = drawio_style(cell.style, "fillColor", "")
  let raw_stroke = drawio_style(cell.style, "strokeColor", "")
  let stroke_w = drawio_num_from_style(cell.style, "strokeWidth", 1.0)
  if name == "mxgraph.aws4.resourceIcon" {
    // The bounds filled with the fill color, the resIcon stencil in the
    // middle 80% filled with the stroke color.
    drawio_aws4_rect(
      drawing, cm, 0.0, 0.0, w, h,
      drawio_aws4_paint(raw_fill, ctx.fill_opacity), 0U, 1.0,
    )
    drawio_aws4_inner(
      drawing, ctx, cm, raw_stroke, ctx.fill_opacity,
      drawio_style(cell.style, "resIcon", ""),
      w * 0.1, h * 0.1, w * 0.8, h * 0.8,
    )
  } else if name == "mxgraph.aws4.productIcon" {
    // The bounds filled with the stroke color, a square inset by 1 filled
    // with the fill color, and the prIcon stencil in its middle.
    let ind = 1.0
    drawio_aws4_rect(
      drawing, cm, 0.0, 0.0, w, h,
      drawio_aws4_paint(raw_stroke, 1.0), 0U, 1.0,
    )
    drawio_aws4_rect(
      drawing, cm, ind, ind, w - 2.0 * ind, w - 2.0 * ind,
      drawio_aws4_paint(raw_fill, ctx.fill_opacity), 0U, 1.0,
    )
    drawio_aws4_inner(
      drawing, ctx, cm, raw_stroke, ctx.fill_opacity,
      drawio_style(cell.style, "prIcon", ""),
      ind + w * 0.15, ind + w * 0.15, w * 0.7 - 2.0 * ind, w * 0.7 - 2.0 * ind,
    )
  } else {
    // group, groupCenter and group2: the frame is always filled with the
    // fill color; the grIcon stencil is filled with the stroke color
    // (white for group2) at the alpha of strokeOpacity.
    let gr_stroke = drawio_style(cell.style, "grStroke", "1")
    let outline = drawio_style(cell.style, "outline", "0") == "1"
    // group2 fillAndStrokes its frame unconditionally; group and
    // groupCenter stroke it only when grStroke is 1 or outline is set.
    let stroked = name == "mxgraph.aws4.group2" || gr_stroke == "1" || outline
    drawio_aws4_rect(
      drawing, cm, 0.0, 0.0, w, h,
      drawio_aws4_paint(raw_fill, ctx.fill_opacity),
      if stroked { drawio_aws4_paint(raw_stroke, ctx.stroke_opacity) } else { 0U },
      stroke_w,
      dash=drawio_aws4_dash(cell, stroke_w),
    )
    if name == "mxgraph.aws4.group2" {
      // group2 always fillAndStrokes its frame, then a 25x25 square of
      // the stroke color with the grIcon stencil in white inside the
      // middle 80% of the grIconSize square.
      let size = 25.0
      let icon_size = drawio_num_from_style(cell.style, "grIconSize", 25.0)
      drawio_aws4_rect(
        drawing, cm, 0.0, 0.0, size, size,
        drawio_aws4_paint(raw_stroke, ctx.stroke_opacity), 0U, 1.0,
      )
      if icon_size > 0.0 && !icon_size.is_nan() && !icon_size.is_inf() {
        drawio_aws4_inner(
          drawing, ctx, cm, "#ffffff", ctx.stroke_opacity,
          drawio_style(cell.style, "grIcon", ""),
          icon_size * 0.1, icon_size * 0.1, icon_size * 0.8, icon_size * 0.8,
        )
      }
    } else {
      let size = drawio_num_from_style(cell.style, "grIconSize", 25.0)
      if size > 0.0 && !size.is_nan() && !size.is_inf() {
        let x0 = if name == "mxgraph.aws4.groupCenter" { (w - size) / 2.0 } else { 0.0 }
        drawio_aws4_inner(
          drawing, ctx, cm, raw_stroke, ctx.stroke_opacity,
          drawio_style(cell.style, "grIcon", ""),
          x0, 0.0, size, size,
        )
      }
    }
  }
  true
}
