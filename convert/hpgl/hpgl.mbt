///|
/// An HP-GL/2 conversion failure.
pub suberror HpglError {
  HpglInvalid(String)
}

///|
pub(all) struct HpglResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
/// Convert an HP-GL/2, HP-GL or HP RTL plot into a fixed-view BDF document.
pub fn convert(
  data : Bytes,
  title~ : String = "",
  colors~ : String = "",
  no_text_index~ : Bool = false,
  db~ : @fontdb.Database? = None,
) -> HpglResult raise HpglError {
  if data.length() > 1073741824 {
    raise HpglInvalid("hpgl: the file is larger than 1073741824 bytes")
  }
  let mono = match colors {
    "" | "pens" => false
    "mono" => true
    _ => raise HpglInvalid("hpgl: parameter colors: \"" + colors + "\" is not pens or mono")
  }
  let converter = HpglConverter::new(data, mono)
  converter.run()
  let head = data[:Int::min(data.length(), 1024)].to_owned()
  if converter.instructions < 3 && !detect(head) {
    raise HpglInvalid("hpgl: the input is not an HP-GL/2 plot")
  }
  if converter.pages.is_empty() {
    let page = HpglPage::new()
    converter.pages.push(page)
  }
  let document_title = if title != "" {
    title
  } else if converter.title != "" {
    converter.title
  } else {
    converter.job_name
  }
  let fonts = @canvas.Fonts::new(db)
  if converter.has_text && !fonts.has_fonts() {
    converter.gl.warn_once(
      "fonts",
      "no fonts found; text is laid out with estimated metrics and not embedded",
    )
  }
  let meta = @cad.document_meta("hpgl", title=document_title)
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let pages_json : Array[Json] = []
  let index_runs : Array[@core.IndexRun] = []
  let plotter = @cad.Plotter::new(fonts, thin=0.1 * 72.0 / 25.4)
  let mut page_number = 0
  let sizes : Array[(Double, Double)] = []
  for page in converter.pages {
    let (matrix, width, height) = page_transform(page)
    let canvas = @canvas.Canvas::new()
    canvas.object().set_bbox(
      0.0F,
      0.0F,
      @canvas.f32(width),
      @canvas.f32(height),
    )
    canvas.object().fill_color(0xffffffffU)
    canvas.object().fill_rect(
      0.0F,
      0.0F,
      @canvas.f32(width),
      @canvas.f32(height),
    )
    canvas.set_drawn()
    let view : @cad.Rect = {
      min: { x: 0.0, y: 0.0 },
      max: { x: width, y: height },
      ok: true,
    }
    plotter.plot(canvas, page.drawing, matrix, view) catch {
      error => raise HpglInvalid("hpgl: plot: " + error.to_string())
    }
    let hash = canvas.encode(writer, fonts, converter.gl.warnings) catch {
      error => raise HpglInvalid("hpgl: object: " + error.to_string())
    }
    pages_json.push(
      @cad.page(width, height, [@cad.layer("body", hash)]),
    )
    sizes.push((width * 25.4 / 72.0, height * 25.4 / 72.0))
    if !no_text_index {
      for (text, bounds) in page.drawing.texts() {
        if is_blank_string(text) {
          continue
        }
        let _ = bounds
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
  let view = @cad.fixed_view(pages_json, title=document_title)
  let view_map = match view {
    Json::Object(value) => value
    _ => Map([])
  }
  if !no_text_index && !index_runs.is_empty() {
    let hash = writer.add_part("idx", @core.encode_text_index(index_runs)) catch {
      error => raise HpglInvalid("hpgl: text index: " + error.to_string())
    }
    view_map["textIndex"] = Json::string(hash)
  }
  writer.add_view(Json::object(view_map))
  let bdf = writer.write_single() catch {
    error => raise HpglInvalid("hpgl: write: " + error.to_string())
  }
  let pages = pages_json.length()
  let mut summary = if pages == 1 {
    let (width, height) = sizes[0]
    "1 page (\{width.round().to_int()} × \{height.round().to_int()} mm)"
  } else {
    "\{pages} page(s)"
  }
  summary += ", 0 embedded font(s)"
  {
    bdf,
    pages,
    summary,
    warnings: converter.gl.warnings.copy(),
  }
}

///|
fn page_transform(page : HpglPage) -> (@canvas.Matrix, Double, Double) {
  let bounds = page.drawing.bounds()
  let view = page.view
  let mut rect = @cad.Rect::empty()
  if page.hard.is_valid() {
    rect = page.hard.transform(view)
  }
  if bounds.is_valid() {
    let mut visible = bounds.transform(view)
    if !rect.is_valid() {
      visible = visible
        .add({
          x: visible.min.x - HPGL_PAGE_MARGIN,
          y: visible.min.y - HPGL_PAGE_MARGIN,
        })
        .add({
          x: visible.max.x + HPGL_PAGE_MARGIN,
          y: visible.max.y + HPGL_PAGE_MARGIN,
        })
    }
    rect = rect.union(visible)
  }
  if !rect.is_valid() {
    rect = {
      min: { x: 0.0, y: 0.0 },
      max: { x: HPGL_DEFAULT_HARD_W, y: HPGL_DEFAULT_HARD_H },
      ok: true,
    }
  }
  let width = Double::min(Double::max(rect.w(), 40.0), 8.0e6)
  let height = Double::min(Double::max(rect.h(), 40.0), 8.0e6)
  let base : @canvas.Matrix = {
    a: HPGL_PLU,
    b: 0.0,
    c: 0.0,
    d: -HPGL_PLU,
    e: -rect.min.x * HPGL_PLU,
    f: rect.max.y * HPGL_PLU,
  }
  (base.mul(view), width * HPGL_PLU, height * HPGL_PLU)
}
