///|
// The fields of the AcroForm of a PDF, as the names that data for the form
// has (converter/pdfform of upstream).

///|
/// The object number of a reference after a key of a dictionary, as
/// `/Pages 2 0 R` or `/Kids [3 0 R]`.
fn pdf_reference_after(body : String, key : String) -> Int? {
  let at = match body.find(key) {
    Some(index) => index
    None => return None
  }
  let mut i = skip_spaces(body, at + key.length())
  let begin = i
  while i < body.length() && body[i].to_char().unwrap() >= '0' &&
    body[i].to_char().unwrap() <= '9' {
    i += 1
  }
  if i == begin {
    return None
  }
  let number = @string.parse_int(body[begin:i].to_owned()) catch {
    _ => return None
  }
  i = skip_spaces(body, i)
  let generation_begin = i
  while i < body.length() && body[i].to_char().unwrap() >= '0' &&
    body[i].to_char().unwrap() <= '9' {
    i += 1
  }
  if i == generation_begin {
    return None
  }
  i = skip_spaces(body, i)
  if i < body.length() && body[i].to_char().unwrap() == 'R' {
    Some(number)
  } else {
    None
  }
}

///|
/// The object numbers of the kids of a page tree node.
fn pdf_page_kids(body : String) -> Array[Int] {
  let out : Array[Int] = []
  let at = match body.find("/Kids") {
    Some(index) => index
    None => return out
  }
  let open = match body[at:].find("[") {
    Some(index) => at + index
    None => return out
  }
  let close = match body[open:].find("]") {
    Some(index) => open + index
    None => return out
  }
  let inner = body[open + 1:close]
  let pending : Array[Int] = []
  let mut i = 0
  while i < inner.length() {
    let c = inner[i].to_char().unwrap()
    if c >= '0' && c <= '9' {
      let begin = i
      while i < inner.length() && inner[i].to_char().unwrap() >= '0' &&
        inner[i].to_char().unwrap() <= '9' {
        i += 1
      }
      let value = @string.parse_int(inner[begin:i].to_owned()) catch {
        _ => -1
      }
      if value >= 0 {
        pending.push(value)
      }
    } else if c == 'R' {
      if pending.length() >= 2 {
        out.push(pending[pending.length() - 2])
      }
      pending.clear()
      i += 1
    } else {
      i += 1
    }
  }
  out
}

///|
fn pdf_collect_pages(
  text : String,
  number : Int,
  out : Array[Int],
  depth : Int,
) -> Unit {
  if depth > 64 {
    return
  }
  let body = match find_object_body(text, number) {
    Some(value) => value
    None => return
  }
  let kids = pdf_page_kids(body)
  if kids.is_empty() {
    out.push(number)
    return
  }
  for kid in kids {
    pdf_collect_pages(text, kid, out, depth + 1)
  }
}

///|
/// The object numbers of the pages of a PDF, in the order of its page tree.
fn pdf_page_order(text : String) -> Array[Int] {
  let root = match pdf_root(text) {
    Some(value) => value
    None => return []
  }
  let root_body = match find_object_body(text, root.0) {
    Some(value) => value
    None => return []
  }
  let pages = match pdf_reference_after(root_body, "/Pages") {
    Some(value) => value
    None => return []
  }
  let out : Array[Int] = []
  pdf_collect_pages(text, pages, out, 0)
  out
}

///|
fn pdf_page_number(order : Array[Int], object : Int) -> Int? {
  for i, number in order {
    if number == object {
      return Some(i + 1)
    }
  }
  None
}

///|
fn pdf_inspect_field(field : Field) -> @tag.Field? {
  if pdf_pushbutton(field) {
    return None
  }
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
  let text = @utf8.decode_lossy(data[:])
  let order = pdf_page_order(text)
  let out : Array[@tag.Field] = []
  for field in fields {
    match pdf_inspect_field(field) {
      Some(value) => {
        match field.page_object {
          Some(object) =>
            match pdf_page_number(order, object) {
              Some(page) => value.at.push("page " + page.to_string())
              None => ()
            }
          None => ()
        }
        out.push(value)
      }
      None => ()
    }
  }
  out
}
