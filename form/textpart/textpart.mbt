///|
// The print image of a form filled from a plain-text template: the grid
// of columns and lines that the pages draw, as JSON (docs/spec.md §4).
pub const VERSION : Int = 1
pub const MAX_SIZE : Int = 64 << 20
pub const MAX_COLUMNS : Int = 4096
pub const MAX_LINES : Int = 4096
pub const MAX_PAGES : Int = 100000
pub const MAX_PAGE_LINES : Int = 1 << 20

pub const SIZE_WIDE : String = "wide"
pub const SIZE_TALL : String = "tall"
pub const SIZE_BIG : String = "big"

///|
pub suberror TextPartError {
  TextPartError(String)
  TextPartNone
}

///|
pub(all) struct Margin {
  left : Int
  top : Int
}

///|
pub(all) struct Range {
  col : Int
  cols : Int
  size : String
}

///|
pub(all) struct Line {
  text : String
  paper : Array[Range]
  size : Array[Range]
}

///|
pub(all) struct Page {
  lines : Array[Line]
}

///|
pub(all) struct Image {
  version : Int
  cpi : Double
  lpi : Double
  columns : Int
  lines : Int
  margin : Margin
  skip : Int
  ambiguous_wide : Bool
  font : String
  pages : Array[Page]
}

///|
pub(all) struct Cell {
  mut text : String
  col : Int
  cols : Int
  size : String
  paper : Bool
}

///|
pub(all) struct TextOptions {
  margins : Bool
  no_paper : Bool
  crlf : Bool
}

///|
pub fn Line::new(text : String) -> Line {
  { text, paper: [], size: [] }
}

///|
pub fn Range::new(col : Int, cols : Int, size : String) -> Range {
  { col, cols, size }
}

///|
pub fn Image::new() -> Image {
  {
    version: VERSION,
    cpi: 10.0,
    lpi: 6.0,
    columns: 80,
    lines: 66,
    margin: { left: 0, top: 0 },
    skip: 0,
    ambiguous_wide: false,
    font: "",
    pages: [],
  }
}

///|
/// The columns of a character: 2 for a wide character, 0 for one that takes
/// no column, and 1 for the others.
pub fn width(c : Char, ambiguous_wide : Bool) -> Int {
  @font_db.east_asian_width(c, ambiguous_wide)
}

///|
pub fn Line::tall(self : Line) -> Bool {
  for range in self.size {
    if range.size == SIZE_TALL || range.size == SIZE_BIG {
      return true
    }
  }
  false
}

///|
fn range_at(ranges : Array[Range], col : Int) -> String {
  for range in ranges {
    if col >= range.col && col < range.col + range.cols {
      return range.size
    }
  }
  ""
}

///|
fn paper_at(ranges : Array[Range], col : Int) -> Bool {
  for range in ranges {
    if col >= range.col && col < range.col + range.cols {
      return true
    }
  }
  false
}

///|
/// The characters of a line with their columns; a combining character is
/// part of the cell before it.
pub fn Image::cells(self : Image, line : Line) -> Array[Cell] {
  let out : Array[Cell] = []
  let mut col = 0
  for c in line.text {
    let w = width(c, self.ambiguous_wide)
    if w == 0 && !out.is_empty() {
      let last = out[out.length() - 1]
      last.text += c.to_string()
      continue
    }
    let size = range_at(line.size, col)
    let mut cols = w
    if size == SIZE_WIDE || size == SIZE_BIG {
      cols *= 2
    }
    out.push({
      text: c.to_string(),
      col,
      cols,
      size,
      paper: paper_at(line.paper, col),
    })
    col += cols
  }
  out
}

///|
/// The lines that a page prints: the paper without the top margin and the
/// skip, or all lines on a roll (Lines 0).
pub fn Image::rows(self : Image, page : Page) -> Int {
  if self.lines == 0 {
    return page.lines.length()
  }
  self.lines - self.margin.top - self.skip
}

///|
fn spaces(count : Int) -> String {
  let out = StringBuilder()
  for _ in 0..<count {
    out.write_char(' ')
  }
  out.to_string()
}

