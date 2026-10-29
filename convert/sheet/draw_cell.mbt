///|
fn cell_reference(row : Int32, column : Int32, header : Bool) -> String {
  let mut value = column + 1
  let letters : Array[Char] = []
  while value > 0 {
    value -= 1
    letters.push((65 + value % 26).unsafe_to_char())
    value = value / 26
  }
  let out = StringBuilder()
  for i = letters.length() - 1; i >= 0; i = i - 1 {
    out.write_char(letters[i])
  }
  out.write_string((row + 1).to_string())
  if header {
    out.write_string(" col")
  }
  out.to_string()
}

///|
fn grid_visible_text(text : String) -> String {
  let characters : Array[Char] = []
  for character in text {
    characters.push(character)
  }
  let mut end = characters.length()
  while end > 0 && break_space(characters[end - 1]) {
    end -= 1
  }
  let out = StringBuilder()
  for i in 0..<end {
    out.write_char(characters[i])
  }
  out.to_string()
}

///|
fn grid_total_width(
  text : String,
  bold : Bool,
  advance : (Char, Bool) -> Double,
) -> Double {
  let mut width = 0.0
  for character in text {
    width += advance(character, bold)
  }
  width
}

///|
fn grid_cell_layout(
  row : Array[Cell],
  cell : Cell,
  column : Int32,
  col_positions : Array[Double],
  y : Double,
  height : Double,
  bold : Bool,
  language : String,
  advance : (Char, Bool) -> Double,
  metrics : (Char, Bool) -> (Double, Double),
) -> DrawCell {
  let x = col_positions[column]
  let width = col_positions[column + 1] - x
  let wraps = cell.text.contains("\n") || cell.text.contains("\r")
  let available = Double::max(width - 3.75, 0.0)
  let mut lines = wrap_text(
    cell.text,
    if wraps {
      available
    } else {
      1.0e300
    },
    bold~,
    advance~,
  )
  if !wraps &&
    cell.number &&
    grid_total_width(lines[0].text, bold, advance) > available + 0.01 {
    let count = (available / Double::max(advance('#', bold), 0.01)).to_int()
    lines = wrap_text("#".repeat(count), 1.0e300, bold~, advance~)
  }
  let (lang, lang_known) = grid_cell_language(lines, language)
  let line_metrics : Array[(Double, Double)] = []
  let mut total = 0.0
  for line in lines {
    let mut ascent = 0.0
    let mut descent = 0.0
    for character in line.text {
      let (a, d) = metrics(character, bold)
      ascent = Double::max(ascent, a)
      descent = Double::max(descent, d)
    }
    if ascent == 0.0 && descent == 0.0 {
      let (a, d) = metrics('x', bold)
      ascent = a
      descent = d
    }
    line_metrics.push((ascent, descent))
    total += ascent + descent
  }
  let mut top = y + height - 0.75 - total
  let out : Array[DrawLine] = []
  let mut tx0 = 1.0e300
  let mut tx1 = -1.0e300
  for i, line in lines {
    let (ascent, descent) = line_metrics[i]
    let baseline = top + ascent
    let lx = if cell.number { x + width - 2.25 - line.width } else { x + 1.5 }
    tx0 = Double::min(tx0, lx)
    tx1 = Double::max(tx1, lx + line.width)
    out.push({
      text: grid_visible_text(line.text),
      x: lx,
      baseline,
      width: line.width,
      cjk_wrap: line.cjk_wrap,
    })
    top += ascent + descent
  }
  let mut x0 = x
  let mut x1 = x + width
  if !wraps && !cell.number && (tx0 < x0 || tx1 > x1) {
    let mut next = column + 1
    while next < 16384 && x1 < tx1 {
      if next < row.length() && row[next].text != "" {
        break
      }
      x1 = col_positions[next + 1]
      next += 1
    }
  }
  let (first_ascent, _) = line_metrics[0]
  let (_, last_descent) = line_metrics[line_metrics.length() - 1]
  let ty0 = out[0].baseline - first_ascent
  let ty1 = out[out.length() - 1].baseline + last_descent
  let clip = tx0 < x0 - 0.01 ||
    tx1 > x1 + 0.01 ||
    ty0 < y - 0.01 ||
    ty1 > y + height + 0.01
  if !clip {
    x0 = Double::min(tx0, x)
    x1 = Double::max(tx1, x + width)
  }
  { x0, x1, y0: y, y1: y + height, clip, lang, lang_known, lines: out, }
}
