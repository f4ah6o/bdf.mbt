///|
// A small filler for pdfme templates: blank pages and text/line/rectangle/
// checkbox fields. The full pdfme layout (base PDFs, tables, expressions,
// codes) is not supported yet.
pub suberror PdfmeError {
  PdfmeError(String)
}

///|
pub(all) struct FillResult {
  bdf : Bytes
  pages : Int
  warnings : Array[String]
}

///|
fn json_field(value : Json, name : String) -> Json? {
  match value {
    Json::Object(object) => object.get(name)
    _ => None
  }
}

///|
fn json_text(value : Json) -> String? {
  match value {
    Json::String(text) => Some(text)
    Json::Number(number, ..) => Some(number.to_string())
    Json::True => Some("true")
    Json::False => Some("false")
    _ => None
  }
}

///|
fn text_of(value : Json?, fallback : String) -> String {
  match value {
    Some(value) =>
      match json_text(value) {
        Some(text) => text
        None => fallback
      }
    None => fallback
  }
}

///|
fn number_of(value : Json?, fallback : Double) -> Double {
  match value {
    Some(Json::Number(number, ..)) => number
    _ => fallback
  }
}

///|
fn mm_to_pt(value : Double) -> Float {
  Float::from_double(value * 72.0 / 25.4)
}

///|
fn color_of(value : Json?, fallback : UInt32) -> UInt32 {
  let text = match value {
    Some(Json::String(text)) => text
    _ => return fallback
  }
  if !text.has_prefix("#") {
    return fallback
  }
  let hex = text[1:].to_owned()
  if hex.length() == 6 {
    let number = @string.parse_int(hex, base=16) catch { _ => return fallback }
    ((number << 8) | 0xff).to_uint()
  } else if hex.length() == 3 {
    let mut out = 0
    for c in hex {
      let digit = @string.parse_int(c.to_string(), base=16) catch {
        _ => return fallback
      }
      out = (out << 8) | (digit * 17)
    }
    ((out << 8) | 0xff).to_uint()
  } else {
    fallback
  }
}

///|
fn split_lines(text : String) -> Array[String] {
  let lines = text.split("\n").collect()
  if lines.length() == 0 {
    [""]
  } else {
    lines.map(fn(line) { line.to_owned() })
  }
}

///|
fn field_text(field : Json, data : Json) -> String {
  let name = text_of(json_field(field, "name"), "")
  let read_only = match json_field(field, "readOnly") {
    Some(Json::True) => true
    Some(Json::False) => false
    _ => false
  }
  if !read_only && name != "" {
    match json_field(data, name) {
      Some(value) =>
        match json_text(value) {
          Some(text) => return text
          None => ()
        }
      None => ()
    }
  }
  text_of(json_field(field, "content"), "")
}


///|
fn substitute_variables(template : String, values : Json) -> String {
  let parts = template.split("{").collect()
  let out = StringBuilder()
  if parts.length() == 0 {
    return template
  }
  out.write_string(parts[0].to_owned())
  for i in 1..<parts.length() {
    let part = parts[i]
    match part.find("}") {
      Some(end) => {
        let key = part[:end].to_owned()
        let value = if key.contains("+") || key.contains("-") ||
          key.contains("*") || key.contains("/") || key.contains("%") ||
          key.contains("(") {
          match eval_expression(key, values) {
            Some(number) => format_expr_number(number)
            None => ""
          }
        } else {
          match json_field(values, key) {
            Some(value) => text_of(Some(value), "")
            None => ""
          }
        }
        out.write_string(value)
        out.write_string(part[end + 1:].to_owned())
      }
      None => {
        out.write_char('{')
        out.write_string(part.to_owned())
      }
    }
  }
  out.to_string()
}

fn FieldPainter::draw_text(
  self : FieldPainter,
  field : Json,
  data : Json,
  x : Float,
  y : Float,
 ) -> Unit raise PdfmeError {
  let typ = text_of(json_field(field, "type"), "text")
  let mut text = field_text(field, data)
  if typ == "multiVariableText" {
    let name = text_of(json_field(field, "name"), "")
    let values = match json_field(data, name) {
      Some(value) => value
      None =>
        match json_field(field, "content") {
          Some(Json::String(content)) =>
            @json.parse(content[:]) catch { _ => Json::null() }
          _ => Json::null()
        }
    }
    let template = text_of(json_field(field, "text"), text)
    text = substitute_variables(template, values)
  }
  if text == "" {
    return
  }
  let size = Float::from_double(number_of(json_field(field, "fontSize"), 10.0))
  let line_height = Float::from_double(
    number_of(json_field(field, "lineHeight"), 1.2),
  ) * size
  let family = text_of(json_field(field, "fontName"), "Helvetica")
  let font = self.font(family)
  self.builder.font(font, size) catch {
    _ => raise PdfmeError("pdfme: a font cannot be set")
  }
  self.builder.fill_color(color_of(json_field(field, "fontColor"), 0x000000ff))
  let width = mm_to_pt(number_of(json_field(field, "width"), 50.0))
  let alignment = text_of(json_field(field, "alignment"), "left")
  let lines = split_lines(text)
  for i, line in lines {
    let advance = Float::from_double(
      line.length().to_double() * size.to_double() * 0.5,
    )
    let start = if alignment == "center" {
      x + (width - advance) / 2.0
    } else if alignment == "right" {
      x + width - advance
    } else {
      x
    }
    self.builder.fill_text(line, start, y - Float::from_double(i.to_double()) * line_height, advance)
  }
}

///|
///|
fn stroke_segment(
  builder : @core.ObjectBuilder,
  x1 : Float,
  y1 : Float,
  x2 : Float,
  y2 : Float,
) -> Unit raise PdfmeError {
  let path : @core.PathEntry = @core.PathEntry::Inline({
    verbs: Bytes::from_array([0, 1]),
    coordinates: [x1.to_double(), y1.to_double(), x2.to_double(), y2.to_double()],
  })
  let index = builder.add_path(path)
  builder.stroke_path(index) catch {
    _ => raise PdfmeError("pdfme: a path cannot be added")
  }
}

///|
struct FieldPainter {
  builder : @core.ObjectBuilder
  writer : @core.DocumentWriter
  fonts : Map[String, Int]
  warnings : Array[String]
  page_height : Float
  scale : Float
}

