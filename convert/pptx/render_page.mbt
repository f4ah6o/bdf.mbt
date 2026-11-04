///|
// Slide pages and their background, master, layout and body layers.

///|
priv struct PptxCachedLayer {
  hash : String
  data : Bytes
}

///|
priv struct PptxRenderCache {
  backgrounds : Map[String, PptxCachedLayer]
  masters : Map[String, PptxCachedLayer]
  layouts : Map[String, PptxCachedLayer]
  mut embedded_fonts : Int32
}

///|
fn pptx_new_render_cache() -> PptxRenderCache {
  {
    backgrounds: Map([]),
    masters: Map([]),
    layouts: Map([]),
    embedded_fonts: 0,
  }
}

///|
fn pptx_layer_json(role : String, hash : String) -> Json {
  Json::object({ "role": Json::string(role), "obj": Json::string(hash) })
}

///|
fn pptx_object_is_empty(data : Bytes) -> Bool {
  data.length() <= 31
}

///|
fn pptx_collect_tree_shapes(
  root : PptxXmlNode,
  skip_placeholders : Bool,
) -> Array[(PptxXmlNode, PptxPlacement)] {
  let shapes : Array[(PptxXmlNode, PptxPlacement)] = []
  match pptx_child(pptx_child(Some(root), "cSld"), "spTree") {
    Some(tree) =>
      pptx_collect_shapes(
        tree,
        { sx: 1.0, sy: 1.0, tx: 0.0, ty: 0.0, rotation: 0.0, cx: 0.0, cy: 0.0, },
        skip_placeholders,
        shapes,
      )
    None => ()
  }
  shapes
}

