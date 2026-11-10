///|
// The fields of the AcroForm of a PDF, as the names that data for the form
// has (converter/pdfform of upstream).

///|
fn pdf_inspect_field(field : Field) -> @tag.Field? {
  let out : @tag.Field = {
    name: field.name,
    kind: @tag.FIELD_VALUE,
    in_sections: [],
    format: "",
    mode: "",
    slots: 0,
    inverted: false,
    code: "",
    input: "",
    at: [],
    value_type: "",
    options: [],
    labels: [],
    label: field.alternate_name,
    default: Json::null(),
    max_len: 0,
    multiline: false,
  }
  match field.typ {
    "/Tx" => {
      out.value_type = "string"
      out.max_len = match field.max_len {
        Some(value) => value
        None => 0
      }
      out.multiline = field.multiline
      if field.value != "" {
        out.default = Json::string(field.value)
      }
    }
    "/Btn" => {
      if field.option_values.is_empty() {
        out.value_type = "boolean"
        out.default = Json::boolean(field.value != "" && field.value != "Off")
      } else {
        out.value_type = "string"
        let mut labelled = false
        for i, value in field.option_values {
          out.options.push(value)
          let label = if i < field.options.length() {
            field.options[i]
          } else {
            value
          }
          out.labels.push(label)
          labelled = labelled || label != value
        }
        if !labelled {
          out.labels.clear()
        }
        if field.value != "" && field.value != "Off" {
          out.default = Json::string(field.value)
        }
      }
    }
    "/Ch" => {
      out.value_type = "string"
      let mut labelled = false
      for i, value in field.option_values {
        out.options.push(value)
        let label = if i < field.options.length() {
          field.options[i]
        } else {
          value
        }
        out.labels.push(label)
        labelled = labelled || label != value
      }
      if !labelled {
        out.labels.clear()
      }
      if field.value != "" {
        out.default = Json::string(field.value)
      }
    }
    "/Sig" => {
      out.kind = @tag.FIELD_IMAGE
      out.input = @tag.INPUT_SIGNATURE
    }
    _ => return None
  }
  Some(out)
}

///|
/// The fields of the AcroForm of a PDF, in the order of the form: the
/// names that data for it has, and what each asks for. A button that is
/// only pressed is not a name of the data.
pub fn inspect(data : Bytes) -> Array[@tag.Field] raise PdfFillError {
  let fields = read_fields(data)
  if fields.is_empty() {
    raise PdfFillError("form/pdf: the PDF has no form fields")
  }
  let out : Array[@tag.Field] = []
  for field in fields {
    match pdf_inspect_field(field) {
      Some(value) => out.push(value)
      None => ()
    }
  }
  out
}