///|
fn FieldPainter::font(self : FieldPainter, family : String) -> Int raise PdfmeError {
  match self.fonts.get(family) {
    Some(index) => index
    None => {
      let index = self.builder.add_font({
        hash: None,
        family,
        weight: 400,
        style: 0,
      }) catch {
        _ => raise PdfmeError("pdfme: a font cannot be added")
      }
      self.fonts[family] = index
      index
    }
  }
}

///|
fn FieldPainter::draw_field(self : FieldPainter, field : Json, data : Json) -> Unit raise PdfmeError {
  let typ = text_of(json_field(field, "type"), "text")
  let position = match json_field(field, "position") {
    Some(value) => value
    None => return
  }
  let x_mm = number_of(json_field(position, "x"), 0.0)
  let y_mm = number_of(json_field(position, "y"), 0.0)
  let width_mm = number_of(json_field(field, "width"), 20.0)
  let height_mm = number_of(json_field(field, "height"), 5.0)
  let x = mm_to_pt(x_mm)
  let y_top = self.page_height - mm_to_pt(y_mm)
  let width = mm_to_pt(width_mm)
  let height = mm_to_pt(height_mm)
  if typ == "text" || typ == "multiVariableText" || typ == "select" || typ == "date" {
    match json_field(field, "backgroundColor") {
      Some(value) => {
        self.builder.fill_color(color_of(Some(value), 0xffffffff))
        self.builder.fill_rect(x, y_top - height, width, height)
      }
      None => ()
    }
    match json_field(field, "borderColor") {
      Some(value) => {
        self.builder.stroke_color(color_of(Some(value), 0x000000ff))
        self.builder.line(
          Float::from_double(number_of(json_field(field, "borderWidth"), 0.3)),
          0,
          0,
          0.0F,
        )
        self.builder.stroke_rect(x, y_top - height, width, height)
      }
      None => ()
    }
    let size = Float::from_double(number_of(json_field(field, "fontSize"), 10.0))
    let baseline = y_top - size
    self.draw_text(field, data, x, baseline)
  } else if typ == "line" {
    let width = Float::max(0.5, height)
    self.builder.stroke_color(color_of(json_field(field, "color"), 0x000000ff))
    self.builder.line(width, 0, 0, 0.0F)
    stroke_segment(self.builder, x, y_top, x + mm_to_pt(width_mm), y_top)
  } else if typ == "rectangle" {
    self.builder.fill_color(color_of(json_field(field, "color"), 0xffffffff))
    self.builder.stroke_color(color_of(json_field(field, "borderColor"), 0x000000ff))
    self.builder.line(
      Float::from_double(number_of(json_field(field, "borderWidth"), 0.3)),
      0,
      0,
      0.0F,
    )
    self.builder.fill_rect(x, y_top - height, width, height)
    self.builder.stroke_rect(x, y_top - height, width, height)
  } else if typ == "qrcode" {
    self.draw_qr(field, data, x, y_top, width, height)
  } else if typ == "barcode" {
    self.draw_barcode(field, data, x, y_top, width, height)
  } else if typ == "image" {
    self.draw_image(field, data, x, y_top, width, height)
  } else if typ == "table" {
    self.draw_table(field, data, x, y_top, width, height)
  } else if typ == "checkbox" {
    let checked = match json_field(data, text_of(json_field(field, "name"), "")) {
      Some(Json::True) => true
    Some(Json::False) => false
      _ => false
    }
    self.builder.stroke_color(0x000000ff)
    self.builder.line(0.8, 0, 0, 0.0F)
    self.builder.stroke_rect(x, y_top - height, width, height)
    if checked {
      stroke_segment(self.builder, x, y_top, x + width, y_top - height)
      stroke_segment(self.builder, x, y_top - height, x + width, y_top)
    }
  } else {
    self.warnings.push("pdfme: the field type \"" + typ + "\" is not supported yet")
  }
}



///|
fn png_size(data : Bytes) -> (Double, Double)? {
  if data.length() < 24 || data[0].to_int() != 0x89 || data[1].to_int() != 0x50 ||
    data[2].to_int() != 0x4e || data[3].to_int() != 0x47 {
    return None
  }
  let width = (data[16].to_int() << 24) |
    (data[17].to_int() << 16) |
    (data[18].to_int() << 8) |
    data[19].to_int()
  let height = (data[20].to_int() << 24) |
    (data[21].to_int() << 16) |
    (data[22].to_int() << 8) |
    data[23].to_int()
  if width > 0 && height > 0 {
    Some((width.to_double(), height.to_double()))
  } else {
    None
  }
}

///|
fn FieldPainter::draw_image(
  self : FieldPainter,
  field : Json,
  data : Json,
  x : Float,
  y_top : Float,
  width : Float,
  height : Float,
) -> Unit raise PdfmeError {
  let value = field_text(field, data)
  let comma = match value.find(",") {
    Some(index) => index
    None => raise PdfmeError("pdfme: the image is not a data URI")
  }
  if !value[:comma].contains("base64") {
    raise PdfmeError("pdfme: the image is not base64 data")
  }
  let payload = value[comma + 1:].to_owned()
  let bytes = @base64.decode(payload) catch {
    _ => raise PdfmeError("pdfme: the image data is not base64")
  }
  match png_size(bytes) {
    Some(_) => ()
    None => raise PdfmeError("pdfme: the image is not a PNG")
  }
  let hash = self.writer.add_part("img", bytes) catch {
    _ => raise PdfmeError("pdfme: the image cannot be added")
  }
  let index = self.builder.add_image(hash)
  self.builder.image(index, x, y_top - height, width, height) catch {
    _ => raise PdfmeError("pdfme: the image cannot be placed")
  }
}

