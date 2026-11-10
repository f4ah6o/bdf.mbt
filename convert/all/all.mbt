///|
/// ブラウザの変換 Worker（browser/native_converter_worker.mbt）と同じ呼び方で、
/// 対応する形式を 1 つの入り口から BDF に変換する。JS と wasm-gc のどちらの
/// ビルドでも動くように、ここには Worker のプロトコルも FFI も置かない。
/// オプションは渡されなかったときの値（Worker がオプションなしで受けたときと
/// 同じ結果）だけを扱う。

///|
pub(all) struct Outcome {
  bdf : Bytes
  format : String
  summary : String
  warnings : Array[String]
}

///|
pub suberror AllError {
  AllFailure(String)
}

///|
fn head_bytes(data : Bytes) -> Bytes {
  data[:if data.length() < 1024 { data.length() } else { 1024 }].to_owned()
}

///|
fn named(lower : String, extensions : Array[String]) -> Bool {
  extensions.iter().any((ext) => lower.has_suffix(ext))
}

///|
fn audio_named(lower : String) -> Bool {
  named(
    lower,
    [
      ".mp3", ".m4a", ".m4b", ".m4p", ".aac", ".flac", ".ogg", ".oga", ".opus",
      ".spx", ".wav", ".wave", ".aif", ".aiff", ".aifc",
    ],
  )
}

///|
fn image_not_supported(message : String) -> Bool {
  message ==
  "image: input is not a supported BMP, ICO, JPEG, PNG, GIF, WebP, AVIF or SVG image"
}

///|
fn run_pdf(data : Bytes) -> Outcome raise AllError {
  let result = @pdf.convert(data) catch {
    @pdf.PdfFailure(message) => raise AllFailure("pdf: " + message)
  }
  {
    bdf: result.bdf,
    format: "pdf",
    summary: result.summary,
    warnings: result.warnings,
  }
}

///|
fn run_docx(data : Bytes) -> Outcome raise AllError {
  let result = @docx.convert(data) catch {
    @docx.DocxInvalid(message) => raise AllFailure("docx: " + message)
    _ => raise AllFailure("docx: conversion failed")
  }
  {
    bdf: result.bdf,
    format: "docx",
    summary: result.summary,
    warnings: result.warnings,
  }
}

///|
fn run_pptx(
  data : Bytes,
  database : @fontdb.Database?,
) -> Outcome raise AllError {
  let result = @pptx.convert(data, db=database) catch {
    @pptx.PptxInvalid(message) => raise AllFailure("pptx: " + message)
    _ => raise AllFailure("pptx: conversion failed")
  }
  {
    bdf: result.bdf,
    format: "pptx",
    summary: result.summary,
    warnings: result.warnings,
  }
}

///|
fn run_xlsx(
  data : Bytes,
  database : @fontdb.Database?,
) -> Outcome raise AllError {
  let font_data = match database {
    Some(db) if db.faces().length() > 0 => Some(db.face(0).unwrap().font.data())
    _ => None
  }
  let result = try {
    match font_data {
      Some(font) => @xlsx.convert_plain_with_font(data, font)
      None => @xlsx.convert_plain_no_fonts(data)
    }
  } catch {
    @xlsx.InvalidXlsxInput(message) => raise AllFailure(message)
    error => raise AllFailure(error.to_string())
  }
  let warnings : Array[String] = []
  if font_data is None {
    warnings.push(
      "no fonts found; text is laid out with estimated metrics and not embedded",
    )
  }
  for warning in result.warnings {
    warnings.push(warning)
  }
  {
    bdf: result.bdf,
    format: "xlsx",
    summary: "\{result.sheets} sheet(s), " +
    (if font_data is None { "0" } else { "1" }) +
    " embedded font(s)",
    warnings,
  }
}

