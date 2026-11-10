///|
// Filling a template with data, and compiling a template: the formats of
// the templates, what a template is, and the fill of each format
// (form/form.go of upstream).

///|
pub suberror FormError {
  FormError(String)
}

///|
/// The formats of templates: the documents of Office with tags in their
/// text, the files whose fields are what is filled (a PDF with the fields
/// of a form, and a template of pdfme), and text with tags on a grid of
/// columns and lines.
pub const FORMAT_XLSX : String = "xlsx"
pub const FORMAT_DOCX : String = "docx"
pub const FORMAT_PPTX : String = "pptx"
pub const FORMAT_PDF : String = "pdf"
pub const FORMAT_PDFME : String = "pdfme"
pub const FORMAT_TEXT : String = "text"

///|
const NOT_TEMPLATE : String = "form: the template is not an Excel workbook (.xlsx), a Word document (.docx), a PowerPoint presentation (.pptx), a PDF with form fields (.pdf), a template of pdfme (.json), a template of text (.txt) nor a compiled template (.bdft)"

///|
/// What is read of a file of text to find a tag in it.
const MAX_TEXT_HEAD : Int = 1 << 20

///|
/// Options controls filling a template.
pub(all) struct Options {
  /// The data: an object of the values of JSON (see `@data.load_data`).
  data : Json?
  /// Makes a tag whose name the data does not have an error, in every
  /// format; without it the tag is left empty and the fill warns.
  strict : Bool
  /// The names of the data that the fill leaves open: with any, `fill`
  /// makes a partly filled form of the values that the data gives, which
  /// another fill completes. `OPEN_ALL` leaves open every name that the
  /// data does not give.
  open : Array[String]
}

///|
pub fn Options::new(
  data? : Json,
  strict? : Bool = false,
  open? : Array[String] = [],
) -> Options {
  { data, strict, open }
}

///|
/// A filled template.
pub(all) struct Result {
  /// The document: the template filled with the data.
  bdf : Bytes
  warnings : Array[String]
  /// The names that the tags of the template look up.
  fields : Array[@tag.Field]
  /// The format of the template (`FORMAT_XLSX` …).
  format : String
  /// The partly filled form that the document is when the fill left names
  /// open, and `None` when the document is complete.
  partial : Template?
}

///|
/// A compiled template: the document to write as the .bdft, and its
/// description.
pub(all) struct Compiled {
  bdf : Bytes
  template : Template
  warnings : Array[String]
}

///|
fn form_is_zip(head : Bytes) -> Bool {
  head.length() >= 4 && head[:4] == b"PK\x03\x04"[:]
}

///|
fn form_pdfme_template(text : String) -> Bool {
  let mut start = 0
  if text.has_prefix("\u{feff}") {
    start = 1
  }
  while start < text.length() &&
        (
          text[start] == ' ' ||
          text[start] == '\t' ||
          text[start] == '\r' ||
          text[start] == '\n'
        ) {
    start += 1
  }
  if start >= text.length() || text[start] != '{' {
    return false
  }
  text.contains("\"schemas\"") || text.contains("\"basePdf\"")
}

///|
/// What a template is: its format, the bytes of the template (that of the
/// compiled template it holds), and its description when it is compiled.
fn form_source(data : Bytes) -> (String, Bytes, Template?) raise FormError {
  let head = data[:Int::min(data.length(), 1024)].to_owned()
  if head.length() >= 4 && head[:4] == b"bdf\x00"[:] {
    let (template, source) = read_template(data)
    return (template.format, source, Some(template))
  }
  let head_text = @utf8.decode_lossy(head[:])
  if head_text.contains("%PDF-") {
    return (FORMAT_PDF, data, None)
  }
  if form_pdfme_template(head_text) {
    return (FORMAT_PDFME, data, None)
  }
  if !form_is_zip(head) && @textform.is_text(head) {
    let mut text = head
    if !@textform.is_template(text) && head.length() < data.length() {
      text = data[:Int::min(data.length(), MAX_TEXT_HEAD)].to_owned()
    }
    if @textform.is_template(text) {
      return (FORMAT_TEXT, data, None)
    }
  }
  if !form_is_zip(head) {
    raise FormError(NOT_TEMPLATE)
  }
  let archive = @zip.open_zip(data) catch {
    _ => raise FormError(NOT_TEMPLATE)
  }
  for entry in archive.entries {
    let name = entry.name.replace(old="\\", new="/").to_lower()
    if name == "xl/workbook.xml" {
      return (FORMAT_XLSX, data, None)
    }
    if name == "word/document.xml" {
      return (FORMAT_DOCX, data, None)
    }
    if name == "ppt/presentation.xml" {
      return (FORMAT_PPTX, data, None)
    }
  }
  raise FormError(NOT_TEMPLATE)
}