///|
fn code39_pattern(c : Char) -> String? {
  if c >= '0' && c <= '9' {
    return Some([
      "nnnwwnwnn", "wnnwnnnnw", "nnwwnnnnw", "wnwwnnnnn", "nnnwwnnnw",
      "wnnwwnnnn", "nnwwwnnnn", "nnnwnnwnw", "wnnwnnwnn", "nnwwnnwnn",
    ][c.to_int() - '0'.to_int()])
  }
  let index = if c >= 'A' && c <= 'Z' {
    c.to_int() - 'A'.to_int()
  } else {
    -1
  }
  if index >= 0 {
    return Some([
      "wnnnnwnnw", "nnwnnwnnw", "wnwnnwnnn", "nnnnwwnnw", "wnnnwwnnn",
      "nnwnwwnnn", "nnnnnwwnw", "wnnnnwwnn", "nnwnnwwnn", "nnnnwwwnn",
      "wnnnnnnww", "nnwnnnnww", "wnwnnnnwn", "nnnnwnnww", "wnnnwnnwn",
      "nnwnwnnwn", "nnnnnnwww", "wnnnnnwwn", "nnwnnnwwn", "nnnnwnwwn",
      "wwnnnnnnw", "nwwnnnnnw", "wwwnnnnnn", "nwnnwnnnw", "wwnnwnnnn",
      "nwwnwnnnn",
    ][index])
  }
  if c == '-' {
    Some("nwnnnnwnw")
  } else if c == '.' {
    Some("wwnnnnwnn")
  } else if c == ' ' {
    Some("nwwnnnwnn")
  } else if c == '$' {
    Some("nwnwnwnnn")
  } else if c == '/' {
    Some("nwnwnnnwn")
  } else if c == '+' {
    Some("nwnnnwnwn")
  } else if c == '%' {
    Some("nnnwnwnwn")
  } else if c == '*' {
    Some("nwnnwnwnn")
  } else {
    None
  }
}

///|
fn barcode_units(pattern : String) -> Int {
  let mut units = 0
  for c in pattern {
    units += if c == 'w' { 3 } else { 1 }
  }
  units
}

///|
fn ean13_bits(value : String) -> String raise PdfmeError {
  let digits : Array[Int] = []
  for c in value {
    if c < '0' || c > '9' {
      raise PdfmeError("pdfme: EAN-13 takes digits only")
    }
    digits.push(c.to_int() - '0'.to_int())
  }
  if digits.length() == 12 {
    let mut sum = 0
    for i, digit in digits {
      sum += if i % 2 == 0 { digit } else { digit * 3 }
    }
    digits.push((10 - sum % 10) % 10)
  }
  if digits.length() != 13 {
    raise PdfmeError("pdfme: EAN-13 takes 12 or 13 digits")
  }
  let left = [
    "0001101", "0011001", "0010011", "0111101", "0100011", "0110001",
    "0101111", "0111011", "0110111", "0001011",
  ]
  let right = [
    "1110010", "1100110", "1101100", "1000010", "1011100", "1001110",
    "1010000", "1000100", "1001000", "1110100",
  ]
  let parity = [
    "LLLLLL", "LLGLGG", "LLGGLG", "LLGGGL", "LGLLGG", "LGGLLG", "LGGGLL",
    "LGLGLG", "LGLGGL", "LGGLGL",
  ]
  let out = StringBuilder()
  out.write_string("101")
  let first = digits[0]
  let parity_text = parity[first]
  for i in 0..<6 {
    let digit = digits[i + 1]
    if parity_text[i] == 'L' {
      out.write_string(left[digit])
    } else {
      let l = left[digit]
      let g = String::make(l.length(), '0')
      let chars = g.to_array()
      for j in 0..<l.length() {
        chars[j] = if l[j] == '1' { '0' } else { '1' }
      }
      // G is L reversed and complemented.
      let reversed = StringBuilder()
      for j in 0..<l.length() {
        reversed.write_char(chars[l.length() - 1 - j])
      }
      out.write_string(reversed.to_string())
    }
  }
  out.write_string("01010")
  for i in 7..<13 {
    out.write_string(right[digits[i]])
  }
  out.write_string("101")
  out.to_string()
}

///|
fn FieldPainter::draw_ean13(
  self : FieldPainter,
  field : Json,
  data : Json,
  x : Float,
  y_top : Float,
  width : Float,
  height : Float,
) -> Unit raise PdfmeError {
  let value = field_text(field, data)
  if value == "" {
    return
  }
  let bits = ean13_bits(value)
  let module = width / Float::from_double(bits.length().to_double())
  self.builder.fill_color(0x000000ff)
  for i in 0..<bits.length() {
    if bits[i] == '1' {
      self.builder.fill_rect(
        x + Float::from_double(i.to_double()) * module,
        y_top - height,
        module,
        height,
      )
    }
  }
}

///|
fn ean8_bits(value : String) -> String raise PdfmeError {
  let digits : Array[Int] = []
  for c in value {
    if c < '0' || c > '9' {
      raise PdfmeError("pdfme: EAN-8 takes digits only")
    }
    digits.push(c.to_int() - '0'.to_int())
  }
  if digits.length() == 7 {
    let mut sum = 0
    for i, digit in digits {
      sum += if i % 2 == 0 { digit * 3 } else { digit }
    }
    digits.push((10 - sum % 10) % 10)
  }
  if digits.length() != 8 {
    raise PdfmeError("pdfme: EAN-8 takes 7 or 8 digits")
  }
  let left = [
    "0001101", "0011001", "0010011", "0111101", "0100011", "0110001",
    "0101111", "0111011", "0110111", "0001011",
  ]
  let right = [
    "1110010", "1100110", "1101100", "1000010", "1011100", "1001110",
    "1010000", "1000100", "1001000", "1110100",
  ]
  let out = StringBuilder()
  out.write_string("101")
  for i in 0..<4 {
    out.write_string(left[digits[i]])
  }
  out.write_string("01010")
  for i in 4..<8 {
    out.write_string(right[digits[i]])
  }
  out.write_string("101")
  out.to_string()
}

///|
fn FieldPainter::draw_ean8(
  self : FieldPainter,
  field : Json,
  data : Json,
  x : Float,
  y_top : Float,
  width : Float,
  height : Float,
) -> Unit raise PdfmeError {
  let value = field_text(field, data)
  if value == "" {
    return
  }
  let bits = ean8_bits(value)
  let cell = width / Float::from_double(bits.length().to_double())
  self.builder.fill_color(0x000000ff)
  for i in 0..<bits.length() {
    if bits[i] == '1' {
      self.builder.fill_rect(
        x + Float::from_double(i.to_double()) * cell,
        y_top - height,
        cell,
        height,
      )
    }
  }
}

///|
fn code128_patterns() -> Array[String] {
  [
  "212222", "222122", "222221", "121223", "121322", "131222", "122213",
  "122312", "132212", "221213", "221312", "231212", "112232", "122132",
  "122231", "113222", "123122", "123221", "223211", "221132", "221231",
  "213212", "223112", "312131", "311222", "321122", "321221", "312212",
  "322112", "322211", "212123", "212321", "232121", "111323", "131123",
  "131321", "112313", "132113", "132311", "211313", "231113", "231311",
  "112133", "112331", "132131", "113123", "113321", "133121", "313121",
  "211331", "231131", "213113", "213311", "213131", "311123", "311321",
  "331121", "312113", "312311", "332111", "314111", "221411", "431111",
  "111224", "111422", "121124", "121421", "141122", "141221", "112214",
  "112412", "122114", "122411", "142112", "142211", "241211", "221114",
  "413111", "241112", "134111", "111242", "121142", "121241", "114212",
  "124112", "124211", "411212", "421112", "421211", "212141", "214121",
  "412121", "111143", "111341", "131141", "114113", "114311", "411113",
  "411311", "113141", "114131", "311141", "411131", "211412", "211214",
  "211232", "2331112",
  ]
}

