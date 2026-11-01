///|
/// An Illustrator conversion failure.
pub suberror AiError {
  AiInvalid(String)
}

///|
pub(all) struct AiResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
let ai_no_pdf_content : String = "the file was saved without PDF content; save it again in Illustrator with \"Create PDF Compatible File\" on"

///|
let ai_postscript : String = "PostScript-based Illustrator files (Illustrator 8 and earlier) are not supported; save it again in Illustrator 9 or later"

///|
/// Tell an Illustrator file from its first bytes: `"pdf"` for the PDF based
/// format (Illustrator 9 and later), `"ps"` for the PostScript based one,
/// `""` for other files.
pub fn kind(data : Bytes) -> String {
  let head_length = if data.length() < 1024 { data.length() } else { 1024 }
  let head = @utf8.decode_lossy(data[:head_length])
  if head.has_prefix("%!PS-Adobe") {
    if head.contains("%%Creator: Adobe Illustrator") ||
      head.contains("%%Creator:Adobe Illustrator") {
      return "ps"
    }
  }
  if head.contains("%PDF-") {
    let scan_length = if data.length() < 262144 {
      data.length()
    } else {
      262144
    }
    let scan = @utf8.decode_lossy(data[:scan_length])
    if scan.contains("<illustrator:Type>Document</illustrator:Type>") ||
      scan.contains("illustrator:Type=\"Document\"") {
      return "pdf"
    }
  }
  ""
}

///|
fn ai_placeholder(doc : @core.Document) -> Bool {
  if doc.manifest.views.length() != 1 {
    return false
  }
  let view = doc.manifest.views[0]
  if view.pages.length() != 1 {
    return false
  }
  let text = @buffer.Buffer()
  for layer in view.pages[0].layers {
    let resources = @core.decode_object_resources(doc.part(layer.object)) catch {
      _ => continue
    }
    let loader = fn(hash : String) -> @core.ObjectResources? raise {
      Some(@core.decode_object_resources(doc.part(hash)))
    }
    let content = @render.extract_text(resources, loader) catch {
      _ => continue
    }
    text.write_string_utf8(@render.join_text(content.runs))
  }
  let lowered = @utf8.decode_lossy(text.to_bytes()).to_lower()
  let chars : Array[Char] = []
  for ch in lowered {
    if !ch.is_whitespace() {
      chars.push(ch)
    }
  }
  let plain = String::from_array(chars)
  plain.contains("savedwithoutpdfcontent") ||
  plain.contains("createpdfcompatiblefile") ||
  plain.contains("pdf互換ファイルを作成")
}

///|
/// Convert Illustrator artwork (Illustrator 9 and later, which saves a PDF
/// and Illustrator's data beside it) by converting the PDF. The default
/// page box is the trim box, the artboard.
pub fn convert(
  data : Bytes,
  box~ : String = "trim",
  title~ : String = "",
  no_text_index~ : Bool = false,
  no_share_prefix~ : Bool = false,
) -> AiResult raise AiError {
  let file_kind = kind(data)
  if file_kind == "ps" {
    raise AiInvalid("ai: " + ai_postscript)
  }
  if file_kind != "pdf" {
    raise AiInvalid("ai: not an Illustrator file")
  }
  let page_box = if box == "" { "trim" } else { box }
  let result = @pdf.convert(
    data,
    box=page_box,
    title~,
    no_text_index~,
    no_share_prefix~,
    source="ai",
  ) catch {
    @pdf.PdfFailure(message) => raise AiInvalid("ai: " + message)
  }
  let document = @core.open_single(result.bdf) catch {
    _ => raise AiInvalid("ai: the PDF output is not a BDF document")
  }
  if ai_placeholder(document) {
    raise AiInvalid("ai: " + ai_no_pdf_content)
  }
  {
    bdf: result.bdf,
    pages: result.pages,
    summary: "\{result.pages} artboard(s)",
    warnings: result.warnings,
  }
}
