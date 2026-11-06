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
fn overlay_page_offsets(pdf : String) -> Array[(Int, Double, Double)] {
  let offsets : Array[(Int, Double, Double)] = []
  let mut pos = 0
  while pos < pdf.length() {
    let rest = pdf[pos:]
    let at = match rest.find(" 0 obj") {
      Some(index) => pos + index
      None => break
    }
    let mut start = at
    while start > 0 {
      let c = pdf[start - 1].to_char().unwrap()
      if c >= '0' && c <= '9' {
        start -= 1
      } else {
        break
      }
    }
    if start == at {
      pos = at + 1
      continue
    }
    let object = @string.parse_int(pdf[start:at].to_owned()) catch {
      _ => {
        pos = at + 1
        continue
      }
    }
    let tail = pdf[at:]
    let end = match tail.find("endobj") {
      Some(index) => at + index
      None => pdf.length()
    }
    let segment = pdf[start:end]
    if segment.contains("/Type /Page") && !segment.contains("/Type /Pages") {
      let (box_at, key_length) = match segment.find("/MediaBox") {
        Some(index) => (index, 9)
        None =>
          match segment.find("/CropBox") {
            Some(index) => (index, 8)
            None => {
              pos = end + 6
              continue
            }
          }
      }
      let mut i = box_at + key_length
      while i < segment.length() && segment[i].to_char().unwrap() != '[' {
        i += 1
      }
      let a = match overlay_f64(segment.to_owned(), i + 1) {
        Some(value) => value
        None => {
          pos = end + 6
          continue
        }
      }
      let b = match overlay_f64(segment.to_owned(), a.1) {
        Some(value) => value
        None => {
          pos = end + 6
          continue
        }
      }
      offsets.push((object, a.0, b.0))
    }
    pos = end + 6
  }
  offsets
}

