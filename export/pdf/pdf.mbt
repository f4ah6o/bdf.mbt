///|
/// Options for writing a BDF document as a PDF.
pub(all) struct PdfOptions {
  views : Array[String]
  tagged : Bool
  compress : Bool
  /// A font program (TrueType or OpenType) that draws the text whose own font
  /// the document does not carry, such as the text a form fill writes. The
  /// writer embeds a subset of it, so Japanese and the lines of a form keep
  /// their characters instead of becoming "?".
  fallback_font : Bytes?
}

///|
pub fn PdfOptions::new() -> PdfOptions {
  { views: [], tagged: false, compress: false, fallback_font: None }
}

///|
pub(all) struct PdfResult {
  bytes : Bytes
  pages : Int32
  fonts : Int32
  warnings : Array[String]
}

///|
struct PageInfo {
  page_ref : Int32
  content_ref : Int32
  annots : Array[Int32]
  width : Double
  height : Double
}

///|
fn has(array : Array[String], value : String) -> Bool {
  for item in array {
    if item == value {
      return true
    }
  }
  false
}

///|
fn selected_views(
  document : @core.Document,
  options : PdfOptions,
) -> Array[@core.View] {
  let views : Array[@core.View] = []
  for view in document.manifest.views {
    if options.views.length() == 0 || has(options.views, view.id) {
      views.push(view)
    }
  }
  views
}

///|
fn num(value : Double) -> String {
  if value.abs() < 0.000001 {
    "0"
  } else {
    value.to_string()
  }
}

///|
fn hex_digit(value : Int32) -> Char {
  if value < 10 {
    (48 + value).unsafe_to_char()
  } else {
    (55 + value).unsafe_to_char()
  }
}

///|
fn pdf_string(text : String) -> String {
  let out = StringBuilder()
  out.write_string("<FEFF")
  for ch in text {
    let code = ch.to_int()
    let value = if code > 0xffff { 0xfffd } else { code }
    let high = (value >> 8) & 0xff
    let low = value & 0xff
    out.write_char(hex_digit((high >> 4) & 0xf))
    out.write_char(hex_digit(high & 0xf))
    out.write_char(hex_digit((low >> 4) & 0xf))
    out.write_char(hex_digit(low & 0xf))
  }
  out.write_string(">")
  out.to_string()
}

///|
/// A string of the metadata of a document: the converters of forms write
/// theirs at the top of the metadata, the ones of documents under "dc".
fn meta_string(meta : Json, key : String) -> String {
  match meta.value(key) {
    Some(Json::String(text)) => text
    _ => metadata_string(meta, key)
  }
}

///|
fn metadata_string(meta : Json, key : String) -> String {
  let dc = match meta.value("dc") {
    Some(value) => value
    None => return ""
  }
  match dc.value(key) {
    Some(Json::String(text)) => text
    Some(Json::Array(items)) => {
      for item in items {
        match item {
          Json::String(text) => return text
          _ => ()
        }
      }
      ""
    }
    _ => ""
  }
}