///|
fn run_csv(
  data : Bytes,
  name : String,
  database : @fontdb.Database?,
) -> Outcome raise AllError {
  let params : Map[String, String] = Map([])
  for key in ["charset", "delimiter", "quote", "header", "data", "table"] {
    params[key] = ""
  }
  let options = @csv.parse_params(params) catch {
    @csv.InvalidDialect(message) => raise AllFailure(message)
    error => raise AllFailure(error.to_string())
  }
  let sheet = if name == "" { "" } else { @csv.sheet_name(name) }
  let result = (match database {
    Some(db) =>
      @csv.convert_with_fonts(
        data,
        db,
        name=sheet,
        charset=options.charset,
        delimiter=options.delimiter,
        quote=options.quote,
        header=options.header,
        data_mode=options.data_mode,
        table_style=options.table_style,
        no_woff2=true,
      )
    None =>
      @csv.convert_no_fonts(
        data,
        name=sheet,
        charset=options.charset,
        delimiter=options.delimiter,
        quote=options.quote,
        header=options.header,
        data_mode=options.data_mode,
        table_style=options.table_style,
      )
  }) catch {
    @csv.InvalidDialect(message) => raise AllFailure(message)
    error => raise AllFailure(error.to_string())
  }
  {
    bdf: result.bdf,
    format: "csv",
    summary: @csv.summary(result.parsed),
    warnings: result.warnings,
  }
}

///|
fn run_font(
  data : Bytes,
  database : @fontdb.Database?,
) -> Outcome raise AllError {
  let base = @font.SpecimenOptions::new()
  let options : @font.SpecimenOptions = {
    selection: "",
    title: base.title,
    text: "",
    examples: base.examples,
    system_fonts: base.system_fonts,
    no_subset: base.no_subset,
    ignore_restrictions: base.ignore_restrictions,
    no_text_index: base.no_text_index,
    no_woff2: true,
  }
  let db = database.unwrap_or(@fontdb.Database::new())
  let result = @font.convert(data, db, options~) catch {
    @font.InvalidFontInput(message) => raise AllFailure(message)
    error => raise AllFailure(error.to_string())
  }
  {
    bdf: result.bdf,
    format: "font",
    summary: result.summary,
    warnings: result.warnings,
  }
}

///|
fn run_ai(data : Bytes) -> Outcome raise AllError {
  let result = @ai.convert(data) catch {
    @ai.AiInvalid(message) => raise AllFailure(message)
  }
  { bdf: result.bdf, format: "ai", summary: result.summary, warnings: result.warnings }
}

///|
fn normalize_tiff(message : String) -> String {
  if message.has_prefix("TIFF: ") {
    "tiff: " + message[6:].to_string()
  } else if message.has_prefix("tiff: ") {
    message
  } else {
    "tiff: " + message
  }
}

///|
fn run_tiff(data : Bytes) -> Outcome raise AllError {
  let result = @tiff.convert(data) catch {
    @tiff.TiffInvalid(message) => raise AllFailure(normalize_tiff(message))
  }
  {
    bdf: result.bdf,
    format: "tiff",
    summary: result.summary,
    warnings: result.warnings,
  }
}

///|
fn run_psd(data : Bytes) -> Outcome raise AllError {
  let result = @psd.convert(data) catch {
    @psd.PsdInvalid(message) => raise AllFailure(message)
  }
  { bdf: result.bdf, format: "psd", summary: result.summary, warnings: result.warnings }
}

///|
fn run_xdw(data : Bytes, params : Map[String, String]) -> Outcome raise AllError {
  let options = @xdw.parse_params(params) catch {
    @xdw.XdwInvalidParam(message) => raise AllFailure(message)
    error => raise AllFailure(error.to_string())
  }
  let result = @xdw.xdw_convert(data, include_hidden=options.include_hidden) catch {
    e => raise AllFailure(e.to_string())
  }
  {
    bdf: result.bdf,
    format: "xdw",
    summary: result.summary,
    warnings: result.warnings,
  }
}

///|
fn run_emf(data : Bytes) -> Outcome raise AllError {
  let result = @emf.convert(data) catch {
    @emf.EmfInvalid(message) => raise AllFailure(message)
  }
  { bdf: result.bdf, format: "emf", summary: result.summary, warnings: result.warnings }
}

///|
fn run_markdown(data : Bytes) -> Outcome raise AllError {
  let result = @markdown.convert(data) catch {
    @markdown.MarkdownInvalid(message) => raise AllFailure(message)
  }
  {
    bdf: result.bdf,
    format: "markdown",
    summary: result.summary,
    warnings: result.warnings,
  }
}

///|
fn run_html(data : Bytes) -> Outcome raise AllError {
  let result = @html.convert(data) catch {
    @html.HtmlInvalid(message) => raise AllFailure(message)
  }
  { bdf: result.bdf, format: "html", summary: result.summary, warnings: result.warnings }
}

