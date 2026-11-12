///|
/// The JavaScript bridge of the BDF→PDF writer, for the public npm entry
/// `bdf.mbt/pdf` (`dist/pdf/pdf_js.js`). The exported function never raises
/// across the FFI: every call returns a `PdfJsReport`, a plain object on the
/// JavaScript side with an `ok` boolean, the `pdf` bytes (a `Uint8Array` on
/// the JavaScript side), the page and embedded-font counts, the warnings of
/// the writer unchanged and in order, and, when `ok` is false, the `error`
/// that the caller of the public API rejects with. The thin wrapper module
/// `dist/pdf/index.js` maps this report onto the typed
/// `exportPdf(input, options?)` contract.
///
/// The options are a JSON text: `{"views":["..."],"tagged":false,
/// "compress":false}`. The fields are the writer's own options: `views` is
/// empty or absent for every view, `tagged` and `compress` default to
/// false. A view that the document does not have is a rejection, not
/// silently no pages; the same holds for a successful write whose selected
/// views hold no page. The third parameter is the fallback font program
/// (TrueType or OpenType) whose subset the writer embeds for the text that
/// the document carries no font of; an empty byte string is no fallback.
///
/// The input is never modified: the writer only reads it, and the report
/// holds a fresh `Bytes` of the written PDF.

///|
/// The report `bdf_pdf_export` returns. On the JavaScript side the fields
/// are plain properties: `ok` and `error`, the `pdf` bytes (a
/// `Uint8Array`), the `pages` and `fonts` counts and the `warnings` as a
/// JavaScript array of strings, so the wrapper reads them without any
/// conversion.
pub(all) struct PdfJsReport {
  ok : Bool
  error : String
  pdf : Bytes
  pages : Int32
  fonts : Int32
  warnings : FixedArray[String]
}

///|
/// A rejection report: no PDF is written, `pdf` is empty.
fn pdf_js_reject(message : String) -> PdfJsReport {
  {
    ok: false,
    error: message,
    pdf: b"",
    pages: 0,
    fonts: 0,
    warnings: pdf_js_strings([]),
  }
}

///|
/// The dynamic array of the writer's warnings as the JavaScript array the
/// report hands to the wrapper.
fn pdf_js_strings(values : Array[String]) -> FixedArray[String] {
  FixedArray::makei(values.length(), index => values[index])
}

///|
/// The options of the bridge, the writer's own fields.
struct PdfJsOptions {
  views : Array[String]
  tagged : Bool
  compress : Bool
}

///|
/// The parsed options, or the text of the rejection they call for.
fn pdf_js_options(text : String) -> Result[PdfJsOptions, String] {
  let trimmed = text.trim()
  if trimmed == "" {
    return Ok({ views: [], tagged: false, compress: false })
  }
  let parsed = @json.parse(trimmed) catch {
    _ => return Err("the options are not a JSON object")
  }
  let object = match parsed {
    Json::Object(object) => object
    _ => return Err("the options are not a JSON object")
  }
  let views : Array[String] = []
  match object.get("views") {
    Some(Json::Array(items)) =>
      for item in items {
        match item {
          Json::String(view) => views.push(view)
          _ => return Err("the views option is an array of view ids")
        }
      }
    Some(_) => return Err("the views option is an array of view ids")
    None => ()
  }
  let tagged = match object.get("tagged") {
    Some(Json::True) => true
    Some(Json::False) => false
    Some(_) => return Err("the tagged option is a boolean")
    None => false
  }
  let compress = match object.get("compress") {
    Some(Json::True) => true
    Some(Json::False) => false
    Some(_) => return Err("the compress option is a boolean")
    None => false
  }
  Ok({ views, tagged, compress })
}

///|
/// Whether the document has a view of the given id.
fn pdf_js_has_view(
  document : @core.Document,
  id : String,
) -> Bool {
  for view in document.manifest.views {
    if view.id == id {
      return true
    }
  }
  false
}

///|
/// Write a single-file BDF document as PDF, for the public npm API
/// `bdf.mbt/pdf`. `options` is the JSON of `views`, `tagged` and `compress`;
/// `fallback_font` is the caller's fallback font program, or empty for
/// none. The report rejects (instead of a success with no page) when the
/// BDF cannot be read, an option is invalid, a requested view is missing or
/// the selected views hold no page.
#export_name("bdf_pdf_export")
pub fn bdf_pdf_export(
  input : Bytes,
  options : String,
  fallback_font : Bytes,
) -> PdfJsReport {
  if input.length() == 0 {
    return pdf_js_reject("the BDF document is empty")
  }
  let options = match pdf_js_options(options) {
    Ok(options) => options
    Err(message) => return pdf_js_reject(message)
  }
  let document = @core.open_single(input) catch {
    @core.BadFormat(message) =>
      return pdf_js_reject("the BDF document could not be read: " + message)
    @core.Unsupported(message) =>
      return pdf_js_reject("the BDF document could not be read: " + message)
    _ => return pdf_js_reject("the BDF document could not be read")
  }
  for view in options.views {
    if !pdf_js_has_view(document, view) {
      return pdf_js_reject("the document has no view named \"" + view + "\"")
    }
  }
  let fallback = if fallback_font.length() == 0 {
    None
  } else {
    Some(fallback_font)
  }
  let result = @export_pdf.write_document(
    document,
    {
      views: options.views,
      tagged: options.tagged,
      compress: options.compress,
      fallback_font: fallback,
    },
  ) catch {
    _ => return pdf_js_reject("the PDF could not be written")
  }
  if result.pages == 0 {
    return pdf_js_reject(
      "the selected views hold no page, so the PDF would have no page",
    )
  }
  {
    ok: true,
    error: "",
    pdf: result.bytes,
    pages: result.pages,
    fonts: result.fonts,
    warnings: pdf_js_strings(result.warnings),
  }
}
