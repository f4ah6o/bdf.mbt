///|
pub suberror PdfError {
  PdfFailure(String)
}

///|
/// The converted document and the warnings collected while reading it.
pub(all) struct PdfResult {
  bdf : Bytes
  format : String
  pages : Int32
  summary : String
  warnings : Array[String]
  shared_prefixes : Int32
  shared_bytes : Int64
}

///|
/// Recognize a PDF header in the first KiB, as PDF readers do.
pub fn detect(data : Bytes) -> Bool {
  let limit = Int32::min(data.length(), 1024)
  let mut i = 0
  while i + 5 <= limit {
    if data[i:i + 5] == b"%PDF-"[:] {
      return true
    }
    i += 1
  }
  false
}

///|
/// Convert a PDF into a single-file BDF document. Unsupported content fails
/// with an explicit message instead of producing a partial page.
pub fn convert(
  data : Bytes,
  box~ : String = "crop",
  title~ : String = "",
  no_text_index~ : Bool = false,
  no_share_prefix~ : Bool = false,
) -> PdfResult raise PdfError {
  let (bdf, warnings, shared_prefixes, shared_bytes) = pdf_graphics_document_full(
    data,
    box~,
    title~,
    no_text_index~,
    no_share_prefix~,
  ) catch {
    InvalidStream(message) => raise PdfFailure(message)
  }
  let pages = @core.open_single(bdf) catch {
    _ => raise PdfFailure("PDF document output is invalid")
  }
  let count = if pages.manifest.views.is_empty() {
    0
  } else {
    pages.manifest.views[0].pages.length()
  }
  {
    bdf,
    format: "pdf",
    pages: count,
    summary: "\{count} page(s) (PDF)",
    warnings,
    shared_prefixes,
    shared_bytes,
  }
}