///|
/// The image as plain text: lines ended by LF, pages by FF, double-width
/// characters followed by the spaces of their other columns.
pub fn Image::text(self : Image, options : TextOptions) -> String {
  let newline = if options.crlf { "\r\n" } else { "\n" }
  let out = StringBuilder()
  for pi, page in self.pages {
    if pi > 0 {
      out.write_char('\u{c}')
    }
    if options.margins {
      for _ in 0..<self.margin.top {
        out.write_string(newline)
      }
    }
    for line in page.lines {
      let text = StringBuilder()
      if options.margins {
        text.write_string(spaces(self.margin.left))
      }
      for cell in self.cells(line) {
        let w = width(cell.text.to_array()[0], self.ambiguous_wide)
        if options.no_paper && cell.paper {
          text.write_string(spaces(cell.cols))
        } else {
          text.write_string(cell.text)
          text.write_string(spaces(cell.cols - w))
        }
      }
      out.write_string(text.to_string().trim_end().to_string())
      out.write_string(newline)
    }
  }
  out.to_string()
}

///|
fn json_int(object : Map[String, Json], key : String, default : Int) -> Int {
  match object.get(key) {
    Some(Json::Number(value, ..)) => value.to_int()
    _ => default
  }
}

///|
fn json_double(object : Map[String, Json], key : String, default : Double) -> Double {
  match object.get(key) {
    Some(Json::Number(value, ..)) => value
    _ => default
  }
}

///|
fn json_string(object : Map[String, Json], key : String, default : String) -> String {
  match object.get(key) {
    Some(Json::String(value)) => value
    _ => default
  }
}

///|
fn json_bool(object : Map[String, Json], key : String, default : Bool) -> Bool {
  match object.get(key) {
    Some(Json::True) => true
    Some(Json::False) => false
    _ => default
  }
}

///|
fn json_object(value : Json) -> Map[String, Json] raise TextPartError {
  match value {
    Json::Object(object) => object
    _ => raise TextPartError("textpart: the part is not an object")
  }
}

///|

fn range_json(range : Range) -> Json {
  let object : Map[String, Json] = {
    "col": Json::number(range.col.to_double()),
    "cols": Json::number(range.cols.to_double()),
  }
  if range.size != "" {
    object["size"] = Json::string(range.size)
  }
  Json::object(object)
}

///|
fn line_json(line : Line) -> Json {
  let object : Map[String, Json] = { "text": Json::string(line.text) }
  if !line.paper.is_empty() {
    object["paper"] = Json::array(line.paper.map(range_json))
  }
  if !line.size.is_empty() {
    object["size"] = Json::array(line.size.map(range_json))
  }
  Json::object(object)
}

///|
fn page_json(page : Page) -> Json {
  Json::object({
    "lines": Json::array(page.lines.map(line_json)),
  })
}

///|
/// The JSON of the part, in the order of the fields of the specification.
pub fn Image::encode(self : Image) -> String raise TextPartError {
  self.check()
  let object : Map[String, Json] = {
    "version": Json::number(self.version.to_double()),
    "cpi": Json::number(self.cpi),
    "lpi": Json::number(self.lpi),
    "columns": Json::number(self.columns.to_double()),
    "lines": Json::number(self.lines.to_double()),
    "margin": Json::object({
      "left": Json::number(self.margin.left.to_double()),
      "top": Json::number(self.margin.top.to_double()),
    }),
  }
  if self.skip != 0 {
    object["skip"] = Json::number(self.skip.to_double())
  }
  if self.ambiguous_wide {
    object["ambiguousWide"] = Json::boolean(true)
  }
  if self.font != "" {
    object["font"] = Json::string(self.font)
  }
  object["pages"] = Json::array(self.pages.map(page_json))
  Json::object(object).stringify()
}

///|
fn decode_range(object : Map[String, Json]) -> Range {
  {
    col: json_int(object, "col", 0),
    cols: json_int(object, "cols", 0),
    size: json_string(object, "size", ""),
  }
}

///|
fn decode_ranges(value : Json?) -> Array[Range] raise TextPartError {
  match value {
    None => []
    Some(Json::Array(values)) => {
      let out : Array[Range] = []
      for entry in values {
        out.push(decode_range(json_object(entry)))
      }
      out
    }
    _ => raise TextPartError("textpart: the ranges are not an array")
  }
}

///|
fn decode_line(object : Map[String, Json]) -> Line raise TextPartError {
  {
    text: json_string(object, "text", ""),
    paper: decode_ranges(object.get("paper")),
    size: decode_ranges(object.get("size")),
  }
}

///|
fn decode_page(object : Map[String, Json]) -> Page raise TextPartError {
  let lines : Array[Line] = []
  match object.get("lines") {
    Some(Json::Array(values)) =>
      for entry in values {
        lines.push(decode_line(json_object(entry)))
      }
    None => ()
    _ => raise TextPartError("textpart: the lines are not an array")
  }
  { lines, }
}

