///|
pub suberror PdfFillError {
  PdfFillError(String)
}

///|
fn overlay_f64(text : String, start : Int) -> (Double, Int)? {
  let mut i = start
  while i < text.length() && (text[i].to_char().unwrap() == ' ' || text[i].to_char().unwrap() == '[') {
    i += 1
  }
  let begin = i
  while i < text.length() {
    let c = text[i].to_char().unwrap()
    if (c >= '0' && c <= '9') || c == '.' || c == '-' || c == '+' {
      i += 1
    } else {
      break
    }
  }
  if i == begin {
    return None
  }
  try {
    Some((@string.parse_double(text[begin:i].to_owned()), i))
  } catch {
    _ => None
  }
}

///|
fn overlay_box(pdf : String, key : String) -> (Double, Double)? {
  let at = match pdf.find(key) {
    Some(index) => index
    None => return None
  }
  let mut i = at + key.length()
  while i < pdf.length() && pdf[i].to_char().unwrap() != '[' {
    i += 1
  }
  let a = match overlay_f64(pdf, i + 1) {
    Some((value, next)) => (value, next)
    None => return None
  }
  let b = match overlay_f64(pdf, a.1) {
    Some((value, next)) => (value, next)
    None => return None
  }
  let c = match overlay_f64(pdf, b.1) {
    Some((value, next)) => (value, next)
    None => return None
  }
  let d = match overlay_f64(pdf, c.1) {
    Some((value, next)) => (value, next)
    None => return None
  }
  let width = c.0 - a.0
  let height = d.0 - b.0
  if width > 0.0 && height > 0.0 {
    Some((width, height))
  } else {
    None
  }
}

///|
fn overlay_page_size(pdf : String) -> (Double, Double) {
  match overlay_box(pdf, "/MediaBox") {
    Some(size) => size
    None =>
      match overlay_box(pdf, "/CropBox") {
        Some(size) => size
        None => (595.0, 842.0)
      }
  }
}

///|
fn overlay_value(data : Json, name : String) -> String {
  let value = match data {
    Json::Object(object) => object.get(name)
    _ => None
  }
  match value {
    Some(Json::String(text)) => text
    Some(Json::Number(number, ..)) => number.to_string()
    Some(Json::True) => "true"
    Some(Json::False) => "false"
    _ => ""
  }
}

///|
/// Draw the values of the AcroForm fields at their rectangles on blank
/// pages, for printing onto preprinted forms. This does not fill the PDF.
pub fn fill_overlay(
  pdf_bytes : Bytes,
  data_bytes : Bytes,
  title~ : String = "",
  skip_read_only~ : Bool = false,
) -> Bytes raise PdfFillError {
  let pdf = @utf8.decode_lossy(pdf_bytes[:])
  let data = @json.parse(@utf8.decode_lossy(data_bytes[:])) catch {
    _ => raise PdfFillError("form/pdf: the data is not JSON")
  }
  let fields = read_fields(pdf_bytes)
  let (page_width, page_height) = overlay_page_size(pdf)
  let builder = @core.ObjectBuilder::new()
  builder.set_bbox(0.0, 0.0, Float::from_double(page_width), Float::from_double(page_height))
  builder.fill_color(0xffffffff)
  builder.fill_rect(
    0.0,
    0.0,
    Float::from_double(page_width),
    Float::from_double(page_height),
  )
  let font = builder.add_font({
    hash: None,
    family: "Helvetica",
    weight: 400,
    style: 0,
  }) catch {
    _ => raise PdfFillError("form/pdf: the font cannot be added")
  }
  for field in fields {
    if skip_read_only && field.read_only {
      continue
    }
    let raw = overlay_value(data, field.name)
    let is_button = field.typ == "/Btn"
    let value = if is_button {
      if raw == "true" || raw == "Yes" || raw == "/Yes" || raw == "On" ||
        raw == "/On" || raw == "1" || raw == "/1" {
        "X"
      } else {
        ""
      }
    } else {
      raw
    }
    if value == "" {
      continue
    }
    let (x1, y1, x2, y2) = match field.rect {
      Some(rect) => rect
      None => continue
    }
    let width = x2 - x1
    let height = y2 - y1
    if width <= 0.0 || height <= 0.0 {
      continue
    }
    match field.border_color {
      Some(color) => {
        builder.stroke_color(color)
        builder.line(0.5, 0, 0, 0.0F)
        builder.stroke_rect(
          Float::from_double(x1),
          Float::from_double(y1),
          Float::from_double(width),
          Float::from_double(height),
        )
      }
      None => ()
    }
    match field.background_color {
      Some(color) => {
        builder.fill_color(color)
        builder.fill_rect(
          Float::from_double(x1),
          Float::from_double(y1),
          Float::from_double(width),
          Float::from_double(height),
        )
      }
      None => ()
    }
    let size = if is_button {
      Float::from_double(Double::min(width, height) * 0.8)
    } else {
      Float::from_double(Double::min(12.0, height * 0.7))
    }
    let field_font = if field.font_name == "" || field.font_name == "Helvetica" {
      font
    } else {
      builder.add_font({
        hash: None,
        family: field.font_name,
        weight: 400,
        style: 0,
      }) catch {
        _ => font
      }
    }
    builder.font(field_font, size) catch {
      _ => raise PdfFillError("form/pdf: the font cannot be set")
    }
    builder.fill_color(0x000000ff)
    let lines = value.split("\n").collect()
    for i, line in lines {
      let advance = Float::from_double(
        line.length().to_double() * size.to_double() * 0.5,
      )
      builder.fill_text(
        line.to_owned(),
        Float::from_double(
          if is_button {
          x1 + (width - advance.to_double()) / 2.0
        } else {
          match field.quadding {
            Some(1) => x1 + (width - advance.to_double()) / 2.0
            Some(2) => x1 + width - advance.to_double()
            _ => x1 + 1.0
          }
        },
        ),
        Float::from_double(
          y1 + (height - size.to_double()) / 2.0 -
          i.to_double() * size.to_double() * 1.2,
        ),
        advance,
      )
    }
  }
  let writer = @core.DocumentWriter::new()
  let hash = writer.add_part("obj", builder.encode()) catch {
    _ => raise PdfFillError("form/pdf: the overlay cannot be encoded")
  }
  writer.add_view(
    Json::object({
      "id": Json::string("form"),
      "kind": Json::string("fixed"),
      "title": Json::string(title),
      "pages": Json::array([
        Json::object({
          "w": Json::number(page_width),
          "h": Json::number(page_height),
          "layers": Json::array([
            Json::object({
              "role": Json::string(""),
              "obj": Json::string(hash),
            }),
          ]),
        }),
      ]),
    }),
  )
  writer.write_single() catch {
    _ => raise PdfFillError("form/pdf: the overlay cannot be written")
  }
}
