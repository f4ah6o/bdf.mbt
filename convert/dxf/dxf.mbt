///|
/// A DXF conversion failure.
pub suberror DxfError {
  DxfInvalid(String)
}

///|
pub(all) struct DxfResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
/// Detect an ASCII or binary DXF drawing.
pub fn detect(data : Bytes) -> Bool {
  if data.has_prefix(b"AutoCAD Binary DXF") {
    return true
  }
  let head = data[:Int::min(data.length(), 4096)].to_owned()
  let text = @utf8.decode_lossy(head)
  text.contains("SECTION") && (text.contains("HEADER") || text.contains("ENTITIES"))
}

///|
fn dxf_header_point(drawing : DxfDrawing, name : String) -> @cad.Point? {
  match drawing.header.get(name) {
    None => None
    Some(values) => {
      let mut x = 0.0
      let mut y = 0.0
      let mut has = false
      for tag in values {
        if tag.code == 10 {
          x = tag.f
          has = true
        }
        if tag.code == 20 {
          y = tag.f
        }
      }
      if has { Some({ x, y }) } else { None }
    }
  }
}

///|
/// Convert a DXF drawing into a fixed-view BDF document.
pub fn convert(
  data : Bytes,
  title~ : String = "",
  views~ : String = "all",
  light~ : Bool = false,
  no_text_index~ : Bool = false,
  db~ : @fontdb.Database? = None,
) -> DxfResult raise DxfError {
  if data.length() > 1073741824 {
    raise DxfInvalid("dxf: the file is larger than 1073741824 bytes")
  }
  let tags = try {
    read_tags(data)
  } catch {
    Failure(message) => raise DxfInvalid(message)
    _ => raise DxfInvalid("dxf: not a DXF file")
  }
  let drawing = parse_dxf(tags)
  let entities : Array[DxfEntity] = []
  for entity in drawing.entities {
    if entity.int(67, 0) != 1 {
      entities.push(entity)
    }
  }
  match drawing.blocks.get("*MODEL_SPACE") {
    Some(block) => entities.append(block.entities)
    None => ()
  }
  if views.to_lower() == "layouts" {
    raise DxfInvalid("dxf: layouts are not supported yet")
  }
  let fonts = @canvas.Fonts::new(db)
  let warnings : Array[String] = []
  if !fonts.has_fonts() {
    warnings.push("no fonts found; text is laid out with estimated metrics and not embedded")
  }
  let drawing_out = @cad.Drawing::new()
  let context : DxfCtx = {
    drawing: drawing_out,
    matrix: @canvas.Matrix::identity(),
    dark: !light,
    plot: false,
    frozen: Map([]),
    ins_layer: "",
    by_block: 0xffffffffU,
    fonts,
    depth: 0,
  }
  context.draw_entities(drawing, entities)
  let mut has_hatch = false
  let mut has_ocs = false
  let mut has_dimension = false
  let mut has_spline = false
  for entity in entities {
    if entity.typ == "HATCH" { has_hatch = true }
    if entity.num(230, 1.0) < 0.0 || entity.num(220, 0.0) != 0.0 || entity.num(210, 0.0) != 0.0 { has_ocs = true }
    if entity.typ == "DIMENSION" || entity.typ == "LEADER" || entity.typ == "MULTILEADER" { has_dimension = true }
    if entity.typ == "SPLINE" { has_spline = true }
  }
  if has_hatch {
    warnings.push("HATCH entities are not drawn yet")
  }
  if has_ocs {
    warnings.push("entities whose OCS normal is not +Z are not drawn")
  }
  if has_dimension {
    warnings.push("DIMENSION, LEADER and MULTILEADER entities are not drawn yet")
  }
  if has_spline {
    warnings.push("SPLINE entities are drawn as their control polygons")
  }
  let mut bounds = drawing_out.bounds()
  if !bounds.is_valid() {
    match (dxf_header_point(drawing, "$EXTMIN"), dxf_header_point(drawing, "$EXTMAX")) {
      (Some(low), Some(high)) =>
        if high.x > low.x && high.y > low.y {
          bounds = @cad.Rect::empty().add(low).add(high)
        }
      _ => ()
    }
  }
  if !bounds.is_valid() {
    bounds = @cad.Rect::empty().add({ x: 0.0, y: 0.0 }).add({ x: 297.0, y: 210.0 })
  }
  let w = bounds.w()
  let h = bounds.h()
  let model_size = 420.0 * 72.0 / 25.4
  let margin = model_size * 0.03
  let scale = (model_size - 2.0 * margin) / Double::max(Double::max(w, h), 1.0e-9)
  let mut page_w = w * scale + 2.0 * margin
  let mut page_h = h * scale + 2.0 * margin
  page_w = Double::max(page_w, 4.0 * margin)
  page_h = Double::max(page_h, 4.0 * margin)
  let ox = (page_w - w * scale) / 2.0
  let oy = (page_h - h * scale) / 2.0
  let matrix : @canvas.Matrix = {
    a: scale,
    b: 0.0,
    c: 0.0,
    d: -scale,
    e: ox - bounds.min.x * scale,
    f: oy + bounds.max.y * scale,
  }
  let meta = @cad.document_meta("dxf", title=title)
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let canvas = @canvas.Canvas::new()
  canvas.object().set_bbox(0.0F, 0.0F, @canvas.f32(page_w), @canvas.f32(page_h))
  let background = if !light { 0x303821ffU } else { 0xffffffffU }
  canvas.object().fill_color(background)
  canvas.object().fill_rect(0.0F, 0.0F, @canvas.f32(page_w), @canvas.f32(page_h))
  canvas.set_drawn()
  let view : @cad.Rect = {
    min: { x: 0.0, y: 0.0 },
    max: { x: page_w, y: page_h },
    ok: true,
  }
  let plotter = @cad.Plotter::new(fonts, thin=0.1 * 72.0 / 25.4)
  plotter.plot(canvas, drawing_out, matrix, view) catch {
    error => raise DxfInvalid("dxf: " + error.to_string())
  }
  let hash = canvas.encode(writer, fonts, warnings) catch {
    error => raise DxfInvalid("dxf: " + error.to_string())
  }
  let page = @cad.page(page_w, page_h, [@cad.layer("body", hash)])
  let view_json = @cad.fixed_view([page], title=title)
  let view_map = match view_json {
    Json::Object(value) => value
    _ => Map([])
  }
  if !no_text_index {
    let runs : Array[@core.IndexRun] = []
    for (text, _) in drawing_out.texts() {
      if text == "" { continue }
      runs.push({
        a: 0,
        b: 0,
        ordinal: runs.length(),
        separator: 2,
        text,
      })
    }
    if !runs.is_empty() {
      let index_hash = writer.add_part("idx", @core.encode_text_index(runs)) catch {
        error => raise DxfInvalid("dxf: " + error.to_string())
      }
      view_map["textIndex"] = Json::string(index_hash)
    }
  }
  writer.add_view(Json::object(view_map))
  let bdf = writer.write_single() catch {
    error => raise DxfInvalid("dxf: " + error.to_string())
  }
  {
    bdf,
    pages: 1,
    summary: "1 page (\{page_w.round().to_int()} × \{page_h.round().to_int()} pt), 0 embedded font(s)",
    warnings,
  }
}
