///|
/// A wrapped line. Trailing spaces are retained in text but excluded from
/// width, as the BDF text painter does.
pub(all) struct WrappedLine {
  text : String
  width : Double
  explicit : Bool
  wrapped : Bool
  cjk_wrap : Bool
} derive(Debug)

///|
priv struct WrapItem {
  character : Char
  width : Double
  is_break : Bool
}

///|
/// Lay out a cell's text into lines using Office-compatible break rules.
/// Width and character advances are in points. A CR or CRLF is normalized
/// to a line break, as for a grid cell in the upstream sheet converter.
pub fn wrap_text(
  text : String,
  width : Double,
  bold~ : Bool = false,
  advance~ : (Char, Bool) -> Double = fallback_advance,
) -> Array[WrappedLine] {
  let items : Array[WrapItem] = []
  let mut skip_lf = false
  let mut shown = 0
  for character in text {
    if skip_lf && character == '\n' {
      skip_lf = false
      continue
    }
    skip_lf = false
    if character == '\r' || character == '\n' {
      if character == '\r' {
        skip_lf = true
      }
      items.push({ character: '\n', width: 0.0, is_break: true, })
      shown += 1
    } else {
      let character = if character == '\t' { ' ' } else { character }
      if character.to_int() < 0x20 {
        continue
      }
      items.push({
        character,
        width: advance(character, bold),
        is_break: false,
      })
      shown += 1
    }
    if shown >= 1024 {
      break
    }
  }
  let available = Double::max(width, 0.0)
  let lines : Array[WrappedLine] = []
  let mut start = 0
  let mut explicit = false
  let mut wrapped = false
  let mut cjk_wrap = false
  while start < items.length() || lines.length() == 0 {
    let mut x = 0.0
    let mut end = items.length()
    let mut last_break = -1
    let mut broke_at = -1
    for i in start..<items.length() {
      let item = items[i]
      if item.is_break {
        end = i
        broke_at = i
        break
      }
      if x + item.width > available + 0.000001 &&
        i > start &&
        !break_space(item.character) {
        end = if last_break >= 0 { last_break + 1 } else { i }
        break
      }
      x += item.width
      if i + 1 >= items.length() ||
        items[i + 1].is_break ||
        line_break_allowed(item.character, items[i + 1].character) {
        last_break = i
      }
    }
    let result = StringBuilder()
    let mut line_width = 0.0
    let mut visible_width = 0.0
    for i in start..<end {
      result.write_char(items[i].character)
      line_width += items[i].width
      if !break_space(items[i].character) {
        visible_width = line_width
      }
    }
    lines.push({
      text: result.to_string(),
      width: visible_width,
      explicit,
      wrapped,
      cjk_wrap,
    })
    if broke_at >= 0 {
      start = broke_at + 1
      explicit = true
      wrapped = false
      cjk_wrap = false
      if start == items.length() {
        lines.push({
          text: "",
          width: 0.0,
          explicit: true,
          wrapped: false,
          cjk_wrap: false,
        })
        break
      }
      continue
    }
    if end >= items.length() {
      break
    }
    cjk_wrap = line_break_joins(items[end - 1].character, items[end].character)
    explicit = false
    wrapped = true
    start = end
    while start < items.length() &&
          !items[start].is_break &&
          break_space(items[start].character) {
      start += 1
    }
    if start == items.length() {
      break
    }
  }
  lines
}

///|
/// A text fragment and its resolved fallback font size for rich wrapping.
pub(all) struct RichMeasureRun {
  text : String
  size : Double
  vertical : String
}

///|
/// A wrapped rich text line and the largest size on that line.
pub(all) struct RichWrappedLine {
  text : String
  width : Double
  explicit : Bool
  wrapped : Bool
  cjk_wrap : Bool
  size : Double
}

///|
priv struct RichWrapItem {
  character : Char
  width : Double
  size : Double
  is_break : Bool
}

///|
/// Wrap styled fallback text with per-run font sizes.
pub fn wrap_rich_text(
  runs : Array[RichMeasureRun],
  width : Double,
  base_size : Double,
) -> Array[RichWrappedLine] {
  let items : Array[RichWrapItem] = []
  let mut shown = 0
  for run in runs {
    if shown >= 1024 {
      break
    }
    for character in run.text {
      if character == '\n' {
        items.push({ character, width: 0.0, size: run.size, is_break: true, })
      } else {
        let character = if character == '\t' { ' ' } else { character }
        if character.to_int() < 0x20 {
          continue
        }
        items.push({
          character,
          width: sized_fallback_advance(
            character,
            false,
            if run.vertical != "" {
              run.size * (2.0 / 3.0)
            } else {
              run.size
            },
          ),
          size: run.size,
          is_break: false,
        })
      }
      shown += 1
      if shown >= 1024 {
        break
      }
    }
  }
  let available = Double::max(width, 0.0)
  let lines : Array[RichWrappedLine] = []
  let mut start = 0
  let mut explicit = false
  let mut wrapped = false
  let mut cjk_wrap = false
  while start < items.length() || lines.length() == 0 {
    let mut x = 0.0
    let mut end = items.length()
    let mut last_break = -1
    let mut broke_at = -1
    for i in start..<items.length() {
      let item = items[i]
      if item.is_break {
        end = i
        broke_at = i
        break
      }
      if x + item.width > available + 0.000001 &&
        i > start &&
        !break_space(item.character) {
        end = if last_break >= 0 { last_break + 1 } else { i }
        break
      }
      x += item.width
      if i + 1 >= items.length() ||
        items[i + 1].is_break ||
        line_break_allowed(item.character, items[i + 1].character) {
        last_break = i
      }
    }
    let result = StringBuilder()
    let mut line_width = 0.0
    let mut visible_width = 0.0
    let mut max_size = 0.0
    for i in start..<end {
      result.write_char(items[i].character)
      line_width += items[i].width
      max_size = Double::max(max_size, items[i].size)
      if !break_space(items[i].character) {
        visible_width = line_width
      }
    }
    lines.push({
      text: result.to_string(),
      width: visible_width,
      explicit,
      wrapped,
      cjk_wrap,
      size: if max_size > 0.0 {
        max_size
      } else {
        base_size
      },
    })
    if broke_at >= 0 {
      start = broke_at + 1
      explicit = true
      wrapped = false
      cjk_wrap = false
      if start == items.length() {
        lines.push({
          text: "",
          width: 0.0,
          explicit: true,
          wrapped: false,
          cjk_wrap: false,
          size: base_size,
        })
        break
      }
      continue
    }
    if end >= items.length() {
      break
    }
    explicit = false
    cjk_wrap = line_break_joins(items[end - 1].character, items[end].character)
    wrapped = true
    start = end
    while start < items.length() &&
          !items[start].is_break &&
          break_space(items[start].character) {
      start += 1
    }
    if start == items.length() {
      break
    }
  }
  lines
}