///|
fn gs1_fixed_ai(ai : String) -> Bool {
  match ai {
    "00" | "01" | "02" | "03" | "04" | "11" | "12" | "13" | "14" | "15" |
    "16" | "17" | "18" | "19" | "20" | "22" | "23" | "24" | "25" | "30" |
    "37" | "400" | "401" | "402" | "403" | "410" | "411" | "412" | "413" |
    "414" | "415" | "416" | "417" | "420" | "421" | "422" | "423" | "424" |
    "425" | "426" | "427" => true
    _ => false
  }
}

///|
fn gs1_groups(value : String) -> Array[(String, String)] {
  let groups : Array[(String, String)] = []
  let mut i = 0
  while i < value.length() {
    if value[i].to_char().unwrap() != '(' {
      groups.push(("", value[i:].to_owned()))
      break
    }
    let close = match value[i:].find(")") {
      Some(index) => i + index
      None => {
        groups.push(("", value[i:].to_owned()))
        break
      }
    }
    let ai = value[i + 1:close].to_owned()
    let next = match value[close + 1:].find("(") {
      Some(index) => close + 1 + index
      None => value.length()
    }
    groups.push((ai, value[close + 1:next].to_owned()))
    i = next
  }
  groups
}

///|
fn FieldPainter::draw_code128_values(
  self : FieldPainter,
  values : Array[Int],
  x : Float,
  y_top : Float,
  width : Float,
  height : Float,
) -> Unit {
  let mut checksum = values[0]
  for i in 1..<values.length() {
    checksum += values[i] * i
  }
  let all = values.copy()
  all.push(checksum % 103)
  all.push(106)
  let patterns = code128_patterns()
  let widths : Array[Int] = []
  for code in all {
    for ch in patterns[code] {
      widths.push(ch.to_int() - '0'.to_int())
    }
  }
  let mut total = 0
  for unit in widths {
    total += unit
  }
  let module = width / Float::from_double(total.to_double())
  self.builder.fill_color(0x000000ff)
  let mut cursor = 0
  let mut bar = true
  for unit in widths {
    if bar {
      self.builder.fill_rect(
        x + Float::from_double(cursor.to_double()) * module,
        y_top - height,
        Float::from_double(unit.to_double()) * module,
        height,
      )
    }
    cursor += unit
    bar = !bar
  }
}

///|
fn FieldPainter::draw_gs1_128(
  self : FieldPainter,
  field : Json,
  data : Json,
  x : Float,
  y_top : Float,
  width : Float,
  height : Float,
) -> Unit raise PdfmeError {
  let value = field_text(field, data)
  if value == "" {
    return
  }
  let groups = gs1_groups(value)
  let values : Array[Int] = [104, 102]
  for i, group in groups {
    let (ai, text) = group
    for c in ai + text {
      let code = c.to_int()
      if code < 32 || code > 126 {
        raise PdfmeError("pdfme: GS1-128 takes printable ASCII only")
      }
      values.push(code - 32)
    }
    if ai != "" && !gs1_fixed_ai(ai) && i + 1 < groups.length() {
      values.push(102)
    }
  }
  self.draw_code128_values(values, x, y_top, width, height)
}

///|
fn FieldPainter::draw_code128(
  self : FieldPainter,
  field : Json,
  data : Json,
  x : Float,
  y_top : Float,
  width : Float,
  height : Float,
) -> Unit raise PdfmeError {
  let value = field_text(field, data)
  if value == "" {
    return
  }
  let values : Array[Int] = [104]
  for c in value {
    let code = c.to_int()
    if code < 32 || code > 126 {
      raise PdfmeError("pdfme: Code 128 takes printable ASCII only")
    }
    values.push(code - 32)
  }
  self.draw_code128_values(values, x, y_top, width, height)
}

///|
fn itf_digit_pattern(c : Char) -> String? {
  if c < '0' || c > '9' {
    return None
  }
  let patterns = [
    "nnwwn", "wnnnw", "nwnnw", "wwnnn", "nnwnw", "wnwnn", "nwwnn", "nnnww",
    "wnnwn", "nwnwn",
  ]
  Some(patterns[c.to_int() - '0'.to_int()])
}

///|
fn itf_bits(value : String) -> String raise PdfmeError {
  let digits = value.to_array()
  if digits.length() == 0 {
    return ""
  }
  let digits = if digits.length() % 2 == 1 {
    let padded : Array[Char] = ['0']
    for c in digits {
      padded.push(c)
    }
    padded
  } else {
    digits
  }
  let out = StringBuilder()
  out.write_string("1010")
  for i in 0..<(digits.length() / 2) {
    let bars = match itf_digit_pattern(digits[i * 2]) {
      Some(pattern) => pattern
      None => raise PdfmeError("pdfme: ITF takes digits only")
    }
    let spaces = match itf_digit_pattern(digits[i * 2 + 1]) {
      Some(pattern) => pattern
      None => raise PdfmeError("pdfme: ITF takes digits only")
    }
    for j in 0..<5 {
      for _ in 0..<(if bars[j] == 'w' { 3 } else { 1 }) {
        out.write_char('1')
      }
      for _ in 0..<(if spaces[j] == 'w' { 3 } else { 1 }) {
        out.write_char('0')
      }
    }
  }
  out.write_string("11101")
  out.to_string()
}

///|
fn FieldPainter::draw_itf(
  self : FieldPainter,
  field : Json,
  data : Json,
  x : Float,
  y_top : Float,
  width : Float,
  height : Float,
) -> Unit raise PdfmeError {
  let value = field_text(field, data)
  if value == "" {
    return
  }
  let bits = itf_bits(value)
  let cell = width / Float::from_double(bits.length().to_double())
  self.builder.fill_color(0x000000ff)
  for i in 0..<bits.length() {
    if bits[i] == '1' {
      self.builder.fill_rect(
        x + Float::from_double(i.to_double()) * cell,
        y_top - height,
        cell,
        height,
      )
    }
  }
}

