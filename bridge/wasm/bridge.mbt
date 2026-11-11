///|
fn error_json(message : String) -> String {
  Json::object({ "ok": Json::boolean(false), "error": Json::string(message) }).stringify()
}

///|
fn decode_input(input : String) -> Bytes? {
  Some(@base64.decode(input)) catch {
    _ => None
  }
}

///|
fn warnings_json(warnings : Array[String]) -> Json {
  let items : Array[Json] = []
  for warning in warnings {
    items.push(Json::string(warning))
  }
  Json::array(items)
}

///|
/// Convert a PDF file (base64) into BDF. The password is only used for
/// encrypted PDFs and may be empty.
#export_name("bdf_wasm_pdf")
pub fn wasm_pdf(input : String, password : String) -> String {
  let data = match decode_input(input) {
    Some(data) => data
    None => return error_json("base64 を読み取れませんでした")
  }
  let result = @pdf_convert.convert(data, password~) catch {
    _ => return error_json("PDF を変換できませんでした")
  }
  Json::object({
    "ok": Json::boolean(true),
    "pages": Json::number(result.pages.to_double()),
    "bdf": Json::string(@base64.encode(result.bdf)),
  }).stringify()
}

///|
fn export_pdf_json(input : String, tagged : Int32, font : String) -> String {
  let data = match decode_input(input) {
    Some(data) => data
    None => return error_json("base64 を読み取れませんでした")
  }
  let fallback = if font == "" {
    None
  } else {
    match decode_input(font) {
      Some(font) => Some(font)
      None => return error_json("フォントを読み取れませんでした")
    }
  }
  let options : @export_pdf.PdfOptions = {
    views: [],
    tagged: tagged != 0,
    compress: false,
    fallback_font: fallback,
  }
  let result = @export_pdf.write_bytes(data, options) catch {
    _ => return error_json("PDF を書き出せませんでした")
  }
  Json::object({
    "ok": Json::boolean(true),
    "pages": Json::number(result.pages.to_double()),
    "fonts": Json::number(result.fonts.to_double()),
    "warnings": warnings_json(result.warnings),
    "pdf": Json::string(@base64.encode(result.bytes)),
  }).stringify()
}

///|
/// Write a BDF file (base64) as PDF. The result is base64 in JSON.
#export_name("bdf_wasm_export_pdf")
pub fn wasm_export_pdf(input : String, tagged : Int32) -> String {
  export_pdf_json(input, tagged, "")
}

///|
/// Write a BDF file (base64) as PDF, drawing the text whose own font the
/// document does not carry with the font (base64, TrueType or OpenType) that
/// the caller gives. The writer embeds a subset of it, so Japanese and the
/// lines of a form keep their characters.
#export_name("bdf_wasm_export_pdf_font")
pub fn wasm_export_pdf_font(
  input : String,
  tagged : Int32,
  font : String,
) -> String {
  export_pdf_json(input, tagged, font)
}

///|
/// Write a BDF file (base64) as Markdown. The images option is one of
/// "zip", "embed", or "none".
#export_name("bdf_wasm_markdown")
pub fn wasm_markdown(input : String, images : String) -> String {
  let data = match decode_input(input) {
    Some(data) => data
    None => return error_json("base64 を読み取れませんでした")
  }
  let base = @export_md.MarkdownOptions::new()
  let options : @export_md.MarkdownOptions = {
    views: base.views,
    skip_roles: base.skip_roles,
    internal_links: base.internal_links,
    keep_running: base.keep_running,
    tables: base.tables,
    images,
  }
  let result = @export_md.write_bytes(data, options) catch {
    _ => return error_json("Markdown を書き出せませんでした")
  }
  let files : Array[Json] = []
  for file in result.files {
    files.push(
      Json::object({
        "name": Json::string(file.name),
        "bytes": Json::string(@base64.encode(file.bytes)),
      }),
    )
  }
  Json::object({
    "ok": Json::boolean(true),
    "markdown": Json::string(result.markdown),
    "files": Json::array(files),
    "warnings": warnings_json(result.warnings),
    "views": Json::number(result.views.to_double()),
    "images": Json::number(result.images.to_double()),
    "tables": Json::number(result.tables.to_double()),
  }).stringify()
}

///|
/// Extract the page records used by the upstream text and MiniSearch tools.
#export_name("bdf_wasm_search_text")
pub fn wasm_search_text(input : String) -> String {
  let data = match decode_input(input) {
    Some(data) => data
    None => return error_json("base64 を読み取れませんでした")
  }
  let result = @export_search.search_text_bytes(data) catch {
    _ => return error_json("テキストを取り出せませんでした")
  }
  Json::object({
    "ok": Json::boolean(true),
    "text": Json::string(result.json),
    "plain": Json::string(result.plain),
    "views": Json::number(result.views.to_double()),
    "pages": Json::number(result.pages.to_double()),
  }).stringify()
}

///|
/// Convert a file of any supported format (base64) into BDF. The format is
/// detected the same way the browser converter detects it when format is empty.
#export_name("bdf_wasm_convert")
pub fn wasm_convert(input : String, name : String, format : String) -> String {
  let data = match decode_input(input) {
    Some(data) => data
    None => return error_json("base64 を読み取れませんでした")
  }
  let result = @all.convert(data, format=format, name=name) catch {
    @all.AllFailure(message) => return error_json(message)
  }
  Json::object({
    "ok": Json::boolean(true),
    "format": Json::string(result.format),
    "summary": Json::string(result.summary),
    "warnings": warnings_json(result.warnings),
    "bdf": Json::string(@base64.encode(result.bdf)),
  }).stringify()
}
