///|
/// A DrawingML text layout failure.
pub suberror DrawingmlError {
  DrawingmlInvalid(String)
}

///|
pub(all) struct TextStyle {
  family : String
  size : Double
  bold : Bool
  italic : Bool
  color : UInt32
}

///|
pub fn TextStyle::new(
  family~ : String = "Arial",
  size~ : Double = 12.0,
  bold~ : Bool = false,
  italic~ : Bool = false,
  color~ : UInt32 = 0x000000ffU,
) -> TextStyle {
  { family, size, bold, italic, color }
}

///|
pub(all) struct TextRun {
  text : String
  style : TextStyle
}

///|
pub(all) struct TextParagraph {
  runs : Array[TextRun]
  align : Int32
}

///|
pub(all) struct TextBody {
  paragraphs : Array[TextParagraph]
}

///|
pub(all) struct TextRect {
  x : Double
  y : Double
  width : Double
  height : Double
}

///|
pub(all) struct TextLine {
  text : String
  x : Double
  y : Double
  width : Double
  style : TextStyle
  align : Int32
}

///|
/// A conservative advance estimate: CJK and full-width characters take one
/// em, Latin characters half an em. DrawingML font metrics are not loaded.
pub fn text_width(text : String, size : Double) -> Double {
  let mut width = 0.0
  for ch in text {
    let code = ch.to_int()
    width += if code > 0x2e80 || ch == '\u3000' { size } else { size * 0.5 }
  }
  width
}

///|
/// Split a run sequence into lines of at most `width` points. The first run
/// style represents the line; style changes within a line are flattened.
pub fn wrap_runs(runs : Array[TextRun], width : Double, align : Int32) -> Array[TextLine] {
  let lines : Array[TextLine] = []
  let current = StringBuilder()
  let mut current_width = 0.0
  let mut style = if runs.is_empty() { TextStyle::new() } else { runs[0].style }
  let flush = fn() -> Unit {
    if current.to_string() != "" {
      lines.push({
        text: current.to_string(),
        x: 0.0,
        y: 0.0,
        width: current_width,
        style,
        align,
      })
      current.reset()
      current_width = 0.0
    }
  }
  for run in runs {
    style = run.style
    for paragraph in run.text.split("\n") {
      if paragraph != "" {
        for ch in paragraph {
          let advance = text_width(ch.to_string(), style.size)
          if current_width + advance > width && current.to_string() != "" {
            flush()
          }
          current.write_char(ch)
          current_width += advance
        }
      }
      flush()
    }
  }
  flush()
  lines
}

///|
/// Lay out a text body in one rectangle. Returns the visible lines and
/// whether some text did not fit.
pub fn layout(body : TextBody, rect : TextRect) -> (Array[TextLine], Bool) {
  let lines : Array[TextLine] = []
  let mut y = rect.y
  let mut overflow = false
  for paragraph in body.paragraphs {
    let wrapped = wrap_runs(paragraph.runs, rect.width, paragraph.align)
    for line in wrapped {
      let line_height = line.style.size * 1.25
      if y + line_height > rect.y + rect.height {
        overflow = true
        break
      }
      let line_width = text_width(line.text, line.style.size)
      let x = match line.align {
        1 => rect.x + (rect.width - line_width) / 2.0
        2 => rect.x + rect.width - line_width
        _ => rect.x
      }
      lines.push({
        text: line.text,
        x,
        y: y + line.style.size,
        width: line_width,
        style: line.style,
        align: line.align,
      })
      y += line_height
    }
    if overflow {
      break
    }
  }
  (lines, overflow)
}

///|
/// Flow a text body through frames in order. Text that does not fit the last
/// frame is reported as overflow.
pub fn flow(
  body : TextBody,
  frames : Array[TextRect],
) -> (Array[Array[TextLine]], Bool) {
  let result : Array[Array[TextLine]] = []
  for _ in frames {
    result.push([])
  }
  let mut paragraph_index = 0
  let mut run_index = 0
  let mut offset = 0
  let mut overflow = false
  for frame_index, frame in frames {
    let lines : Array[TextLine] = []
    let mut y = frame.y
    while paragraph_index < body.paragraphs.length() && y < frame.y + frame.height {
      let paragraph = body.paragraphs[paragraph_index]
      let remaining : Array[TextRun] = []
      for i in run_index..<paragraph.runs.length() {
        let run = paragraph.runs[i]
        let chars = run.text.to_array()
        let start = if i == run_index { offset.min(chars.length()) } else { 0 }
        if start < chars.length() {
          remaining.push({
            text: String::from_array(chars[start:]),
            style: run.style,
          })
        }
      }
      let wrapped = wrap_runs(remaining, frame.width, paragraph.align)
      let mut consumed_all = true
      for line in wrapped {
        let line_height = line.style.size * 1.25
        if y + line_height > frame.y + frame.height {
          consumed_all = false
          break
        }
        let line_width = text_width(line.text, line.style.size)
        let x = match line.align {
          1 => frame.x + (frame.width - line_width) / 2.0
          2 => frame.x + frame.width - line_width
          _ => frame.x
        }
        lines.push({
          text: line.text,
          x,
          y: y + line.style.size,
          width: line_width,
          style: line.style,
          align: line.align,
        })
        y += line_height
      }
      if consumed_all {
        paragraph_index += 1
        run_index = 0
        offset = 0
      } else {
        // Advance by the characters that fit. This is an approximation: the
        // next frame re-wraps the remainder at its own width.
        let mut visible = 0
        for line in lines {
          visible += line.text.to_array().length()
        }
        let total = {
          let mut count = 0
          for run in paragraph.runs {
            count += run.text.to_array().length()
          }
          count
        }
        if visible == 0 {
          overflow = true
          break
        }
        let next = (offset + visible).min(total)
        if next >= total {
          paragraph_index += 1
          run_index = 0
          offset = 0
        } else {
          offset = next
          // Locate the run that holds the offset.
          let mut remaining_offset = offset
          run_index = 0
          while run_index < paragraph.runs.length() {
            let length = paragraph.runs[run_index].text.to_array().length()
            if remaining_offset < length {
              offset = remaining_offset
              break
            }
            remaining_offset -= length
            run_index += 1
          }
        }
        break
      }
    }
    result[frame_index] = lines
    if paragraph_index >= body.paragraphs.length() {
      return (result, false)
    }
  }
  overflow = overflow || paragraph_index < body.paragraphs.length()
  (result, overflow)
}