///|
///|
fn FieldPainter::draw_upca(
  self : FieldPainter,
  field : Json,
  data : Json,
  x : Float,
  y_top : Float,
  width : Float,
  height : Float,
) -> Unit raise PdfmeError {
  let value = field_text(field, data)
  if value == "" {
    return
  }
  let bits = ean13_bits("0" + value)
  let cell = width / Float::from_double(bits.length().to_double())
  self.builder.fill_color(0x000000ff)
  for i in 0..<bits.length() {
    if bits[i] == '1' {
      self.builder.fill_rect(
        x + Float::from_double(i.to_double()) * cell,
        y_top - height,
        cell,
        height,
      )
    }
  }
}

///|
fn upce_expand(body : String, number_system : Int) -> Array[Int] {
  let d : Array[Int] = []
  for c in body {
    d.push(c.to_int() - '0'.to_int())
  }
  if d.length() != 6 {
    return []
  }
  let manufacturer : Array[Int] = []
  let product : Array[Int] = []
  match d[5] {
    0 | 1 | 2 => {
      manufacturer.push(d[0])
      manufacturer.push(d[1])
      manufacturer.push(d[5])
      manufacturer.push(0)
      manufacturer.push(0)
      product.push(0)
      product.push(0)
      product.push(d[2])
      product.push(d[3])
      product.push(d[4])
    }
    3 => {
      manufacturer.push(d[0])
      manufacturer.push(d[1])
      manufacturer.push(d[2])
      manufacturer.push(0)
      manufacturer.push(0)
      product.push(0)
      product.push(0)
      product.push(0)
      product.push(d[3])
      product.push(d[4])
    }
    4 => {
      manufacturer.push(d[0])
      manufacturer.push(d[1])
      manufacturer.push(d[2])
      manufacturer.push(d[3])
      manufacturer.push(0)
      product.push(0)
      product.push(0)
      product.push(0)
      product.push(0)
      product.push(d[4])
    }
    _ => {
      for i in 0..<5 {
        manufacturer.push(d[i])
      }
      product.push(0)
      product.push(0)
      product.push(0)
      product.push(0)
      product.push(d[5])
    }
  }
  let all : Array[Int] = [number_system]
  for digit in manufacturer {
    all.push(digit)
  }
  for digit in product {
    all.push(digit)
  }
  all
}

///|
fn upce_bits(value : String) -> String raise PdfmeError {
  let digits : Array[Int] = []
  for c in value {
    if c < '0' || c > '9' {
      raise PdfmeError("pdfme: UPC-E takes digits only")
    }
    digits.push(c.to_int() - '0'.to_int())
  }
  let (number_system, body, check) = if digits.length() == 6 {
    (0, value, -1)
  } else if digits.length() == 7 {
    (digits[0], value[1:].to_owned(), -1)
  } else if digits.length() == 8 {
    (digits[0], value[1:7].to_owned(), digits[7])
  } else {
    raise PdfmeError("pdfme: UPC-E takes 6, 7 or 8 digits")
  }
  if number_system != 0 && number_system != 1 {
    raise PdfmeError("pdfme: UPC-E takes number system 0 or 1")
  }
  let expanded = upce_expand(body, number_system)
  if expanded.length() != 11 {
    raise PdfmeError("pdfme: UPC-E takes 6 digits")
  }
  let mut sum = 0
  for i, digit in expanded {
    sum += if i % 2 == 0 { digit * 3 } else { digit }
  }
  let computed = (10 - sum % 10) % 10
  let check_digit = if check >= 0 { check } else { computed }
  let parity = [
    "EEEOOO", "EEOEOO", "EEOOEO", "EEOOOE", "EOEEOO", "EOOEEO", "EOOOEE",
    "EOEOEO", "EOEOOE", "EOOEOE",
  ]
  let left = [
    "0001101", "0011001", "0010011", "0111101", "0100011", "0110001",
    "0101111", "0111011", "0110111", "0001011",
  ]
  let out = StringBuilder()
  out.write_string("101")
  let parity_text = parity[check_digit]
  for i in 0..<6 {
    let digit = body[i].to_char().unwrap().to_int() - '0'.to_int()
    let l = left[digit]
    if parity_text[i] == 'E' {
      out.write_string(l)
    } else {
      let reversed = StringBuilder()
      for j in 0..<l.length() {
        let bit = l[l.length() - 1 - j]
        reversed.write_char(if bit == '1' { '0' } else { '1' })
      }
      out.write_string(reversed.to_string())
    }
  }
  out.write_string("010101")
  out.to_string()
}

///|
fn FieldPainter::draw_upce(
  self : FieldPainter,
  field : Json,
  data : Json,
  x : Float,
  y_top : Float,
  width : Float,
  height : Float,
) -> Unit raise PdfmeError {
  let value = field_text(field, data)
  if value == "" {
    return
  }
  let bits = upce_bits(value)
  let module = width / Float::from_double(bits.length().to_double())
  self.builder.fill_color(0x000000ff)
  for i in 0..<bits.length() {
    if bits[i] == '1' {
      self.builder.fill_rect(
        x + Float::from_double(i.to_double()) * module,
        y_top - height,
        module,
        height,
      )
    }
  }
}

///|
fn msi_digit_bits(c : Char) -> String? {
  let patterns = [
    "100100100100", "100100100110", "100100110100", "100100110110",
    "100110100100", "100110100110", "100110110100", "100110110110",
    "101100100100", "101100100110",
  ]
  if c < '0' || c > '9' {
    return None
  }
  Some(patterns[c.to_int() - '0'.to_int()])
}

///|
fn FieldPainter::draw_msi(
  self : FieldPainter,
  field : Json,
  data : Json,
  x : Float,
  y_top : Float,
  width : Float,
  height : Float,
) -> Unit raise PdfmeError {
  let value = field_text(field, data)
  if value == "" {
    return
  }
  let bits = StringBuilder()
  bits.write_string("110")
  for c in value {
    let pattern = match msi_digit_bits(c) {
      Some(pattern) => pattern
      None => raise PdfmeError("pdfme: MSI takes digits only")
    }
    bits.write_string(pattern)
  }
  bits.write_string("1001")
  let text = bits.to_string()
  let module = width / Float::from_double(text.length().to_double())
  self.builder.fill_color(0x000000ff)
  for i in 0..<text.length() {
    if text[i] == '1' {
      self.builder.fill_rect(
        x + Float::from_double(i.to_double()) * module,
        y_top - height,
        module,
        height,
      )
    }
  }
}