///|
/// The text of a template of text, or the mistake in its UTF-8: a template
/// that is not UTF-8 is refused, not filled with replacement characters.
fn form_text(source : Bytes) -> String raise FormError {
  @utf8.decode(source[:]) catch {
    _ => raise FormError("text: the template is not text of UTF-8")
  }
}

///|
/// The number formats of the tags of a text template are those of Excel, as
/// upstream's form.fill passes xlsx.Formatter() to every format: a number in
/// its format code, a text that is a date in a date format, and a text in
/// the text section of a format.
fn form_text_format(value : Json, format : String) -> String {
  if format == "" {
    match value {
      Json::Number(number, ..) =>
        if number.is_nan() || number.is_inf() {
          ""
        } else {
          @xlsx_convert.xlsx_format_general(number, 11)
        }
      _ => @tag.value_text(value, "", None)
    }
  } else {
    let sections = @xlsx_convert.xlsx_parse_number_format(
      format,
      @xlsx_convert.xlsx_default_palette(),
    )
    match value {
      Json::Number(number, ..) =>
        if number.is_nan() || number.is_inf() {
          ""
        } else {
          @xlsx_convert.xlsx_format_number(sections, number, false).text()
        }
      Json::String(text) => {
        let date = sections.length() > 0 && sections[0].date
        let mut text_section = false
        for i, section in sections {
          text_section = text_section || section.text || i == 3
        }
        if date {
          match @xlsx_convert.xlsx_iso_serial(text, false) {
            Some(serial) =>
              @xlsx_convert.xlsx_format_number(sections, serial, false).text()
            None =>
              if text_section {
                @xlsx_convert.xlsx_format_text(sections, text).text()
              } else {
                text
              }
          }
        } else if text_section {
          @xlsx_convert.xlsx_format_text(sections, text).text()
        } else {
          text
        }
      }
      _ => @tag.value_text(value, "", None)
    }
  }
}

///|
/// The fields of the tags of a template, read without filling it.
fn fields_of(format : String, source : Bytes) -> Array[@tag.Field] raise FormError {
  match format {
    FORMAT_XLSX =>
      @xlsx.inspect(source) catch {
        @xlsx.XlsxFormError(message) => raise FormError(message)
      }
    FORMAT_DOCX =>
      @docx.inspect(source) catch {
        @docx.DocxFormError(message) => raise FormError(message)
      }
    FORMAT_PPTX =>
      @pptx.inspect(source) catch {
        @pptx.PptxFormError(message) => raise FormError(message)
      }
    FORMAT_PDF =>
      @pdf.inspect(source) catch {
        @pdf.PdfFillError(message) => raise FormError(message)
      }
    FORMAT_PDFME =>
      @pdfme.inspect(source) catch {
        @pdfme.PdfmeError(message) => raise FormError(message)
      }
    FORMAT_TEXT =>
      @textform.inspect(source) catch {
        @textform.TextFormError(message) => raise FormError(message)
      }
    _ =>
      raise FormError(
        "form: templates of the format \"" + format + "\" are not read",
      )
  }
}