///|
fn run_audio(data : Bytes, name : String) -> Outcome raise AllError {
  let result = @audio.convert(data, file_name=name) catch {
    @audio.AudioInvalid(message) => raise AllFailure(message)
  }
  {
    bdf: result.bdf,
    format: "audio",
    summary: result.summary,
    warnings: result.warnings,
  }
}

///|
fn run_hpgl(
  data : Bytes,
  database : @fontdb.Database?,
) -> Outcome raise AllError {
  let result = @hpgl.convert(data, db=database) catch {
    @hpgl.HpglInvalid(message) => raise AllFailure(message)
  }
  {
    bdf: result.bdf,
    format: "hpgl",
    summary: result.summary,
    warnings: result.warnings,
  }
}

///|
fn run_jww(
  data : Bytes,
  database : @fontdb.Database?,
) -> Outcome raise AllError {
  let result = @jww.convert(data, db=database) catch {
    @jww.JwwInvalid(message) => raise AllFailure(message)
  }
  { bdf: result.bdf, format: "jww", summary: result.summary, warnings: result.warnings }
}

///|
fn run_dxf(
  data : Bytes,
  database : @fontdb.Database?,
) -> Outcome raise AllError {
  let result = @dxf.convert(data, db=database) catch {
    @dxf.DxfInvalid(message) => raise AllFailure(message)
  }
  { bdf: result.bdf, format: "dxf", summary: result.summary, warnings: result.warnings }
}

///|
fn run_sxf(
  data : Bytes,
  database : @fontdb.Database?,
) -> Outcome raise AllError {
  let result = @sxf.convert(data, db=database) catch {
    @sxf.SxfInvalid(message) => raise AllFailure(message)
  }
  { bdf: result.bdf, format: "sxf", summary: result.summary, warnings: result.warnings }
}

///|
fn run_cgm(
  data : Bytes,
  database : @fontdb.Database?,
) -> Outcome raise AllError {
  let result = @cgm.convert(data, db=database) catch {
    @cgm.CgmInvalid(message) => raise AllFailure(message)
  }
  { bdf: result.bdf, format: "cgm", summary: result.summary, warnings: result.warnings }
}

///|
fn run_drawio(
  data : Bytes,
  database : @fontdb.Database?,
) -> Outcome raise AllError {
  let result = @drawio.convert(data, db=database) catch {
    @drawio.DrawioInvalid(message) => raise AllFailure(message)
  }
  {
    bdf: result.bdf,
    format: "drawio",
    summary: result.summary,
    warnings: result.warnings,
  }
}

///|
fn run_parquet(data : Bytes) -> Outcome raise AllError {
  let result = @parquet.convert(data) catch {
    @parquet.ParquetInputInvalid(message) => raise AllFailure(message)
  }
  {
    bdf: result.bdf,
    format: "parquet",
    summary: result.summary,
    warnings: result.warnings,
  }
}

///|
fn run_visio(data : Bytes) -> Outcome raise AllError {
  let result = @visio.convert(data) catch {
    @visio.VisioInvalid(message) => raise AllFailure(message)
  }
  {
    bdf: result.bdf,
    format: "visio",
    summary: result.summary,
    warnings: result.warnings,
  }
}

///|
fn run_idml(data : Bytes) -> Outcome raise AllError {
  let result = @idml.convert(data) catch {
    @idml.IdmlInvalid(message) => raise AllFailure(message)
  }
  {
    bdf: result.bdf,
    format: "idml",
    summary: result.summary,
    warnings: result.warnings,
  }
}

///|
fn reject_format(format : String) -> Bool {
  format != "" &&
  format != "image" &&
  format != "csv" &&
  format != "xlsx" &&
  format != "docx" &&
  format != "pptx" &&
  format != "font" &&
  format != "pdf" &&
  format != "ai" &&
  format != "tiff" &&
  format != "psd" &&
  format != "emf" &&
  format != "xdw" &&
  format != "idml" &&
  format != "visio" &&
  format != "markdown" &&
  format != "html" &&
  format != "audio" &&
  format != "hpgl" &&
  format != "jww" &&
  format != "dxf" &&
  format != "sxf" &&
  format != "cgm" &&
  format != "drawio" &&
  format != "parquet"
}