///|
fn code93_index(c : Char) -> Int? {
  let code = c.to_int()
  if code >= '0'.to_int() && code <= '9'.to_int() {
    Some(code - '0'.to_int())
  } else if code >= 'A'.to_int() && code <= 'Z'.to_int() {
    Some(code - 'A'.to_int() + 10)
  } else {
    match c {
      '-' => Some(36)
      '.' => Some(37)
      ' ' => Some(38)
      '$' => Some(39)
      '/' => Some(40)
      '+' => Some(41)
      '%' => Some(42)
      _ => None
    }
  }
}

///|
fn code93_patterns() -> Array[String] {
  [
    "100010100", "101001000", "101000100", "101000010", "100101000",
    "100100100", "100100010", "101010000", "100010010", "100001010",
    "110101000", "110100100", "110100010", "110010100", "110010010",
    "110001010", "101101000", "101100100", "101100010", "100110100",
    "100011010", "101011000", "101001100", "101000110", "100101100",
    "100010110", "110110100", "110110010", "110101100", "110100110",
    "110010110", "110011010", "101101100", "101100110", "100110110",
    "100111010", "100101110", "111010100", "111010010", "111001010",
    "101101110", "101110110", "110101110", "100100110", "111011010",
    "111010110", "100110010", "101011110",
  ]
}

///|
fn code93_check(values : Array[Int]) -> Int {
  let mut weight = 1
  let mut sum = 0
  for i in 0..<values.length() {
    sum += values[values.length() - 1 - i] * weight
    weight += 1
    if weight > 20 {
      weight = 1
    }
  }
  sum % 47
}

///|
fn FieldPainter::draw_code93(
  self : FieldPainter,
  field : Json,
  data : Json,
  x : Float,
  y_top : Float,
  width : Float,
  height : Float,
) -> Unit raise PdfmeError {
  let value = field_text(field, data).to_upper()
  if value == "" {
    return
  }
  let values : Array[Int] = []
  for c in value {
    let index = match code93_index(c) {
      Some(index) => index
      None => raise PdfmeError("pdfme: Code 93 takes digits, A-Z and - . space $ / + %")
    }
    values.push(index)
  }
  let c_check = code93_check(values)
  let k_values = values.copy()
  k_values.push(c_check)
  let k_check = code93_check(k_values)
  let patterns = code93_patterns()
  let bits = StringBuilder()
  bits.write_string(patterns[47])
  for index in values {
    bits.write_string(patterns[index])
  }
  bits.write_string(patterns[c_check])
  bits.write_string(patterns[k_check])
  bits.write_string(patterns[47])
  bits.write_char('1')
  let text = bits.to_string()
  let module = width / Float::from_double(text.length().to_double())
  self.builder.fill_color(0x000000ff)
  for i in 0..<text.length() {
    if text[i] == '1' {
      self.builder.fill_rect(
        x + Float::from_double(i.to_double()) * module,
        y_top - height,
        module,
        height,
      )
    }
  }
}

///|
fn FieldPainter::draw_barcode(
  self : FieldPainter,
  field : Json,
  data : Json,
  x : Float,
  y_top : Float,
  width : Float,
  height : Float,
) -> Unit raise PdfmeError {
  let format = text_of(json_field(field, "format"), "code39")
  if format == "ean13" {
    self.draw_ean13(field, data, x, y_top, width, height)
    return
  }
  if format == "ean8" {
    self.draw_ean8(field, data, x, y_top, width, height)
    return
  }
  if format == "upca" {
    self.draw_upca(field, data, x, y_top, width, height)
    return
  }
  if format == "upce" {
    self.draw_upce(field, data, x, y_top, width, height)
    return
  }
  if format == "msi" {
    self.draw_msi(field, data, x, y_top, width, height)
    return
  }
  if format == "code93" {
    self.draw_code93(field, data, x, y_top, width, height)
    return
  }
  if format == "code128" {
    self.draw_code128(field, data, x, y_top, width, height)
    return
  }
  if format == "gs1" || format == "gs1-128" {
    self.draw_gs1_128(field, data, x, y_top, width, height)
    return
  }
  if format == "itf" || format == "itf14" {
    self.draw_itf(field, data, x, y_top, width, height)
    return
  }
  if format == "nw7" || format == "codabar" {
    self.draw_nw7(field, data, x, y_top, width, height)
    return
  }
  if format != "" && format != "code39" {
    self.warnings.push("pdfme: the barcode format is not supported yet")
    return
  }
  let value = field_text(field, data).to_upper()
  if value == "" {
    return
  }
  let text = "*" + value + "*"
  let patterns : Array[String] = []
  let mut total = 0
  for c in text {
    let pattern = match code39_pattern(c) {
      Some(pattern) => pattern
      None => raise PdfmeError(
        "pdfme: the character cannot be encoded as Code 39",
      )
    }
    patterns.push(pattern)
    total += barcode_units(pattern) + 1
  }
  if total <= 1 {
    return
  }
  let unit = width / Float::from_double((total - 1).to_double())
  self.builder.fill_color(0x000000ff)
  let mut cursor = 0
  for pattern in patterns {
    let mut bar = true
    for c in pattern {
      let cell = if c == 'w' { 3 } else { 1 }
      if bar {
        self.builder.fill_rect(
          x + Float::from_double(cursor.to_double()) * unit,
          y_top - height,
          Float::from_double(cell.to_double()) * unit,
          height,
        )
      }
      cursor += cell
      bar = !bar
    }
    cursor += 1
  }
}

fn FieldPainter::draw_qr(
  self : FieldPainter,
  field : Json,
  data : Json,
  x : Float,
  y_top : Float,
  width : Float,
  height : Float,
) -> Unit raise PdfmeError {
  let value = field_text(field, data)
  if value == "" {
    return
  }
  let qr = @qrcode.encode(value) catch {
    _ => raise PdfmeError("pdfme: the value cannot be encoded as a QR code")
  }
  let modules = qr.size()
  if modules <= 0 {
    return
  }
  let side = if width < height { width } else { height }
  let cell = side / Float::from_double(modules.to_double())
  self.builder.fill_color(0x000000ff)
  for row in 0..<modules {
    for column in 0..<modules {
      if qr.get(column, row) {
        self.builder.fill_rect(
          x + Float::from_double(column.to_double()) * cell,
          y_top - Float::from_double((row + 1).to_double()) * cell,
          cell,
          cell,
        )
      }
    }
  }
}

