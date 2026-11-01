///|
/// An SXF conversion failure.
pub suberror SxfError {
  SxfInvalid(String)
}

///|
pub(all) struct SxfResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
/// Detect an SXF SFC or P21 drawing.
pub fn detect(data : Bytes) -> Bool {
  let head = @utf8.decode_lossy(data[:Int::min(data.length(), 4096)].to_owned())
  head.contains("/*SXF") || head.contains("ISO-10303-21")
}

///|
/// Convert an SXF SFC drawing into a fixed-view BDF document.
///
/// P21/P2Z input is recognized but not ported yet.
pub fn convert(
  data : Bytes,
  title~ : String = "",
  light~ : Bool = false,
  no_text_index~ : Bool = false,
  db~ : @fontdb.Database? = None,
) -> SxfResult raise SxfError {
  if data.length() > 1073741824 {
    raise SxfInvalid("sxf: the file is larger than 1073741824 bytes")
  }
  if data.has_prefix(b"PK\x03\x04") {
    raise SxfInvalid("sxf: zipped P2Z input is not supported yet")
  }
  let text = match @encoding.decode(data, "shift_jis") {
    Ok(value) => value
    Err(_) => @utf8.decode_lossy(data)
  }
  if text.contains("ISO-10303-21") && !text.contains("/*SXF") {
    raise SxfInvalid("sxf: P21 input is not supported yet")
  }
  let features = try {
    read_sfc(text)
  } catch {
    Failure(message) => raise SxfInvalid(message)
    _ => raise SxfInvalid("sxf: the feature comments could not be read")
  }
  if features.is_empty() {
    raise SxfInvalid("sxf: not an SXF SFC file")
  }
  let model = build_sfc_model(features)
  let sheet = match model.sheet {
    Some(value) => value
    None => raise SxfInvalid("sxf: the file has no sheet")
  }
  let fonts = @canvas.Fonts::new(db)
  let warnings : Array[String] = []
  if !fonts.has_fonts() {
    warnings.push("no fonts found; text is laid out with estimated metrics and not embedded")
  }
  let background = if light {
    0xffffffffU
  } else {
    match model.bg {
      Some(value) => value
      None => 0x000000ffU
    }
  }
  let drawing = @cad.Drawing::new()
  let renderer : SfcRenderer = {
    model,
    drawing,
    fonts,
    light,
    bg: background,
    warnings,
    count: 0,
    stack: [],
  }
  for feature in sheet.items {
    renderer.feature(feature, @canvas.Matrix::identity())
  }
  for (name, count) in renderer.model.unknown {
    renderer.warn_once("feature:" + name, count.to_string() + " feature(s) " + name + " are not drawn")
  }
  let (sheet_w, sheet_h) = renderer.model.sheet_size()
  let mut area = @cad.Rect::empty()
  if sheet_w > 0.0 && sheet_h > 0.0 {
    area = area.add({ x: 0.0, y: 0.0 }).add({ x: sheet_w, y: sheet_h })
  }
  let bounds = renderer.drawing.bounds()
  if bounds.is_valid() {
    area = if area.is_valid() { area.union(bounds) } else { bounds }
  }
  if !area.is_valid() {
    area = area.add({ x: 0.0, y: 0.0 }).add({ x: 420.0, y: 297.0 })
  }
  let mm = 72.0 / 25.4
  let page_w = area.w() * mm
  let page_h = area.h() * mm
  let matrix : @canvas.Matrix = {
    a: mm,
    b: 0.0,
    c: 0.0,
    d: -mm,
    e: -area.min.x * mm,
    f: area.max.y * mm,
  }
  let document_title = if title != "" {
    title
  } else {
    match renderer.model.title.get("title") {
      Some(value) => value
      None => ""
    }
  }
  let meta = @cad.document_meta("sfc", title=document_title)
  meta["dc"] = Json::object({
    "title": Json::string(document_title),
    "language": Json::string("ja"),
  })
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let canvas = @canvas.Canvas::new(doc_lang="ja")
  canvas.object().set_bbox(0.0F, 0.0F, @canvas.f32(page_w), @canvas.f32(page_h))
  canvas.object().fill_color(background)
  canvas.object().fill_rect(0.0F, 0.0F, @canvas.f32(page_w), @canvas.f32(page_h))
  canvas.set_drawn()
  let view : @cad.Rect = {
    min: { x: 0.0, y: 0.0 },
    max: { x: page_w, y: page_h },
    ok: true,
  }
  let plotter = @cad.Plotter::new(fonts, thin=0.1 * mm)
  plotter.plot(canvas, renderer.drawing, matrix, view) catch {
    error => raise SxfInvalid("sxf: " + error.to_string())
  }
  let hash = canvas.encode(writer, fonts, renderer.warnings) catch {
    error => raise SxfInvalid("sxf: " + error.to_string())
  }
  let page = @cad.page(page_w, page_h, [@cad.layer("body", hash)])
  let view_json = @cad.fixed_view([page], title=document_title)
  let view_map = match view_json {
    Json::Object(value) => value
    _ => Map([])
  }
  if !no_text_index {
    let runs : Array[@core.IndexRun] = []
    for (text, _) in renderer.drawing.texts() {
      if sfc_blank(text) { continue }
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
        error => raise SxfInvalid("sxf: " + error.to_string())
      }
      view_map["textIndex"] = Json::string(index_hash)
    }
  }
  writer.add_view(Json::object(view_map))
  let bdf = writer.write_single() catch {
    error => raise SxfInvalid("sxf: " + error.to_string())
  }
  {
    bdf,
    pages: 1,
    summary: "1 page (\{area.w().round().to_int()} × \{area.h().round().to_int()} mm), 0 embedded font(s)",
    warnings: renderer.warnings.copy(),
  }
}