///|
/// Fill a template of a format with data.
fn fill_format(
  format : String,
  source : Bytes,
  data : Json,
  strict : Bool,
) -> Result raise FormError {
  let data_bytes = @utf8.encode(data.stringify())
  match format {
    FORMAT_XLSX => {
      let result = @xlsx.fill(source, data_bytes, strict~) catch {
        @xlsx.XlsxFormError(message) => raise FormError(message)
        _ => raise FormError("form: the workbook cannot be filled")
      }
      {
        bdf: result.bdf,
        warnings: result.warnings,
        fields: [],
        format,
        partial: None,
      }
    }
    FORMAT_DOCX => {
      let result = @docx.fill(source, data_bytes, strict~) catch {
        @docx.DocxFormError(message) => raise FormError(message)
        _ => raise FormError("form: the document cannot be filled")
      }
      {
        bdf: result.bdf,
        warnings: result.warnings,
        fields: [],
        format,
        partial: None,
      }
    }
    FORMAT_PPTX => {
      let result = @pptx.fill(source, data_bytes, strict~) catch {
        @pptx.PptxFormError(message) => raise FormError(message)
        _ => raise FormError("form: the presentation cannot be filled")
      }
      {
        bdf: result.bdf,
        warnings: result.warnings,
        fields: [],
        format,
        partial: None,
      }
    }
    FORMAT_PDF => {
      let filled = @pdf.fill_pdf(source, data_bytes, strict~) catch {
        @pdf.PdfFillError(message) => raise FormError(message)
      }
      let result = @pdf_convert.convert(filled) catch {
        @pdf_convert.PdfFailure(message) => raise FormError(message)
      }
      {
        bdf: result.bdf,
        warnings: result.warnings,
        fields: [],
        format,
        partial: None,
      }
    }
    FORMAT_PDFME => {
      let result = @pdfme.fill(source, data_bytes, strict~) catch {
        @pdfme.PdfmeError(message) => raise FormError(message)
      }
      {
        bdf: result.bdf,
        warnings: result.warnings,
        fields: [],
        format,
        partial: None,
      }
    }
    FORMAT_TEXT => {
      let text = form_text(source)
      let values = match data {
        Json::Object(values) => values
        _ => raise FormError("form: the data of a text template is an object")
      }
      let template_data : @textform.TextTemplateData = {
        data: values,
        strict,
        format: Some(form_text_format),
      }
      let result = @textform.fill_result_with(template_data, text) catch {
        @textform.TextFormError(message) => raise FormError(message)
      }
      let bdf = @textform_convert.render_with_tables(
        result.image,
        result.tables,
        "",
      ) catch {
        @textform_convert.TextFormError(message) => raise FormError(message)
        _ => raise FormError("form: the text cannot be laid out")
      }
      { bdf, warnings: result.warnings, fields: [], format, partial: None }
    }
    _ =>
      raise FormError(
        "form: templates of the format \"" + format + "\" are not filled",
      )
  }
}

///|
/// The document of a template as it is, with its tags: what a compiled
/// template shows when it has no sample (Compile of form/form.go of
/// upstream).
fn show_format(format : String, source : Bytes) -> Result raise FormError {
  match format {
    FORMAT_XLSX => {
      let result = @xlsx_convert.convert_plain_no_fonts(source) catch {
        _ => raise FormError("form: the workbook cannot be converted")
      }
      {
        bdf: result.bdf,
        warnings: result.warnings,
        fields: [],
        format,
        partial: None,
      }
    }
    FORMAT_DOCX => {
      let result = @docx_convert.convert(source) catch {
        _ => raise FormError("form: the document cannot be converted")
      }
      {
        bdf: result.bdf,
        warnings: result.warnings,
        fields: [],
        format,
        partial: None,
      }
    }
    FORMAT_PPTX => {
      let result = @pptx_convert.convert(source) catch {
        _ => raise FormError("form: the presentation cannot be converted")
      }
      {
        bdf: result.bdf,
        warnings: result.warnings,
        fields: [],
        format,
        partial: None,
      }
    }
    FORMAT_PDF => {
      let result = @pdf_convert.convert(source) catch {
        @pdf_convert.PdfFailure(message) => raise FormError(message)
      }
      {
        bdf: result.bdf,
        warnings: result.warnings,
        fields: [],
        format,
        partial: None,
      }
    }
    FORMAT_TEXT => {
      let text = form_text(source)
      let result = @textform.show_result(text) catch {
        @textform.TextFormError(message) => raise FormError(message)
      }
      let bdf = @textform_convert.render_with_tables(
        result.image,
        result.tables,
        "",
      ) catch {
        @textform_convert.TextFormError(message) => raise FormError(message)
        _ => raise FormError("form: the text cannot be laid out")
      }
      { bdf, warnings: result.warnings, fields: [], format, partial: None }
    }
    _ =>
      raise FormError(
        "form: templates of the format \"" + format + "\" are not shown",
      )
  }
}