///|
fn table_column_alignment(field : Json, index : Int, head : Bool) -> String {
  if head {
    match json_field(field, "headStyles") {
      Some(Json::Object(styles)) => text_of(styles.get("alignment"), "left")
      _ => "left"
    }
  } else {
    match json_field(field, "columnStyles") {
      Some(Json::Array(styles)) =>
        if index < styles.length() {
          match styles[index] {
            Json::Object(style) => text_of(style.get("alignment"), "left")
            _ => "left"
          }
        } else {
          "left"
        }
      _ => "left"
    }
  }
}

///|
///|
fn table_column_background(field : Json, index : Int) -> UInt32 {
  match json_field(field, "columnStyles") {
    Some(Json::Array(styles)) =>
      if index < styles.length() {
        match styles[index] {
          Json::Object(style) => color_of(style.get("backgroundColor"), 0x00000000)
          _ => 0x00000000
        }
      } else {
        0x00000000
      }
    _ => 0x00000000
  }
}

///|
fn table_column_color(field : Json, index : Int, fallback : UInt32) -> UInt32 {
  match json_field(field, "columnStyles") {
    Some(Json::Array(styles)) =>
      if index < styles.length() {
        match styles[index] {
          Json::Object(style) => color_of(style.get("fontColor"), fallback)
          _ => fallback
        }
      } else {
        fallback
      }
    _ => fallback
  }
}

///|
///|
fn FieldPainter::draw_table(
  self : FieldPainter,
  field : Json,
  data : Json,
  x : Float,
  y_top : Float,
  width : Float,
  height : Float,
) -> Unit raise PdfmeError {
  let name = text_of(json_field(field, "name"), "")
  let rows = match json_field(data, name) {
    Some(Json::Array(rows)) => rows
    _ => []
  }
  let head = match json_field(field, "head") {
    Some(Json::Array(values)) =>
      values.map(fn(value) { text_of(Some(value), "") })
    _ => []
  }
  let columns = if head.length() > 0 {
    head.length()
  } else if rows.length() > 0 {
    match rows[0] {
      Json::Object(object) => object.size()
      _ => 1
    }
  } else {
    1
  }
  let percentage_values = match json_field(field, "headWidthPercentages") {
    Some(Json::Array(values)) => Some(values)
    _ =>
      match json_field(field, "widthPercentages") {
        Some(Json::Array(values)) => Some(values)
        _ => None
      }
  }
  let widths : Array[Float] = []
  let mut width_sum = 0.0
  match percentage_values {
    Some(values) =>
      if values.length() == columns {
        for value in values {
          let number = number_of(Some(value), 0.0)
          widths.push(Float::from_double(number))
          width_sum += number
        }
      }
    None => ()
  }
  if width_sum <= 0.0 || widths.length() != columns {
    widths.clear()
    for _ in 0..<columns {
      widths.push(1.0)
    }
  }
  let edges : Array[Float] = [0.0F]
  let mut edge = 0.0F
  for value in widths {
    edge += width * value / Float::from_double(width_sum)
    edges.push(edge)
  }
  let size = Float::from_double(number_of(json_field(field, "fontSize"), 8.0))
  let head_size = match json_field(field, "headStyles") {
    Some(Json::Object(styles)) =>
      Float::from_double(number_of(styles.get("fontSize"), size.to_double()))
    _ => size
  }
  let head_background = match json_field(field, "headStyles") {
    Some(Json::Object(styles)) =>
      color_of(styles.get("backgroundColor"), 0x00000000)
    _ => 0x00000000
  }
  let head_color = match json_field(field, "headStyles") {
    Some(Json::Object(styles)) =>
      color_of(styles.get("fontColor"), color_of(json_field(field, "fontColor"), 0x000000ff))
    _ => color_of(json_field(field, "fontColor"), 0x000000ff)
  }
  let font = self.font(text_of(json_field(field, "fontName"), "Helvetica"))
  self.builder.font(font, size) catch {
    _ => raise PdfmeError("pdfme: a font cannot be set")
  }
  self.builder.fill_color(color_of(json_field(field, "fontColor"), 0x000000ff))
  self.builder.stroke_color(0x000000ff)
  self.builder.line(0.4, 0, 0, 0.0F)
  let row_height = Float::from_double(
    number_of(json_field(field, "rowHeight"), 6.0),
  )
  let head_height = match json_field(field, "headStyles") {
    Some(Json::Object(styles)) =>
      Float::from_double(number_of(styles.get("height"), row_height.to_double()))
    _ => row_height
  }
  let mut y = y_top
  let draw_row = fn(values : Array[String], head_row : Bool) raise PdfmeError {
    let height = if head_row { head_height } else { row_height }
    let row_size = if head_row { head_size } else { size }
    self.builder.font(font, row_size) catch {
      _ => raise PdfmeError("pdfme: a font cannot be set")
    }
    if head_row {
      if head_background != 0x00000000 {
        self.builder.fill_color(head_background)
        self.builder.fill_rect(x, y - height, width, height)
      }
      self.builder.fill_color(head_color)
    } else {
      self.builder.fill_color(color_of(json_field(field, "fontColor"), 0x000000ff))
    }
    for i in 0..<columns {
      let text = if i < values.length() { values[i] } else { "" }
      let advance = Float::from_double(
        text.length().to_double() * row_size.to_double() * 0.5,
      )
      let cell_width = edges[i + 1] - edges[i]
      let background = if head_row { 0x00000000U } else { table_column_background(field, i) }
      if background != 0x00000000U {
        self.builder.fill_color(background)
        self.builder.fill_rect(x + edges[i], y - height, cell_width, height)
      }
      let base_color = color_of(json_field(field, "fontColor"), 0x000000ff)
      self.builder.fill_color(
        if head_row { head_color } else { table_column_color(field, i, base_color) },
      )
      let alignment = table_column_alignment(field, i, head_row)
      let start = if alignment == "center" {
        x + edges[i] + (cell_width - advance) / 2.0
      } else if alignment == "right" {
        x + edges[i + 1] - advance - 1.0
      } else {
        x + edges[i] + 1.0
      }
      self.builder.fill_text(text, start, y - row_size, advance)
    }
    for i in 0..=columns {
      let line_x = x + edges[i]
      stroke_segment(self.builder, line_x, y, line_x, y - height)
    }
    stroke_segment(self.builder, x, y, x + width, y)
    stroke_segment(self.builder, x, y - height, x + width, y - height)
    y = y - height
  }
  if head.length() > 0 {
    draw_row(head, true)
  }
  let mut drawn = 0
  let header_height = if head.length() > 0 { head_height } else { 0.0F }
  let max_rows = Float::to_int(Float::floor((height - header_height) / row_height))
  for row in rows {
    if drawn >= max_rows {
      self.warnings.push("pdfme: a table is cut at the page")
      break
    }
    let values = match row {
      Json::Object(object) =>
        head.map(fn(column) { text_of(object.get(column), "") })
      Json::Array(cells) =>
        cells.map(fn(cell) { text_of(Some(cell), "") })
      _ => []
    }
    draw_row(values, false)
    drawn += 1
  }
}

