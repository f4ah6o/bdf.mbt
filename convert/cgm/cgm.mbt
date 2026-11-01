///|
/// A CGM conversion failure.
pub suberror CgmError {
  CgmInvalid(String)
}

///|
pub(all) struct CgmResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
/// Detect a binary or clear-text CGM metafile.
pub fn detect(data : Bytes) -> Bool {
  if data.length() >= 2 && data[0] == 0x1f && data[1] == 0x8b {
    return true
  }
  if data.length() >= 4 && data[0] == 0 && data[1] != 0 && (data[1] & 0xe0) == 0x20 {
    return true
  }
  let head = @utf8.decode_lossy(data[:Int::min(data.length(), 4096)].to_owned()).to_upper()
  head.contains("BEGMF")
}

///|
/// Convert a CGM metafile into a fixed-view BDF document.
///
/// This subset covers the binary encoding, pictures, polylines, markers,
/// polygons, rectangles, circles, arcs, ellipses, text and line/fill/text
/// attributes. Clear text, gzip, cell arrays, tiles and hatches are
/// documented gaps.
pub fn convert(
  data : Bytes,
  title~ : String = "",
  no_text_index~ : Bool = false,
  db~ : @fontdb.Database? = None,
) -> CgmResult raise CgmError {
  if data.length() > 1073741824 {
    raise CgmInvalid("cgm: the file is larger than 1073741824 bytes")
  }
  let elements = try {
    read_cgm_elements(data)
  } catch {
    Failure(message) => raise CgmInvalid(message)
    _ => raise CgmInvalid("cgm: not a CGM metafile")
  }
  if elements.is_empty() {
    raise CgmInvalid("cgm: not a CGM metafile")
  }
  let fonts = @canvas.Fonts::new(db)
  let warnings : Array[String] = []
  if !fonts.has_fonts() {
    warnings.push("no fonts found; text is laid out with estimated metrics and not embedded")
  }
  let interp : CgmInterp = {
    state: cgm_state(),
    pictures: [],
    current: None,
    drawing: @cad.Drawing::new(),
    fonts,
    warnings,
    warned: Map([]),
    unknown: Map([]),
  }
  for element in elements {
    interp.element(element)
  }
  if interp.current is Some(_) {
    interp.end_picture()
  }
  if interp.pictures.is_empty() {
    raise CgmInvalid("cgm: the metafile has no pictures")
  }
  for (key, count) in interp.unknown {
    interp.warn_once("element:" + key, count.to_string() + " unsupported element(s) " + key + " are not drawn")
  }
  let meta = @cad.document_meta("cgm", title=title)
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let pages_json : Array[Json] = []
  let index_runs : Array[@core.IndexRun] = []
  let mut page_number = 0
  for picture in interp.pictures {
    let width = picture.width * 72.0 / 25.4
    let height = picture.height * 72.0 / 25.4
    if width <= 0.0 || height <= 0.0 {
      continue
    }
    let canvas = @canvas.Canvas::new()
    canvas.object().set_bbox(0.0F, 0.0F, @canvas.f32(width), @canvas.f32(height))
    canvas.object().fill_color(picture.background)
    canvas.object().fill_rect(0.0F, 0.0F, @canvas.f32(width), @canvas.f32(height))
    canvas.set_drawn()
    let view : @cad.Rect = {
      min: { x: 0.0, y: 0.0 },
      max: { x: width, y: height },
      ok: true,
    }
    let plotter = @cad.Plotter::new(interp.fonts, thin=0.1 * 72.0 / 25.4)
    plotter.plot(canvas, picture.drawing, picture.matrix, view) catch {
      error => raise CgmInvalid("cgm: " + error.to_string())
    }
    let hash = canvas.encode(writer, interp.fonts, interp.warnings) catch {
      error => raise CgmInvalid("cgm: " + error.to_string())
    }
    pages_json.push(@cad.page(width, height, [@cad.layer("body", hash)]))
    if !no_text_index {
      for (text, _) in picture.drawing.texts() {
        if text == "" { continue }
        index_runs.push({
          a: page_number,
          b: 0,
          ordinal: index_runs.length(),
          separator: 2,
          text,
        })
      }
    }
    page_number += 1
  }
  let view = @cad.fixed_view(pages_json, title=title)
  let view_map = match view {
    Json::Object(value) => value
    _ => Map([])
  }
  if !no_text_index && !index_runs.is_empty() {
    let index_hash = writer.add_part("idx", @core.encode_text_index(index_runs)) catch {
      error => raise CgmInvalid("cgm: " + error.to_string())
    }
    view_map["textIndex"] = Json::string(index_hash)
  }
  writer.add_view(Json::object(view_map))
  let bdf = writer.write_single() catch {
    error => raise CgmInvalid("cgm: " + error.to_string())
  }
  {
    bdf,
    pages: page_number,
    summary: "\{page_number} page(s)",
    warnings: interp.warnings.copy(),
  }
}
