///|
// A plain-text form as a fixed BDF view: each character in its grid column,
// with the print image as the "text" part.
const BASELINE : Double = 0.88

///|
pub suberror TextFormError {
  TextFormError(String)
}

///|
priv struct TextRun {
  mut text : String
  col : Int
  mut cols : Int
  paper : Bool
  tall : Bool
}

///|
fn textform_runs(image : @textpart.Image, line : @textpart.Line) -> Array[TextRun] {
  let out : Array[TextRun] = []
  let mut current : TextRun? = None
  for cell in image.cells(line) {
    if cell.cols == 0 {
      match current {
        Some(run) => run.text += cell.text
        None => ()
      }
      continue
    }
    let paper = cell.paper
    let tall = cell.size == @textpart.SIZE_TALL || cell.size == @textpart.SIZE_BIG
    let joins = match current {
      Some(run) =>
        run.paper == paper &&
        run.tall == tall &&
        run.col + run.cols == cell.col
      None => false
    }
    if cell.text == " " {
      if joins {
        let run = current.unwrap()
        run.text += cell.text
        run.cols += cell.cols
        continue
      }
      current = None
      continue
    }
    if joins {
      let run = current.unwrap()
      run.text += cell.text
      run.cols += cell.cols
      continue
    }
    let run : TextRun = {
      text: cell.text,
      col: cell.col,
      cols: cell.cols,
      paper,
      tall,
    }
    out.push(run)
    current = Some(run)
  }
  out
}

///|
/// Lay a filled text form out as a fixed view and return the BDF bytes.
pub fn render(
  image : @textpart.Image,
  title : String,
) -> Bytes raise {
  render_with_tables(image, [], title)
}