///|
fn pdf_box(data : Bytes, key : String) -> (Double, Double)? {
  let text = @utf8.decode_lossy(data[:])
  let start = match text.find(key) {
    Some(index) => index
    None => return None
  }
  let open_offset = match text[start:].find("[") {
    Some(index) => index
    None => return None
  }
  let open = start + open_offset
  let inner = text[open + 1:]
  let close_offset = match inner.find("]") {
    Some(index) => index
    None => return None
  }
  let close = open + 1 + close_offset
  let values : Array[Double] = []
  for token in text[open + 1:close].split(" ") {
    if token == "" {
      continue
    }
    let value = @string.parse_double(token.to_owned()) catch {
      _ => return None
    }
    values.push(value)
  }
  if values.length() < 4 {
    return None
  }
  let width = values[2] - values[0]
  let height = values[3] - values[1]
  if width > 0.0 && height > 0.0 {
    Some((width, height))
  } else {
    None
  }
}

///|
fn pdf_media_box(data : Bytes) -> (Double, Double)? {
  match pdf_box(data, "/MediaBox") {
    Some(size) => Some(size)
    None => pdf_box(data, "/CropBox")
  }
}

///|
fn base_pdf_bytes(template : Json) -> Bytes? {
  match json_field(template, "basePdf") {
    Some(Json::String(value)) => {
      let marker = "base64,"
      match value.find(marker) {
        Some(index) =>
          try {
            Some(@base64.decode(value[index + marker.length():].to_owned()))
          } catch {
            _ => None
          }
        None => None
      }
    }
    _ => None
  }
}

///|
fn pdf_rotation(data : Bytes) -> Int {
  let text = @utf8.decode_lossy(data[:])
  let at = match text.find("/Rotate") {
    Some(index) => index
    None => return 0
  }
  let mut i = at + 7
  while i < text.length() && text[i].to_char().unwrap() == ' ' {
    i += 1
  }
  let begin = i
  if i < text.length() && text[i].to_char().unwrap() == '-' {
    i += 1
  }
  while i < text.length() && text[i].to_char().unwrap() >= '0' &&
    text[i].to_char().unwrap() <= '9' {
    i += 1
  }
  if i == begin {
    return 0
  }
  let value = @string.parse_int(text[begin:i].to_owned()) catch {
    _ => return 0
  }
  let normalized = value % 360
  if normalized < 0 {
    normalized + 360
  } else {
    normalized
  }
}

///|
fn page_size(template : Json) -> (Double, Double) {
  match json_field(template, "basePdf") {
    Some(Json::Object(base)) => (
      number_of(base.get("width"), 210.0),
      number_of(base.get("height"), 297.0),
    )
    Some(Json::String(_)) =>
      match base_pdf_bytes(template) {
        Some(bytes) =>
          match pdf_media_box(bytes) {
            Some((width, height)) => {
              let rotation = pdf_rotation(bytes)
              let (width, height) = if rotation == 90 || rotation == 270 {
                (height, width)
              } else {
                (width, height)
              }
              (width * 25.4 / 72.0, height * 25.4 / 72.0)
            }
            None => (210.0, 297.0)
          }
        None => (210.0, 297.0)
      }
    _ => (210.0, 297.0)
  }
}

///|
fn static_schema(template : Json) -> Array[Json] {
  match json_field(template, "basePdf") {
    Some(Json::Object(base)) =>
      match base.get("staticSchema") {
        Some(Json::Array(fields)) => fields
        _ => []
      }
    _ => []
  }
}

///|
/// Fill a pdfme template (JSON) with data (a JSON object).
pub fn fill(template_bytes : Bytes, data_bytes : Bytes) -> FillResult raise PdfmeError {
  let template = @json.parse(@utf8.decode_lossy(template_bytes[:])) catch {
    _ => raise PdfmeError("pdfme: the template is not JSON")
  }
  let data = @json.parse(@utf8.decode_lossy(data_bytes[:])) catch {
    _ => raise PdfmeError("pdfme: the data is not JSON")
  }
  let (width_mm, height_mm) = page_size(template)
  let page_width = mm_to_pt(width_mm)
  let page_height = mm_to_pt(height_mm)
  let pages = match json_field(template, "schemas") {
    Some(Json::Array(pages)) => pages
    _ => raise PdfmeError("pdfme: the template has no schemas")
  }
  let writer = @core.DocumentWriter::new()
  let static_fields = static_schema(template)
  let warnings : Array[String] = []
  if base_pdf_bytes(template) is Some(_) {
    warnings.push("pdfme: the base PDF content is not drawn")
  }
  let mut page_count = 0
  for page_fields in pages {
    let fields = match page_fields {
      Json::Array(fields) => fields
      _ => []
    }
    let builder = @core.ObjectBuilder::new()
    builder.set_bbox(0.0, 0.0, page_width, page_height)
    builder.fill_color(0xffffffff)
    builder.fill_rect(0.0, 0.0, page_width, page_height)
    let painter : FieldPainter = {
      builder,
      writer,
      fonts: Map([]),
      warnings,
      page_height,
      scale: 1.0,
    }
    for field in static_fields {
      painter.draw_field(field, data)
    }
    for field in fields {
      painter.draw_field(field, data)
    }
    let hash = writer.add_part("obj", builder.encode()) catch {
      _ => raise PdfmeError("pdfme: a page cannot be encoded")
    }
    page_count += 1
    writer.add_view(
      Json::object({
        "id": Json::string("page" + page_count.to_string()),
        "kind": Json::string("fixed"),
        "pages": Json::array([
          Json::object({
            "w": Json::number(page_width.to_double()),
            "h": Json::number(page_height.to_double()),
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
  }
  let bdf = writer.write_single() catch {
    _ => raise PdfmeError("pdfme: the document cannot be written")
  }
  { bdf, pages: page_count, warnings }
}