///|
/// Write an opened BDF document as a PDF.
pub fn write_document(
  document : @core.Document,
  options : PdfOptions,
) -> PdfResult raise {
  let views = selected_views(document, options)
  let warnings : Array[String] = []
  if options.tagged {
    warnings.push("tagged PDF structure is not written yet")
  }
  let writer = PdfWriter::new()
  let resources = PdfResources::new(writer)
  let _std = resources.standard_font()
  // The characters of the text that the fallback font has to draw: the
  // writer embeds only their glyphs, so a page of Japanese text adds a few
  // kilobytes rather than the whole font.
  let fallback_codes : Array[Int32] = []
  match options.fallback_font {
    Some(_) => {
      let seen : Map[Int32, Bool] = Map([])
      for view in views {
        for page in view.pages {
          for layer in page.layers {
            let layer_resources = @core.decode_object_resources(
              document.part(layer.object),
            ) catch {
              _ => continue
            }
            collect_text_codepoints(
              document,
              layer_resources,
              0,
              seen,
              fallback_codes,
            )
          }
        }
      }
    }
    None => ()
  }
  match resources.prepare_fallback(options.fallback_font, fallback_codes) {
    Some(warning) => warnings.push(warning)
    None => ()
  }
  // The text of a form sits on a grid of fixed cells: its runs are drawn as
  // wide as the cells they fill, so that the columns and the lines meet.
  let meta = match @core.manifest_json(document.data).value("meta") {
    Some(value) => value
    None => Json::empty_object()
  }
  let grid_text = meta_string(meta, "source") == "text"
  let ambiguous = match meta.value("ambiguousWide") {
    Some(Json::True) => true
    _ => false
  }
  let pages_ref = writer.reserve()
  let page_infos : Array[PageInfo] = []
  for view in views {
    if view.pages.length() == 0 {
      warnings.push("view " + view.id + " has no pages")
      continue
    }
    for page in view.pages {
      let width = if page.width > 0.0 { page.width } else { 612.0 }
      let height = if page.height > 0.0 { page.height } else { 792.0 }
      let content = page_content(
        document,
        resources,
        page,
        height,
        grid_text,
        ambiguous,
      )
      for warning in content.warnings {
        warnings.push(warning)
      }
      let content_ref = writer.add_stream("", @utf8.encode(content.stream))
      let page_ref = writer.reserve()
      page_infos.push({
        page_ref,
        content_ref,
        annots: content.annots,
        width,
        height,
      })
    }
  }
  let resource_dict = resources.finish()
  let missing = resources.missing_text()
  if missing != "" {
    warnings.push("the fallback font has no glyph for: " + missing)
  }
  for info in page_infos {
    let mut annotations = ""
    if info.annots.length() > 0 {
      let refs = StringBuilder()
      for index, id in info.annots {
        if index > 0 {
          refs.write_string(" ")
        }
        refs.write_string(id.to_string())
        refs.write_string(" 0 R")
      }
      annotations = " /Annots [" + refs.to_string() + "]"
    }
    writer.set_string(
      info.page_ref,
      "<< /Type /Page /Parent " +
      pages_ref.to_string() +
      " 0 R /MediaBox [0 0 " +
      num(info.width) +
      " " +
      num(info.height) +
      "] /Resources " +
      resource_dict +
      " /Contents " +
      info.content_ref.to_string() +
      " 0 R" +
      annotations +
      " >>",
    )
  }
  let kids = StringBuilder()
  for index, info in page_infos {
    if index > 0 {
      kids.write_string(" ")
    }
    kids.write_string(info.page_ref.to_string())
    kids.write_string(" 0 R")
  }
  writer.set_string(
    pages_ref,
    "<< /Type /Pages /Kids [" +
    kids.to_string() +
    "] /Count " +
    page_infos.length().to_string() +
    " >>",
  )
  let catalog = writer.add_string(
    "<< /Type /Catalog /Pages " + pages_ref.to_string() + " 0 R >>",
  )
  let title = metadata_string(meta, "title")
  let author = metadata_string(meta, "creator")
  let mut info = "<< /Producer " + pdf_string("bdf.mbt demo")
  if title != "" {
    info = info + " /Title " + pdf_string(title)
  }
  if author != "" {
    info = info + " /Author " + pdf_string(author)
  }
  info = info + " >>"
  let info_ref = writer.add_string(info)
  let font_count = resources.fonts.length() +
    (if resources.std_ref is Some(_) { 1 } else { 0 })
  {
    bytes: writer.write(catalog, Some(info_ref)),
    pages: page_infos.length(),
    fonts: font_count,
    warnings,
  }
}

///|
/// Write a single-file BDF document as a PDF.
pub fn write_bytes(data : Bytes, options : PdfOptions) -> PdfResult raise {
  write_document(@core.open_single(data), options)
}