///|
/// Lay a filled text form out with the table of each line (0 for none),
/// keeping the pages that the "pages" option names.
pub fn render_with_tables(
  image : @textpart.Image,
  tables : Array[Array[Int]],
  title : String,
  pages~ : String = "",
) -> Bytes raise {
  let selected : Array[@textpart.Page] = []
  let selected_tables : Array[Array[Int]] = []
  let wanted = if pages == "" {
    None
  } else {
    @convert.page_numbers(
      @convert.parse_pages(pages),
      image.pages.length().to_int64(),
    )
  }
  match wanted {
    None =>
      for i, page in image.pages {
        selected.push(page)
        selected_tables.push(if i < tables.length() { tables[i] } else { [] })
      }
    Some(numbers) =>
      for number in numbers {
        let n = number.to_int()
        if n >= 1 && n <= image.pages.length() {
          selected.push(image.pages[n - 1])
          selected_tables.push(if n - 1 < tables.length() { tables[n - 1] } else { [] })
        }
      }
  }
  let cw = 72.0 / image.cpi
  let rh = 72.0 / image.lpi
  let x0 = image.margin.left.to_double() * cw
  let y0 = image.margin.top.to_double() * rh
  let width = image.columns.to_double() * cw
  let output_image : @textpart.Image = {
    version: image.version,
    cpi: image.cpi,
    lpi: image.lpi,
    columns: image.columns,
    lines: image.lines,
    margin: image.margin,
    skip: image.skip,
    ambiguous_wide: image.ambiguous_wide,
    font: image.font,
    pages: selected,
  }
  let meta : Map[String, Json] = Map([])
  meta["source"] = Json::string("text")
  if title != "" {
    meta["title"] = Json::string(title)
  }
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let view_pages : Array[Json] = []
  let index_runs : Array[@core.IndexRun] = []
  for pi, page in selected {
    let height = if image.lines == 0 {
      (image.margin.top + Int::max(1, page.lines.length())).to_double() * rh
    } else {
      image.lines.to_double() * rh
    }
    let body = @core.ObjectBuilder::new()
    let paper = @core.ObjectBuilder::new()
    for object in [body, paper] {
      object.set_bbox(
        0.0F,
        0.0F,
        Float::from_double(width),
        Float::from_double(height),
      )
      object.fill_color(0x000000ffU)
    }
    let font = body.add_font({
      hash: None,
      family: if image.font == "" { "monospace" } else { image.font },
      weight: 400,
      style: 0,
    })
    let paper_font = paper.add_font({
      hash: None,
      family: if image.font == "" { "monospace" } else { image.font },
      weight: 400,
      style: 0,
    })
    let mut body_drawn = false
    let mut paper_drawn = false
    let mut table = 0
    let mut cell_row = 0
    for li, line in page.lines {
      let runs = textform_runs(image, line)
      if runs.is_empty() {
        continue
      }
      let mut row = li + 1
      if line.size.any(fn(range) { range.size == @textpart.SIZE_TALL || range.size == @textpart.SIZE_BIG }) {
        row += 1
      }
      let y = y0 + (row.to_double() - (1.0 - BASELINE)) * rh
      let mut has_body = false
      let mut has_paper = false
      for run in runs {
        if run.paper {
          has_paper = true
        } else {
          has_body = true
        }
      }
      let table_id = if pi < selected_tables.length() &&
        li < selected_tables[pi].length() {
        selected_tables[pi][li]
      } else {
        0
      }
      if has_body {
        if table_id != table {
          if table != 0 {
            body.mark(@core.MARK_END, "")
          }
          table = table_id
          cell_row = 0
          if table != 0 {
            body.mark(@core.MARK_TABLE, "")
          }
        }
        if table != 0 {
          cell_row += 1
          body.mark(@core.MARK_CELL, "A" + cell_row.to_string())
        } else {
          body.mark(@core.MARK_PARAGRAPH, "")
        }
        body_drawn = true
      }
      if has_paper {
        paper.mark(@core.MARK_PARAGRAPH, "")
        paper_drawn = true
      }
      for run in runs {
        let object = if run.paper { paper } else { body }
        let font_index = if run.paper { paper_font } else { font }
        let size = if run.tall { rh * 2.0 } else { rh }
        object.font(font_index, Float::from_double(size))
        object.fill_text(
          run.text,
          Float::from_double(x0 + run.col.to_double() * cw),
          Float::from_double(y),
          Float::from_double(run.cols.to_double() * cw),
        )
      }
    }
    if table != 0 {
      body.mark(@core.MARK_END, "")
    }
    let body_bytes = if body_drawn || !paper_drawn {
      body.encode() catch {
        _ => raise TextFormError("text: the page could not be encoded")
      }
    } else {
      Bytes::new(0)
    }
    let paper_bytes = if paper_drawn {
      paper.encode() catch {
        _ => raise TextFormError("text: the paper could not be encoded")
      }
    } else {
      Bytes::new(0)
    }
    let layers : Array[Json] = []
    if paper_drawn {
      let hash = writer.add_part("obj", paper_bytes) catch {
        _ => raise TextFormError("text: the paper could not be stored")
      }
      layers.push(Json::object({
        "role": Json::string("background"),
        "obj": Json::string(hash),
      }))
    }
    let body_hash = if body_drawn || !paper_drawn {
      let hash = writer.add_part("obj", body_bytes) catch {
        _ => raise TextFormError("text: the page could not be stored")
      }
      layers.push(Json::object({
        "role": Json::string("body"),
        "obj": Json::string(hash),
      }))
      hash
    } else {
      ""
    }
    if body_hash != "" {
      let resources = @core.decode_object_resources(body_bytes) catch {
        _ => raise TextFormError("text: the page is not a BDF object")
      }
      let content = @render.extract_text(resources, fn(_) { None }) catch {
        _ => { runs: [], links: [], nodes: [] }
      }
      for i, run in content.runs {
        index_runs.push({
          a: pi,
          b: 0,
          ordinal: run.ordinal,
          separator: if i == 0 { 2 } else { run.separator },
          text: run.text,
        })
      }
    }
    view_pages.push(Json::object({
      "w": Json::number(width),
      "h": Json::number(height),
      "layers": Json::array(layers),
    }))
  }
  let view : Map[String, Json] = Map([])
  view["id"] = Json::string("pages")
  view["kind"] = Json::string("fixed")
  if title != "" {
    view["title"] = Json::string(title)
  }
  view["pages"] = Json::array(view_pages)
  if !index_runs.is_empty() {
    let encoded = @core.encode_text_index(index_runs)
    let hash = writer.add_part("idx", encoded) catch {
      _ => raise TextFormError("text: the text index could not be stored")
    }
    view["textIndex"] = Json::string(hash)
  }
  writer.add_view(Json::object(view))
  ignore(output_image.add_to(writer) catch {
    _ => raise TextFormError("text: the print image could not be stored")
  })
  writer.write_single() catch {
    _ => raise TextFormError("text: the BDF could not be written")
  }
}

///|
/// A filled text form ready to write: its BDF bytes and print image.
pub(all) struct TextFormResult {
  bdf : Bytes
  image : @textpart.Image
}

///|
/// Fill and lay out a text template in one step.
pub fn convert(
  template : String,
  data : Map[String, Json],
  title : String,
  pages~ : String = "",
) -> TextFormResult raise {
  let filled = @textform.fill_result(data, template)
  let bdf = render_with_tables(filled.image, filled.tables, title, pages~)
  { bdf, image: filled.image }
}

///|
/// Fill and lay out a text template from form/data sources.
pub fn convert_sources(
  template : String,
  sources : Array[@data.Source],
  title : String,
  pages~ : String = "",
) -> TextFormResult raise {
  let filled = @textform.fill_sources(template, sources)
  let bdf = render_with_tables(filled.image, filled.tables, title, pages~)
  { bdf, image: filled.image }
}