///|
fn pptx_emit_shapes(
  ctx : PptxShapeContext,
  object : @core.ObjectBuilder,
  part : String,
  shapes : Array[(PptxXmlNode, PptxPlacement)],
) -> Unit raise {
  for shape_entry in shapes {
    let (shape, placement) = shape_entry
    let mut transform = if shape.element.name.local_name == "graphicFrame" {
      pptx_transform_node(pptx_child(Some(shape), "xfrm"))
    } else {
      pptx_transform_node(pptx_child(pptx_child(Some(shape), "spPr"), "xfrm"))
    }
    if transform is None {
      match pptx_placeholder_info(shape) {
        Some(info) => {
          match
            pptx_find_placeholder_shape(ctx.layout_placeholders, info, false) {
            Some(value) =>
              transform = pptx_transform_node(
                pptx_child(pptx_child(Some(value), "spPr"), "xfrm"),
              )
            None => ()
          }
          if transform is None {
            match
              pptx_find_placeholder_shape(ctx.master_placeholders, info, true) {
              Some(value) =>
                transform = pptx_transform_node(
                  pptx_child(pptx_child(Some(value), "spPr"), "xfrm"),
                )
              None => ()
            }
          }
        }
        None => ()
      }
    }
    let transform = match transform {
      Some(value) => value
      None => continue
    }
    let draw_width = transform.width * placement.sx
    let draw_height = transform.height * placement.sy
    if draw_width <= 0.0 || draw_height <= 0.0 {
      continue
    }
    let shape_x = placement.tx + transform.x * placement.sx
    let shape_y = placement.ty + transform.y * placement.sy
    if shape.element.name.local_name == "graphicFrame" {
      if pptx_table_lines(shape).is_empty() {
        pptx_emit_chart(
          shape,
          ctx.package,
          part,
          object,
          shape_x,
          shape_y,
          draw_width,
          draw_height,
          ctx.theme,
          ctx.theme_fonts,
        )
      } else {
        pptx_emit_table(
          shape,
          object,
          shape_x,
          shape_y,
          draw_width,
          ctx.theme,
          ctx.theme_fonts,
          ctx.font_ctx,
        )
      }
      continue
    }
    if shape.element.name.local_name == "pic" {
      let blip = pptx_child(pptx_child(Some(shape), "blipFill"), "blip")
      let embed = match blip {
        Some(value) => pptx_attribute_any(value.element, "embed", "")
        None => ""
      }
      if embed == "" {
        raise PptxInvalid("PPTX picture has no embedded image")
      }
      let mut target = ""
      let mut external = false
      for rel in ctx.package.relationships(part) {
        if rel.id == embed {
          target = rel.target
          external = rel.external
        }
      }
      if target == "" || external {
        raise PptxInvalid("PPTX picture relationship is missing")
      }
      let bytes = ctx.package.read(target) catch {
        _ => raise PptxInvalid("PPTX picture part is missing")
      }
      let pic_rotation = transform.rotation + placement.rotation
      let pic_transformed = pic_rotation != 0.0 ||
        transform.flip_h ||
        transform.flip_v
      let pic_cx = if placement.rotation != 0.0 {
        placement.cx
      } else {
        shape_x + draw_width / 2.0
      }
      let pic_cy = if placement.rotation != 0.0 {
        placement.cy
      } else {
        shape_y + draw_height / 2.0
      }
      if pic_transformed {
        let radians = pic_rotation * 3.141592653589793 / 180.0
        let sine = @math.sin(radians)
        let cosine = @math.cos(radians)
        object.save()
        object.translate(Float::from_double(pic_cx), Float::from_double(pic_cy))
        object.transform(
          Float::from_double(cosine),
          Float::from_double(sine),
          Float::from_double(-sine),
          Float::from_double(cosine),
          0.0F,
          0.0F,
        )
        if transform.flip_h || transform.flip_v {
          object.scale(
            if transform.flip_h {
              -1.0F
            } else {
              1.0F
            },
            if transform.flip_v {
              -1.0F
            } else {
              1.0F
            },
          )
        }
        object.translate(
          Float::from_double(-pic_cx),
          Float::from_double(-pic_cy),
        )
      }
      let alpha = pptx_picture_alpha(shape)
      if alpha is Some(_) {
        object.save()
        object.alpha(Float::from_double(alpha.unwrap()))
      }
      if @metafile.kind(bytes) != "" {
        ignore(
          @metafile.draw_into(
            object,
            ctx.writer,
            bytes,
            shape_x,
            shape_y,
            draw_width,
            draw_height,
          ) catch {
            _ => []
          },
        )
      } else {
        let hash = ctx.writer.add_part("img", bytes)
        let index = object.add_image(hash)
        let mut cropped = false
        match (pptx_png_size(bytes), pptx_src_rect(shape)) {
          (Some((image_width, image_height)), Some((left, top, right, bottom))) => {
            let sx = left * image_width.to_double()
            let sy = top * image_height.to_double()
            let sw = (1.0 - left - right) * image_width.to_double()
            let sh = (1.0 - top - bottom) * image_height.to_double()
            if sw > 0.0 && sh > 0.0 {
              object.image_sub(
                index,
                Float::from_double(sx),
                Float::from_double(sy),
                Float::from_double(sw),
                Float::from_double(sh),
                Float::from_double(shape_x),
                Float::from_double(shape_y),
                Float::from_double(draw_width),
                Float::from_double(draw_height),
              )
              cropped = true
            }
          }
          _ => ()
        }
        if !cropped {
          object.image(
            index,
            Float::from_double(shape_x),
            Float::from_double(shape_y),
            Float::from_double(draw_width),
            Float::from_double(draw_height),
          )
        }
      }
      if alpha is Some(_) {
        object.restore()
      }
      if pic_transformed {
        object.restore()
      }
      continue
    }
    let inherited = pptx_shape_inheritance(ctx, shape)
    let geom = pptx_shape_geometry_node(shape, inherited)
    let mut preset_geom : PptxXmlNode? = None
    let mut custom_geom : PptxXmlNode? = None
    let mut geometry_name = "rect"
    match geom {
      Some(PptxPresetGeometry(node)) => {
        preset_geom = Some(node)
        geometry_name = pptx_attribute(node.element, "prst", "rect")
        if geometry_name == "" {
          geometry_name = "rect"
        }
      }
      Some(PptxCustomGeometry(node)) => {
        custom_geom = Some(node)
        geometry_name = ""
      }
      None => ()
    }
    let geometry = match custom_geom {
      Some(node) =>
        match pptx_custom_geometry(node, draw_width, draw_height) {
          (Some(value), _) => value
          (None, reason) => {
            ctx.warn_once(
              "custGeom:" + reason,
              "malformed custom geometry (" + reason + ") drawn as a rectangle",
            )
            geometry_name = "rect"
            pptx_rect_geometry(draw_width, draw_height)
          }
        }
      None =>
        match
          pptx_preset_geometry(
            geometry_name,
            pptx_preset_adjust(preset_geom),
            draw_width,
            draw_height,
          ) {
          Some(value) => value
          None => {
            ctx.warn_once(
              "prst:" + geometry_name,
              "unknown preset shape \"" +
              geometry_name +
              "\" drawn as a rectangle",
            )
            geometry_name = "rect"
            pptx_rect_geometry(draw_width, draw_height)
          }
        }
    }
    let paint = pptx_shape_paint(ctx, shape, inherited)
    let line = pptx_shape_line(ctx, shape, inherited)
    let center_x = shape_x + draw_width / 2.0
    let center_y = shape_y + draw_height / 2.0
    let path_rotation = transform.rotation + placement.rotation
    let path_center_x = if placement.rotation != 0.0 {
      placement.cx
    } else {
      center_x
    }
    let path_center_y = if placement.rotation != 0.0 {
      placement.cy
    } else {
      center_y
    }
    let gradient = match paint {
      PptxPaintGradient(node, theme) =>
        pptx_gradient_node(
          Some(node),
          shape_x,
          shape_y,
          draw_width,
          draw_height,
          theme,
        )
      _ => None
    }
    let fill_alpha = match paint {
      PptxPaintSolid(_, alpha) => alpha
      _ => None
    }
    if fill_alpha is Some(_) {
      object.save()
      object.alpha(Float::from_double(fill_alpha.unwrap()))
    }
    if geometry_name == "rect" {
      match paint {
        PptxPaintSolid(color, _) => {
          object.fill_color(color)
          if path_rotation != 0.0 {
            let path = pptx_rotated_rect_path_at(
              shape_x, shape_y, draw_width, draw_height, path_rotation, path_center_x,
              path_center_y,
            )
            object.fill_path(object.add_path(@core.Inline(path)), 0)
          } else {
            object.fill_rect(
              Float::from_double(shape_x),
              Float::from_double(shape_y),
              Float::from_double(draw_width),
              Float::from_double(draw_height),
            )
          }
        }
        PptxPaintGradient(_, _) =>
          match gradient {
            Some(value) => {
              object.fill_paint(object.add_paint(value))
              if path_rotation != 0.0 {
                let path = pptx_rotated_rect_path_at(
                  shape_x, shape_y, draw_width, draw_height, path_rotation, path_center_x,
                  path_center_y,
                )
                object.fill_path(object.add_path(@core.Inline(path)), 0)
              } else {
                object.fill_rect(
                  Float::from_double(shape_x),
                  Float::from_double(shape_y),
                  Float::from_double(draw_width),
                  Float::from_double(draw_height),
                )
              }
            }
            None => ()
          }
        PptxPaintNone => ()
      }
      match line {
        Some(value) =>
          if path_rotation != 0.0 {
            let path = pptx_rotated_rect_path_at(
              shape_x, shape_y, draw_width, draw_height, path_rotation, path_center_x,
              path_center_y,
            )
            pptx_stroke_geometry_path(object, value, path)
          } else {
            pptx_set_line(object, value)
            object.stroke_rect(
              Float::from_double(shape_x),
              Float::from_double(shape_y),
              Float::from_double(draw_width),
              Float::from_double(draw_height),
            )
          }
        None => ()
      }
    } else if geometry_name == "roundRect" {
      let radius = pptx_round_rect_radius(preset_geom, draw_width, draw_height)
      let path = pptx_rotate_path(
        pptx_round_rect_path(shape_x, shape_y, draw_width, draw_height, radius),
        path_center_x,
        path_center_y,
        path_rotation,
      )
      pptx_fill_geometry_path(object, paint, gradient, path)
      match line {
        Some(value) => pptx_stroke_geometry_path(object, value, path)
        None => ()
      }
    } else if geometry_name == "ellipse" {
      let path = pptx_rotate_path(
        pptx_ellipse_path(shape_x, shape_y, draw_width, draw_height),
        path_center_x,
        path_center_y,
        path_rotation,
      )
      pptx_fill_geometry_path(object, paint, gradient, path)
      match line {
        Some(value) => pptx_stroke_geometry_path(object, value, path)
        None => ()
      }
    } else {
      for entry in geometry.paths {
        if entry.fill != "none" {
          let path = pptx_geometry_path_at(
            entry.path,
            shape_x,
            shape_y,
            path_rotation,
            path_center_x,
            path_center_y,
          )
          match paint {
            PptxPaintSolid(color, _) => {
              object.fill_color(pptx_adjust_fill_color(color, entry.fill))
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
      }
      match line {
        Some(value) =>
          for entry in geometry.paths {
            if entry.stroke && !entry.empty {
              let path = pptx_geometry_path_at(
                entry.path,
                shape_x,
                shape_y,
                path_rotation,
                path_center_x,
                path_center_y,
              )
              pptx_stroke_geometry_path(object, value, path)
            }
          }
        None => ()
      }
    }
    if fill_alpha is Some(_) {
      object.restore()
    }
    let text_rotation = transform.rotation + placement.rotation
    let text_cx = if placement.rotation != 0.0 {
      placement.cx
    } else {
      shape_x + draw_width / 2.0
    }
    let text_cy = if placement.rotation != 0.0 {
      placement.cy
    } else {
      shape_y + draw_height / 2.0
    }
    let body = match pptx_child(Some(shape), "txBody") {
      Some(value) => value
      None => continue
    }
    let mut text_x = shape_x + geometry.text_left
    let mut text_y = shape_y + geometry.text_top
    let mut text_width = geometry.text_right - geometry.text_left
    let mut text_height = geometry.text_bottom - geometry.text_top
    if text_width <= 0.0 || text_height <= 0.0 {
      text_x = shape_x
      text_y = shape_y
      text_width = draw_width
      text_height = draw_height
    }
    pptx_draw_shape_text(
      ctx, object, shape, body, text_x, text_y, text_width, text_height, text_rotation,
      text_cx, text_cy,
    )
  }
}

///|
fn pptx_find_background(
  slide : PptxXmlNode,
  slide_part : String,
  layout : PptxXmlNode?,
  layout_part : String,
  master : PptxXmlNode?,
  master_part : String,
) -> (PptxXmlNode?, String) {
  match pptx_child(pptx_child(Some(slide), "cSld"), "bg") {
    Some(value) => return (Some(value), slide_part)
    None => ()
  }
  match layout {
    Some(root) =>
      match pptx_child(pptx_child(Some(root), "cSld"), "bg") {
        Some(value) => return (Some(value), layout_part)
        None => ()
      }
    None => ()
  }
  match master {
    Some(root) =>
      match pptx_child(pptx_child(Some(root), "cSld"), "bg") {
        Some(value) => return (Some(value), master_part)
        None => ()
      }
    None => ()
  }
  (None, "")
}

///|
fn pptx_build_background(
  ctx : PptxShapeContext,
  background : PptxXmlNode?,
  part : String,
  width : Double,
  height : Double,
) -> Bytes raise {
  let object = @core.ObjectBuilder::new()
  let background = match background {
    Some(value) => value
    None => {
      let color = ctx.theme.get("bg1").unwrap_or(0xffffffffU)
      object.fill_color(color)
      object.fill_rect(
        0.0,
        0.0,
        Float::from_double(width),
        Float::from_double(height),
      )
      return object.encode()
    }
  }
  let properties = pptx_child(Some(background), "bgPr")
  let reference = pptx_child(Some(background), "bgRef")
  let mut image = false
  match properties {
    Some(value) =>
      match pptx_child(Some(value), "blipFill") {
        Some(fill) =>
          match pptx_child(Some(fill), "blip") {
            Some(blip) => {
              let embed = pptx_attribute_any(blip.element, "embed", "")
              if embed != "" {
                let mut target = ""
                for rel in ctx.package.relationships(part) {
                  if rel.id == embed {
                    target = rel.target
                  }
                }
                if target != "" {
                  let bytes = ctx.package.read(target) catch { _ => b"" }
                  if bytes.length() > 0 {
                    let hash = ctx.writer.add_part("img", bytes)
                    let index = object.add_image(hash)
                    object.image(
                      index,
                      0.0,
                      0.0,
                      Float::from_double(width),
                      Float::from_double(height),
                    )
                    image = true
                  }
                }
              }
            }
            None => ()
          }
        None => ()
      }
    None => ()
  }
  if !image {
    let mut color : UInt32? = None
    let mut gradient : @core.Paint? = None
    match properties {
      Some(value) => {
        color = pptx_node_color(Some(value), "solidFill", ctx.theme)
        gradient = pptx_gradient_node(
          pptx_child(Some(value), "gradFill"),
          0.0,
          0.0,
          width,
          height,
          ctx.theme,
        )
      }
      None => ()
    }
    if color is None && gradient is None {
      match reference {
        Some(value) =>
          match pptx_child(Some(value), "schemeClr") {
            Some(scheme) =>
              color = Some(
                pptx_solid_color(Some(value), ctx.theme).unwrap_or(
                  ctx.theme
                  .get(pptx_attribute(scheme.element, "val", "bg1"))
                  .unwrap_or(0xffffffffU),
                ),
              )
            None => ()
          }
        None => ()
      }
    }
    if color is None && gradient is None {
      color = Some(ctx.theme.get("bg1").unwrap_or(0xffffffffU))
    }
    match gradient {
      Some(paint) => {
        object.fill_paint(object.add_paint(paint))
        object.fill_rect(
          0.0,
          0.0,
          Float::from_double(width),
          Float::from_double(height),
        )
      }
      None =>
        match color {
          Some(value) => {
            object.fill_color(value)
            object.fill_rect(
              0.0,
              0.0,
              Float::from_double(width),
              Float::from_double(height),
            )
          }
          None => ()
        }
    }
  }
  object.encode()
}

///|
fn pptx_build_tree_layer(
  package : @ooxml.OoxmlPackage,
  writer : @core.DocumentWriter,
  theme : Map[String, UInt32],
  theme_fonts : PptxThemeFonts,
  theme_fills : Array[PptxXmlNode],
  theme_bg_fills : Array[PptxXmlNode],
  theme_lines : Array[PptxXmlNode],
  default_text_style : PptxXmlNode?,
  part : String,
  root : PptxXmlNode,
  warnings : Array[String],
  warned : Map[String, Bool],
  fonts : @canvas.Fonts,
  missing : Map[Int32, Bool],
) -> (Bytes, Int32) raise {
  let ctx : PptxShapeContext = {
    package,
    writer,
    part,
    theme,
    theme_fonts,
    theme_fills,
    theme_bg_fills,
    theme_lines,
    default_text_style,
    layout_root: None,
    master_root: None,
    layout_placeholders: [],
    master_placeholders: [],
    is_body: false,
    fonts: Map([]),
    warnings,
    warned,
    font_ctx: pptx_font_context(fonts, missing),
  }
  let object = @core.ObjectBuilder::new()
  pptx_emit_shapes(ctx, object, part, pptx_collect_tree_shapes(root, true))
  let embedded = pptx_embed_fonts(ctx.font_ctx, object, writer, warnings)
  (object.encode(), embedded)
}

///|
fn pptx_cached_layer(
  writer : @core.DocumentWriter,
  data : Bytes,
) -> PptxCachedLayer raise {
  let hash = writer.add_part("obj", data)
  { hash, data, }
}

///|
fn pptx_push_layer_index(
  data : Bytes,
  page : Int32,
  layer : Int32,
  index_runs : Array[@core.IndexRun],
  budget : @render.TextExtractionBudget,
) -> Unit {
  let resources = @core.decode_object_resources(data) catch { _ => return }
  let content = @render.extract_text_with_budget(
    resources,
    fn(_) { None },
    budget,
  ) catch {
    _ => return
  }
  for i, run in content.runs {
    index_runs.push({
      a: page,
      b: layer,
      ordinal: run.ordinal,
      separator: if i == 0 {
        2
      } else {
        run.separator
      },
      text: run.text,
    })
  }
}

///|
fn pptx_render_page(
  package : @ooxml.OoxmlPackage,
  writer : @core.DocumentWriter,
  theme : Map[String, UInt32],
  theme_fonts : PptxThemeFonts,
  theme_fills : Array[PptxXmlNode],
  theme_bg_fills : Array[PptxXmlNode],
  theme_lines : Array[PptxXmlNode],
  default_text_style : PptxXmlNode?,
  slide_part : String,
  slide_root : PptxXmlNode,
  width : Double,
  height : Double,
  page_index : Int32,
  index_runs : Array[@core.IndexRun],
  index_budget : @render.TextExtractionBudget,
  cache : PptxRenderCache,
  warnings : Array[String],
  warned : Map[String, Bool],
  fonts : @canvas.Fonts,
  missing : Map[Int32, Bool],
) -> Json raise {
  let context = pptx_slide_context(package, slide_part)
  let layout_part = context.layout_part
  let master_part = context.master_part
  let layout_root = if context.draw_layout && layout_part != "" {
    Some(pptx_read_xml(package, layout_part))
  } else {
    None
  }
  let master_root = if context.draw_master && master_part != "" {
    Some(pptx_read_xml(package, master_part))
  } else {
    None
  }
  let roles : Array[String] = []
  let layers : Array[PptxCachedLayer] = []
  // background
  let (background, background_part) = pptx_find_background(
    slide_root, slide_part, layout_root, layout_part, master_root, master_part,
  )
  let background_key = if background_part == "" {
    "default"
  } else {
    background_part
  }
  let background_layer = match cache.backgrounds.get(background_key) {
    Some(value) => value
    None => {
      let empty_ctx : PptxShapeContext = {
        package,
        writer,
        part: "",
        theme,
        theme_fonts,
        theme_fills,
        theme_bg_fills,
        theme_lines,
        default_text_style,
        layout_root: None,
        master_root: None,
        layout_placeholders: [],
        master_placeholders: [],
        is_body: false,
        fonts: Map([]),
        warnings,
        warned,
        font_ctx: pptx_font_context(fonts, missing),
      }
      let data = pptx_build_background(
        empty_ctx, background, background_part, width, height,
      )
      let layer = pptx_cached_layer(writer, data)
      cache.backgrounds[background_key] = layer
      layer
    }
  }
  roles.push("background")
  layers.push(background_layer)
  // master
  match master_root {
    Some(root) => {
      let layer = match cache.masters.get(master_part) {
        Some(value) => value
        None => {
          let (data, embedded) = pptx_build_tree_layer(
            package, writer, theme, theme_fonts, theme_fills, theme_bg_fills, theme_lines,
            default_text_style, master_part, root, warnings, warned, fonts, missing,
          )
          cache.embedded_fonts += embedded
          let layer = pptx_cached_layer(writer, data)
          cache.masters[master_part] = layer
          layer
        }
      }
      if !pptx_object_is_empty(layer.data) {
        roles.push("master")
        layers.push(layer)
      }
    }
    None => ()
  }
  // layout
  match layout_root {
    Some(root) => {
      let layer = match cache.layouts.get(layout_part) {
        Some(value) => value
        None => {
          let (data, embedded) = pptx_build_tree_layer(
            package, writer, theme, theme_fonts, theme_fills, theme_bg_fills, theme_lines,
            default_text_style, layout_part, root, warnings, warned, fonts, missing,
          )
          cache.embedded_fonts += embedded
          let layer = pptx_cached_layer(writer, data)
          cache.layouts[layout_part] = layer
          layer
        }
      }
      if !pptx_object_is_empty(layer.data) {
        roles.push("master")
        layers.push(layer)
      }
    }
    None => ()
  }
  // body
  let layout_placeholders = match layout_root {
    Some(value) => pptx_placeholder_shapes(value)
    None => []
  }
  let master_placeholders = match master_root {
    Some(value) => pptx_placeholder_shapes(value)
    None => []
  }
  let body_ctx : PptxShapeContext = {
    package,
    writer,
    part: slide_part,
    theme,
    theme_fonts,
    theme_fills,
    theme_bg_fills,
    theme_lines,
    default_text_style,
    layout_root,
    master_root,
    layout_placeholders,
    master_placeholders,
    is_body: true,
    fonts: Map([]),
    warnings,
    warned,
    font_ctx: pptx_font_context(fonts, missing),
  }
  let body_object = @core.ObjectBuilder::new()
  pptx_emit_shapes(
    body_ctx,
    body_object,
    slide_part,
    pptx_collect_tree_shapes(slide_root, false),
  )
  cache.embedded_fonts += pptx_embed_fonts(
    body_ctx.font_ctx,
    body_object,
    writer,
    warnings,
  )
  let body_data = body_object.encode()
  if !pptx_object_is_empty(body_data) {
    roles.push("body")
    layers.push(pptx_cached_layer(writer, body_data))
  }
  for i, layer in layers {
    pptx_push_layer_index(layer.data, page_index, i, index_runs, index_budget)
  }
  let layer_json : Array[Json] = []
  for i, layer in layers {
    layer_json.push(pptx_layer_json(roles[i], layer.hash))
  }
  Json::object({
    "w": Json::number(width, repr=width.to_string()),
    "h": Json::number(height, repr=height.to_string()),
    "layers": Json::array(layer_json),
  })
}