///|
/// The format a file name's extension names, for the inputs no detector
/// claims. Upstream registers these extensions on the Office converters, so a
/// macro-enabled or template package keeps converting when its content is not
/// recognized. The extensions of the formats dropped from the porting scope
/// are deliberately absent.
fn office_named(lower : String) -> String {
  if named(lower, [".xlsx", ".xlsm", ".xltx", ".xltm"]) {
    "xlsx"
  } else if named(lower, [".docx", ".docm", ".dotx", ".dotm"]) {
    "docx"
  } else if named(lower, [".pptx", ".pptm", ".ppsx", ".ppsm", ".potx", ".potm"]) {
    "pptx"
  } else {
    ""
  }
}

///|
/// 名前の拡張子から形式を決め直す。画像として読めなかったものが対象。
/// 順番も、PDF や HP-GL の強い兆しがあるときに飛ばす判断も、ブラウザの
/// 変換 Worker と同じにしてある。どれにも当てはまらなければ、画像の失敗
/// メッセージをそのまま伝える。
fn run_by_name(
  data : Bytes,
  name : String,
  database : @fontdb.Database?,
  head : Bytes,
  image_message : String,
  params : Map[String, String],
) -> Outcome raise AllError {
  let lower = name.to_lower()
  // Worker がクライアント側の素性検査に使う拡張子の一覧。これに当たる名前
  // は、CSV と画像のどちらにも読ませない。
  let known_named = named(
    lower,
    [
      ".xlsx", ".xlsm", ".xltx", ".xltm", ".dxf", ".drawio", ".dio", ".docx",
      ".docm", ".dotx", ".dotm", ".cgm", ".cgz", ".pptx", ".pptm", ".ppsx",
      ".ppsm", ".potx", ".potm", ".plt", ".hpgl", ".hgl", ".hpg", ".hp2",
      ".rtl", ".p21", ".p2z", ".sfc", ".jww", ".pdf", ".mhtml", ".mht",
      ".parquet", ".parq", ".pqt", ".ttf", ".otf", ".ttc", ".otc", ".woff",
      ".woff2", ".zip",
    ],
  )
  let strong_other = @hpgl.detect(head) || @utf8.decode_lossy(head).contains("%PDF-")
  let office = office_named(lower)
  if office == "xlsx" && !strong_other {
    return run_xlsx(data, database)
  }
  if office == "docx" && !strong_other {
    return run_docx(data)
  }
  if office == "pptx" && !strong_other {
    return run_pptx(data, database)
  }
  if named(lower, [".ttf", ".otf", ".ttc", ".otc", ".woff", ".woff2"]) && !strong_other {
    return run_font(data, database)
  }
  if audio_named(lower) && !strong_other {
    return run_audio(data, name)
  }
  if named(lower, [".html", ".htm", ".xhtml"]) && !strong_other {
    return run_html(data)
  }
  if named(lower, [".md", ".markdown", ".mdown", ".mkd", ".mdx"]) && !strong_other {
    return run_markdown(data)
  }
  if named(lower, [".vsdx", ".vsdm", ".vstx", ".vstm"]) && !strong_other {
    return run_visio(data)
  }
  if lower.has_suffix(".idml") && !strong_other {
    return run_idml(data)
  }
  if named(lower, [".parquet", ".parq", ".pqt"]) && !strong_other {
    return run_parquet(data)
  }
  if named(lower, [".drawio", ".dio", ".drawio.svg", ".drawio.png"]) && !strong_other {
    return run_drawio(data, database)
  }
  if named(lower, [".cgm", ".cgz"]) && !strong_other {
    return run_cgm(data, database)
  }
  if named(lower, [".sfc", ".p21", ".p2z"]) && !strong_other {
    return run_sxf(data, database)
  }
  if lower.has_suffix(".dxf") && !strong_other {
    return run_dxf(data, database)
  }
  if lower.has_suffix(".jww") && !strong_other {
    return run_jww(data, database)
  }
  if named(lower, [".plt", ".hpgl", ".hgl", ".hpg", ".hp2", ".rtl"]) && !strong_other {
    return run_hpgl(data, database)
  }
  if lower.has_suffix(".ai") && !strong_other {
    return run_ai(data)
  }
  if named(lower, [".tif", ".tiff"]) && !strong_other {
    return run_tiff(data)
  }
  if named(lower, [".psd", ".psb"]) && !strong_other {
    return run_psd(data)
  }
  if named(lower, [".xdw", ".xbd"]) && !strong_other {
    return run_xdw(data, params)
  }
  if named(lower, [".emf", ".wmf"]) && !strong_other {
    return run_emf(data)
  }
  let csv_named = named(lower, [".csv", ".tsv", ".tab"])
  let csv_detected = if csv_named || known_named || strong_other {
    false
  } else {
    @csv.detect(data) catch { _ => false }
  }
  if !strong_other && (csv_named || csv_detected) {
    return run_csv(data, name, database)
  }
  raise AllFailure(image_message)
}