///|
/// Read the JSON of a part and check its numbers.
pub fn decode(text : String) -> Image raise TextPartError {
  if text.length() > MAX_SIZE {
    raise TextPartError("textpart: the part is larger than 64 MiB")
  }
  let root = @json.parse(text[:]) catch {
    _ => raise TextPartError("textpart: the part is not JSON")
  }
  let object = json_object(root)
  let margin = match object.get("margin") {
    Some(Json::Object(value)) =>
      {
        left: json_int(value, "left", 0),
        top: json_int(value, "top", 0),
      }
    _ => { left: 0, top: 0 }
  }
  let pages : Array[Page] = []
  match object.get("pages") {
    Some(Json::Array(values)) =>
      for entry in values {
        pages.push(decode_page(json_object(entry)))
      }
    None => ()
    _ => raise TextPartError("textpart: the pages are not an array")
  }
  let image : Image = {
    version: json_int(object, "version", 0),
    cpi: json_double(object, "cpi", 0.0),
    lpi: json_double(object, "lpi", 0.0),
    columns: json_int(object, "columns", 0),
    lines: json_int(object, "lines", 0),
    margin,
    skip: json_int(object, "skip", 0),
    ambiguous_wide: json_bool(object, "ambiguousWide", false),
    font: json_string(object, "font", ""),
    pages,
  }
  if image.version != VERSION {
    raise TextPartError(
      "textpart: the part is of version " +
      image.version.to_string() +
      "; this reads version " +
      VERSION.to_string(),
    )
  }
  image.check()
  image
}

///|
fn Image::check(self : Image) -> Unit raise TextPartError {
  if !(self.cpi > 0.0 && self.cpi <= 100.0) ||
    !(self.lpi > 0.0 && self.lpi <= 100.0) {
    raise TextPartError("textpart: the pitch is out of range")
  }
  if self.columns < 1 || self.columns > MAX_COLUMNS {
    raise TextPartError("textpart: the columns are out of range")
  }
  if self.lines < 0 || self.lines > MAX_LINES {
    raise TextPartError("textpart: the lines are out of range")
  }
  if self.margin.left < 0 ||
    self.margin.left >= self.columns ||
    self.margin.top < 0 ||
    self.skip < 0 {
    raise TextPartError("textpart: the margins are out of range")
  }
  if self.lines > 0 && self.margin.top + self.skip >= self.lines {
    raise TextPartError("textpart: the margins leave no line of the page")
  }
  if self.pages.length() > MAX_PAGES {
    raise TextPartError("textpart: too many pages")
  }
  for pi, page in self.pages {
    if page.lines.length() > MAX_PAGE_LINES ||
      (self.lines > 0 && page.lines.length() > self.rows(page)) {
      raise TextPartError("textpart: page " + pi.to_string() + " has too many lines")
    }
    for line in page.lines {
      for ranges in [line.paper, line.size] {
        let mut end = 0
        for range in ranges {
          if range.col < end ||
            range.cols < 1 ||
            range.cols > MAX_COLUMNS * 2 ||
            range.col > MAX_COLUMNS * 2 {
            raise TextPartError("textpart: the ranges overlap or are out of range")
          }
          end = range.col + range.cols
        }
      }
      for range in line.size {
        if range.size != SIZE_WIDE &&
          range.size != SIZE_TALL &&
          range.size != SIZE_BIG {
          raise TextPartError("textpart: the size " + range.size)
        }
      }
    }
  }
}

///|
/// Read the first part of the type "text" of a single-file BDF document.
/// Raise TextPartNone when it has none.
pub fn from_document(data : Bytes) -> Image raise TextPartError {
  let document = @core.open_single(data) catch {
    error => raise TextPartError("textpart: " + error.to_string())
  }
  for part in document.manifest.parts {
    if part.kind != "text" {
      continue
    }
    if part.size < 0 ||
      part.length < 0 ||
      part.size > MAX_SIZE ||
      part.length > MAX_SIZE {
      raise TextPartError("textpart: the part is larger than 64 MiB")
    }
    let bytes = document.part(part.hash) catch {
      error => raise TextPartError("textpart: " + error.to_string())
    }
    let text = @utf8.decode(bytes) catch {
      _ => raise TextPartError("textpart: the part is not UTF-8")
    }
    return decode(text)
  }
  raise TextPartNone
}

///|
/// Add the image to a document being written as its part of type "text".
/// Return the hash of the part.
pub fn Image::add_to(
  self : Image,
  writer : @core.DocumentWriter,
) -> String raise TextPartError {
  let text = self.encode()
  writer.add_part("text", @utf8.encode(text)) catch {
    error => raise TextPartError("textpart: " + error.to_string())
  }
}