///|
/// The document of a fill with parts added: the parts, views and tables of
/// the document as they are, and the parts of a compiled template.
fn document_with_parts(
  bdf : Bytes,
  extra : Array[(String, Bytes)],
) -> Bytes raise FormError {
  let document = @core.open_single(bdf) catch {
    error => raise FormError("form: " + error.to_string())
  }
  let manifest = @core.manifest_json(bdf) catch {
    _ => raise FormError("form: the manifest of the document cannot be read")
  }
  let meta = match manifest {
    Json::Object(object) =>
      match object.get("meta") {
        Some(value) => value
        None => Json::empty_object()
      }
    _ => Json::empty_object()
  }
  let writer = @core.DocumentWriter::new(meta~)
  for part in document.manifest.parts {
    let data = document.part(part.hash) catch {
      error => raise FormError("form: " + error.to_string())
    }
    ignore(
      writer.add_part(part.kind, data) catch {
        error => raise FormError("form: " + error.to_string())
      },
    )
  }
  match manifest {
    Json::Object(object) => {
      match object.get("views") {
        Some(Json::Array(views)) =>
          for view in views {
            writer.add_view(view)
          }
        _ => ()
      }
      match object.get("tables") {
        Some(Json::Array(tables)) =>
          for table in tables {
            writer.add_table(table)
          }
        _ => ()
      }
    }
    _ => ()
  }
  for entry in extra {
    ignore(
      writer.add_part(entry.0, entry.1) catch {
        error => raise FormError("form: " + error.to_string())
      },
    )
  }
  writer.write_single() catch {
    error => raise FormError("form: " + error.to_string())
  }
}

///|
/// Fill a template, or a compiled template, with data.
pub fn fill(data : Bytes, options : Options) -> Result raise FormError {
  let (format, source, def) = form_source(data)
  let given = match options.data {
    Some(value) => value
    None => Json::empty_object()
  }
  let fields : Array[@tag.Field] = match def {
    Some(template) => template.fields
    None => fields_of(format, source)
  }
  match prepare(def, fields, given, options.open) {
    None => {
      let result = fill_format(format, source, given, options.strict)
      {
        bdf: result.bdf,
        warnings: result.warnings,
        fields,
        format,
        partial: None,
      }
    }
    Some(plan) => {
      let strict = if plan.open.is_empty() { options.strict } else { false }
      let result = fill_format(format, source, plan.data, strict)
      let mut warnings = result.warnings
      if !plan.open.is_empty() {
        warnings = without_open(warnings, plan.open)
      }
      let from = match def {
        Some(template) =>
          if template.is_partial() {
            template.from
          } else {
            template.digest
          }
        None => ""
      }
      if plan.open.is_empty() {
        let signed = match def {
          Some(template) => template.signed
          None => []
        }
        let bdf = if signed.is_empty() {
          result.bdf
        } else {
          record_fill(result.bdf, format, source, from, plan.filled, signed)
        }
        return { bdf, warnings, fields, format, partial: None }
      }
      let (bdf, template) = partly_filled(
        result.bdf,
        source,
        def,
        format,
        from,
        fields,
        plan,
      )
      { bdf, warnings, fields, format, partial: Some(template) }
    }
  }
}