///|
/// Convert `data` to a BDF document. With `format` left empty the format is
/// detected the same way the browser converter detects it: the engines' own
/// detectors first, then the file name as the last resort. `database` supplies
/// the fonts a format wants to embed; without it text keeps estimated metrics.
pub fn convert(
  data : Bytes,
  format? : String,
  name? : String,
  database? : @fontdb.Database,
  params? : Map[String, String],
) -> Outcome raise AllError {
  let format = format.unwrap_or("")
  let name = name.unwrap_or("")
  let params = params.unwrap_or(Map([]))
  if reject_format(format) {
    raise AllFailure("unknown format \"" + format + "\"")
  }
  let head = head_bytes(data)
  if format == "ai" || (format == "" && @ai.kind(data) != "") {
    return run_ai(data)
  }
  if format == "visio" || (format == "" && @visio.detect(data)) {
    return run_visio(data)
  }
  if format == "idml" || (format == "" && @idml.detect(data)) {
    return run_idml(data)
  }
  if format == "pdf" || (format == "" && @pdf.detect(data)) {
    return run_pdf(data)
  }
  if format == "docx" || (format == "" && @docx.detect(data)) {
    return run_docx(data)
  }
  if format == "pptx" || (format == "" && @pptx.detect(data)) {
    return run_pptx(data, database)
  }
  if format == "xlsx" || (format == "" && @xlsx.detect_xlsx(head, data)) {
    return run_xlsx(data, database)
  }
  if format == "csv" {
    return run_csv(data, name, database)
  }
  if format == "markdown" {
    return run_markdown(data)
  }
  if format == "html" {
    return run_html(data)
  }
  if format == "audio" {
    return run_audio(data, name)
  }
  if format == "font" || (format == "" && @font.detect(data)) {
    return run_font(data, database)
  }
  if format == "tiff" || (format == "" && @tiff.detect(data)) {
    return run_tiff(data)
  }
  if format == "psd" || (format == "" && @psd.detect(data)) {
    return run_psd(data)
  }
  if format == "emf" || (format == "" && @emf.detect(data)) {
    return run_emf(data)
  }
  if format == "xdw" || (format == "" && @xdw.xdw_detect(data)) {
    return run_xdw(data, params)
  }
  if format == "hpgl" || (format == "" && @hpgl.detect(head)) {
    return run_hpgl(data, database)
  }
  if format == "jww" || (format == "" && @jww.detect(data)) {
    return run_jww(data, database)
  }
  if format == "dxf" || (format == "" && @dxf.detect(data)) {
    return run_dxf(data, database)
  }
  if format == "sxf" || (format == "" && @sxf.detect(data)) {
    return run_sxf(data, database)
  }
  if format == "cgm" || (format == "" && @cgm.detect(data)) {
    return run_cgm(data, database)
  }
  if format == "drawio" || (format == "" && @drawio.detect(data)) {
    return run_drawio(data, database)
  }
  if format == "parquet" || (format == "" && @parquet.detect(data)) {
    return run_parquet(data)
  }
  // 形式を決められなかったものは、画像として読めるか試す。当てはまらなければ
  // 名前の拡張子から決め直す（ブラウザの変換 Worker と同じ順番）。
  let result = @image.convert(data, name~) catch {
    @image.ImageFailure(message) => {
      if format == "" && image_not_supported(message) {
        return run_by_name(data, name, database, head, message, params)
      }
      raise AllFailure(message)
    }
    error => raise AllFailure(error.to_string())
  }
  {
    bdf: result.bdf,
    format: result.format,
    summary: result.summary,
    warnings: result.warnings,
  }
}