///|
fn overlay_page_sizes(pdf : String) -> Array[(Int, Double, Double)] {
  let sizes : Array[(Int, Double, Double)] = []
  let mut pos = 0
  while pos < pdf.length() {
    let rest = pdf[pos:]
    let at = match rest.find(" 0 obj") {
      Some(index) => pos + index
      None => break
    }
    let mut start = at
    while start > 0 {
      let c = pdf[start - 1].to_char().unwrap()
      if c >= '0' && c <= '9' {
        start -= 1
      } else {
        break
      }
    }
    if start == at {
      pos = at + 1
      continue
    }
    let object = @string.parse_int(pdf[start:at].to_owned()) catch {
      _ => {
        pos = at + 1
        continue
      }
    }
    let tail = pdf[at:]
    let end = match tail.find("endobj") {
      Some(index) => at + index
      None => pdf.length()
    }
    let segment = pdf[start:end]
    if segment.contains("/Type /Page") && !segment.contains("/Type /Pages") {
      let size = match overlay_box(segment.to_owned(), "/MediaBox") {
        Some(value) => value
        None =>
          match overlay_box(segment.to_owned(), "/CropBox") {
            Some(value) => value
            None => (595.0, 842.0)
          }
      }
      sizes.push((object, size.0, size.1))
    }
    pos = end + 6
  }
  sizes
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
fn overlay_lines(value : String, width : Double, size : Double) -> Array[String] {
  let lines : Array[String] = []
  for raw in value.split("\n") {
    let text = raw.to_owned()
    if size <= 0.0 || @drawingml.text_width(text, size) <= width {
      lines.push(text)
    } else {
      let mut start = 0
      while start < text.length() {
        let mut end = start + 1
        let mut last_space = -1
        while end < text.length() &&
          @drawingml.text_width(text[start:end + 1].to_owned(), size) <= width {
          if text[end].to_char().unwrap() == ' ' {
            last_space = end
          }
          end += 1
        }
        let mut cut = end
        if cut < text.length() && last_space > start {
          cut = last_space
        }
        lines.push(text[start:cut].to_owned())
        start = cut
        while start < text.length() && text[start].to_char().unwrap() == ' ' {
          start += 1
        }
      }
    }
  }
  lines
}

///|
fn overlay_mask(value : String) -> String {
  let result = StringBuilder::new()
  for _ in 0..<value.length() {
    result.write_string("*")
  }
  result.to_string()
}

///|
fn overlay_shade(color : UInt32, factor : Double) -> UInt32 {
  let channel = fn(value : UInt32) -> UInt32 {
    let scaled = value.to_double() * factor
    (if scaled > 255.0 { 255 } else if scaled < 0.0 { 0 } else { scaled.to_int() }).to_uint()
  }
  (channel((color >> 24) & 0xffU) << 24) |
  (channel((color >> 16) & 0xffU) << 16) |
  (channel((color >> 8) & 0xffU) << 8) |
  (color & 0xffU)
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
  let page_sizes = overlay_page_sizes(pdf)
  let page_offsets = overlay_page_offsets(pdf)
  let default_page_key = if page_sizes.is_empty() { 0 } else { page_sizes[0].0 }
  let page_keys : Array[Int] = []
  for field in fields {
    let key = field.page_object.unwrap_or(default_page_key)
    if !page_keys.contains(key) {
      page_keys.push(key)
    }
  }
  let mut known_pages = true
  for field in fields {
    match field.page_object {
      Some(key) =>
        if !page_sizes.any(fn(size) { size.0 == key }) {
          known_pages = false
        }
      None => ()
    }
  }
  if !page_sizes.is_empty() && known_pages {
    for size in page_sizes {
      if !page_keys.contains(size.0) {
        page_keys.push(size.0)
      }
    }
  }
  if page_keys.is_empty() {
    page_keys.push(0)
  }
  let ordered_keys : Array[Int] = []
  for size in page_sizes {
    if page_keys.contains(size.0) && !ordered_keys.contains(size.0) {
      ordered_keys.push(size.0)
    }
  }
  for key in page_keys {
    if !ordered_keys.contains(key) {
      ordered_keys.push(key)
    }
  }
  page_keys.clear()
  for key in ordered_keys {
    page_keys.push(key)
  }
  let page_widths : Array[Double] = []
  let page_heights : Array[Double] = []
  let page_x : Array[Double] = []
  let page_y : Array[Double] = []
  for key in page_keys {
    let mut width = page_width
    let mut height = page_height
    for size in page_sizes {
      if size.0 == key {
        width = size.1
        height = size.2
      }
    }
    let mut offset_x = 0.0
    let mut offset_y = 0.0
    for offset in page_offsets {
      if offset.0 == key {
        offset_x = offset.1
        offset_y = offset.2
      }
    }
    page_widths.push(width)
    page_heights.push(height)
    page_x.push(offset_x)
    page_y.push(offset_y)
  }
  let builders : Array[@core.ObjectBuilder] = []
  let fonts : Array[Int32] = []
  for i in 0..<page_keys.length() {
    let builder = @core.ObjectBuilder::new()
    builder.set_bbox(
      0.0,
      0.0,
      Float::from_double(page_widths[i]),
      Float::from_double(page_heights[i]),
    )
    builder.fill_color(0xffffffff)
    builder.fill_rect(
      0.0,
      0.0,
      Float::from_double(page_widths[i]),
      Float::from_double(page_heights[i]),
    )
    let font = builder.add_font({
      hash: None,
      family: "Helvetica",
      weight: 400,
      style: 0,
    }) catch {
      _ => raise PdfFillError("form/pdf: the font cannot be added")
    }
    builders.push(builder)
    fonts.push(font)
  }
  for field in fields {
    let page_key = field.page_object.unwrap_or(default_page_key)
    let mut page_index = 0
    for i, key in page_keys {
      if key == page_key {
        page_index = i
      }
    }
    let builder = builders[page_index]
    let font = fonts[page_index]
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
    let value = match field.max_len {
      Some(limit) =>
        if limit >= 0 && value.length() > limit {
          value[:limit].to_owned()
        } else {
          value
        }
      None => value
    }
    let value = if field.password && !is_button {
      overlay_mask(value)
    } else if !field.multiline && !is_button {
      value.replace(old="\n", new=" ")
    } else {
      value
    }
    if value == "" {
      continue
    }
    let (raw_x1, raw_y1, raw_x2, raw_y2) = match field.rect {
      Some(rect) => rect
      None => continue
    }
    let x1 = raw_x1 - page_x[page_index]
    let y1 = raw_y1 - page_y[page_index]
    let x2 = raw_x2 - page_x[page_index]
    let y2 = raw_y2 - page_y[page_index]
    let width = x2 - x1
    let height = y2 - y1
    if width <= 0.0 || height <= 0.0 {
      continue
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
    let border_width = match field.border_width {
      Some(width) => Double::max(0.0, width)
      None => 0.5
    }
    match field.border_color {
      Some(color) => {
        builder.stroke_color(color)
        if field.border_style == "D" {
          builder.dash([3.0, 3.0], 0.0)
        } else {
          builder.dash([], 0.0)
        }
        if field.border_style == "U" {
          builder.fill_color(color)
          builder.fill_rect(
            Float::from_double(x1),
            Float::from_double(y1),
            Float::from_double(width),
            Float::from_double(border_width),
          )
        } else if field.border_style == "B" || field.border_style == "I" {
          let beveled = field.border_style == "B"
          let light = overlay_shade(color, if beveled { 1.35 } else { 0.55 })
          let dark = overlay_shade(color, if beveled { 0.55 } else { 1.35 })
          builder.fill_color(light)
          builder.fill_rect(
            Float::from_double(x1),
            Float::from_double(y1 + height - border_width),
            Float::from_double(width),
            Float::from_double(border_width),
          )
          builder.fill_rect(
            Float::from_double(x1),
            Float::from_double(y1),
            Float::from_double(border_width),
            Float::from_double(height),
          )
          builder.fill_color(dark)
          builder.fill_rect(
            Float::from_double(x1 + width - border_width),
            Float::from_double(y1),
            Float::from_double(border_width),
            Float::from_double(height),
          )
          builder.fill_rect(
            Float::from_double(x1),
            Float::from_double(y1),
            Float::from_double(width),
            Float::from_double(border_width),
          )
        } else {
          builder.line(Float::from_double(border_width), 0, 0, 0.0F)
          builder.stroke_rect(
            Float::from_double(x1),
            Float::from_double(y1),
            Float::from_double(width),
            Float::from_double(height),
          )
        }
      }
      None => ()
    }
    if field.comb {
      match field.max_len {
        Some(limit) =>
          if limit > 1 {
            builder.fill_color(
              field.border_color.unwrap_or(0x000000ff),
            )
            for i in 1..<limit {
              let offset = width * i.to_double() / limit.to_double()
              builder.fill_rect(
                Float::from_double(x1 + offset),
                Float::from_double(y1),
                Float::from_double(border_width),
                Float::from_double(height),
              )
            }
          }
        None => ()
      }
    }
    let size = if is_button {
      Float::from_double(Double::min(width, height) * 0.8)
    } else {
      match field.font_size {
        Some(value) if value > 0.0 => Float::from_double(value)
        _ => Float::from_double(Double::min(12.0, height * 0.7))
      }
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
    builder.fill_color(field.font_color.unwrap_or(0x000000ff))
    if field.comb {
      match field.max_len {
        Some(limit) =>
          if limit > 0 {
            let cell = width / limit.to_double()
            let count = Int::min(value.length(), limit)
            let baseline = y1 + (height - size.to_double()) / 2.0 + size.to_double() * 0.2
            for i in 0..<count {
              let ch = value[i:i + 1].to_owned()
              let advance = @drawingml.text_width(ch, size.to_double())
              builder.fill_text(
                ch,
                Float::from_double(x1 + i.to_double() * cell + (cell - advance) / 2.0),
                Float::from_double(baseline),
                Float::from_double(cell),
              )
            }
            continue
          }
        None => ()
      }
    }
    builder.save()
    builder.clip_rect(
      Float::from_double(x1),
      Float::from_double(y1),
      Float::from_double(width),
      Float::from_double(height),
    )
    let lines = overlay_lines(value, width, size.to_double())
    for i, line in lines {
      let advance = Float::from_double(
        @drawingml.text_width(line, size.to_double()),
      )
      builder.fill_text(
        line,
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
    builder.restore()
  }
  let writer = @core.DocumentWriter::new()
  let pages : Array[Json] = []
  for i, builder in builders {
    let hash = writer.add_part("obj", builder.encode()) catch {
      _ => raise PdfFillError("form/pdf: the overlay cannot be encoded")
    }
    pages.push(
      Json::object({
        "w": Json::number(page_widths[i]),
        "h": Json::number(page_heights[i]),
        "layers": Json::array([
          Json::object({
            "role": Json::string(""),
            "obj": Json::string(hash),
          }),
        ]),
      }),
    )
  }
  writer.add_view(
    Json::object({
      "id": Json::string("form"),
      "kind": Json::string("fixed"),
      "title": Json::string(title),
      "pages": Json::array(pages),
    }),
  )
  writer.write_single() catch {
    _ => raise PdfFillError("form/pdf: the overlay cannot be written")
  }
}