///|
/// Compile a template: check it, and make the document that holds it with
/// what it asks of data. The data of the options is the sample that the
/// pages show the template filled with; without it they show the template
/// with its tags (a template of pdfme with what its designer left in its
/// fields, which is then the sample).
pub fn compile(
  data : Bytes,
  name : String,
  options : Options,
) -> Compiled raise FormError {
  if data.length() > MAX_TEMPLATE_SIZE {
    raise FormError("form: the template is larger than 256 MiB")
  }
  let (format, source, def) = form_source(data)
  match def {
    Some(template) =>
      if template.is_partial() {
        raise FormError(
          "form: the template is a partly filled form; fill in the rest of it",
        )
      } else {
        raise FormError("form: the template is a compiled template already")
      }
    None => ()
  }
  let fields = fields_of(format, source)
  let (sample, strict) = match options.data {
    Some(value) => (Some(value), options.strict)
    None =>
      if format == FORMAT_PDFME {
        // (what its designer left in its fields is the sample, and is not
        // the data of the fill: it is not checked strictly)
        let defaults = @pdfme.defaults(source) catch {
          @pdfme.PdfmeError(message) => raise FormError(message)
        }
        (Some(defaults), false)
      } else {
        (None, false)
      }
  }
  let result = match sample {
    Some(value) => fill_format(format, source, value, strict)
    None => show_format(format, source)
  }
  let schema = @schema.schema(fields, sample) catch {
    @schema.SchemaError(message) => raise FormError(message)
  }
  let template : Template = {
    version: TEMPLATE_VERSION,
    format,
    name,
    source: @core.hash_of(source),
    fields,
    sample,
    schema: Some(schema),
    filled: None,
    open: [],
    from: "",
    signed: [],
    digest: "",
  }
  let description = @utf8.encode(template.to_json().stringify())
  let bdf = document_with_parts(result.bdf, [
    (PART_SOURCE, source),
    (PART_TEMPLATE, description),
  ])
  { bdf, template, warnings: result.warnings }
}

///|
/// The fields of the tags of a template, read without filling it: the
/// names that data for it has, or the first mistake in its tags.
pub fn fields(data : Bytes) -> Array[@tag.Field] raise FormError {
  let (format, source, def) = form_source(data)
  match def {
    Some(template) => template.fields
    None => fields_of(format, source)
  }
}

///|
/// What a template is: its format, and the sample of its data that it has
/// for itself (of a compiled template the sample it was compiled with, of
/// a template of pdfme what its designer left in its fields).
pub fn describe(data : Bytes) -> (String, Json?) raise FormError {
  let (format, source, def) = form_source(data)
  match def {
    Some(template) => (format, template.sample)
    None =>
      if format == FORMAT_PDFME {
        (
          format,
          Some(
            @pdfme.defaults(source) catch {
              @pdfme.PdfmeError(message) => raise FormError(message)
            },
          ),
        )
      } else {
        (format, None)
      }
  }
}

///|
/// The JSON Schema of the data of a template. A compiled template gives
/// the schema it holds (that of its sample); with a sample, or for a
/// template that is not compiled, the schema is made of the tags.
pub fn schema_of(data : Bytes, sample : Json?) -> String raise FormError {
  let (format, source, def) = form_source(data)
  let fields = match def {
    Some(template) => template.fields
    None => fields_of(format, source)
  }
  let schema = match sample {
    Some(value) =>
      @schema.schema(fields, Some(value)) catch {
        @schema.SchemaError(message) => raise FormError(message)
      }
    None =>
      match def {
        Some(template) =>
          match template.schema {
            Some(value) => value
            None =>
              @schema.schema(fields, template.sample) catch {
                @schema.SchemaError(message) => raise FormError(message)
              }
          }
        None =>
          @schema.schema(fields, None) catch {
            @schema.SchemaError(message) => raise FormError(message)
          }
      }
  }
  schema.stringify(indent=2) + "\n"
}
