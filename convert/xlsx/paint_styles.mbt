///|
/// A gradient stop and its unresolved color.
pub(all) struct XlsxGradientStop {
  position : Double
  mut color : XlsxColor
}

///|
/// A linear or path gradient.
pub(all) struct XlsxGradient {
  path : Bool
  degree : Double
  left : Double
  right : Double
  top : Double
  bottom : Double
  stops : Array[XlsxGradientStop]
}

///|
/// A pattern or gradient fill.
pub(all) struct XlsxFill {
  mut pattern : String
  mut foreground : XlsxColor
  mut background : XlsxColor
  mut gradient : XlsxGradient?
}

///|
/// A border line and its unresolved color.
pub(all) struct XlsxBorderSide {
  style : String
  mut color : XlsxColor
}

///|
/// The outer, diagonal and inner sides of a cell border.
pub(all) struct XlsxBorder {
  left : XlsxBorderSide
  right : XlsxBorderSide
  top : XlsxBorderSide
  bottom : XlsxBorderSide
  diagonal : XlsxBorderSide
  diagonal_up : Bool
  diagonal_down : Bool
  vertical : XlsxBorderSide
  horizontal : XlsxBorderSide
}

///|
fn xlsx_empty_fill() -> XlsxFill {
  {
    pattern: "",
    foreground: xlsx_default_color(),
    background: xlsx_default_color(),
    gradient: None,
  }
}

///|
fn xlsx_empty_side() -> XlsxBorderSide {
  { style: "", color: xlsx_default_color(), }
}

///|
fn xlsx_read_fill(
  reader : @xml.NamespaceReader,
  empty : Bool,
) -> XlsxFill raise {
  let fill = xlsx_empty_fill()
  if empty {
    return fill
  }
  let mut depth = 1
  let mut pattern_depth = -1
  let mut gradient_depth = -1
  let mut stop_depth = -1
  let mut gradient : XlsxGradient? = None
  let mut stop : XlsxGradientStop? = None
  let seen : Map[String, Bool] = Map([])
  while depth > 0 {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        if depth == 1 && name == "patternFill" && !seen.contains(name) {
          seen[name] = true
          let pattern = xlsx_attr(element, "patternType", "")
          fill.pattern = if pattern == "none" { "" } else { pattern }
          if event.kind is Start(_) {
            pattern_depth = depth + 1
          }
        } else if depth == 1 && name == "gradientFill" && !seen.contains(name) {
          seen[name] = true
          gradient = Some({
            path: xlsx_attr(element, "type", "linear") == "path",
            degree: xlsx_float_or(element, "degree", 0.0),
            left: xlsx_float_or(element, "left", 0.0),
            right: xlsx_float_or(element, "right", 0.0),
            top: xlsx_float_or(element, "top", 0.0),
            bottom: xlsx_float_or(element, "bottom", 0.0),
            stops: [],
          })
          if event.kind is Start(_) {
            gradient_depth = depth + 1
          }
        } else if depth == pattern_depth &&
          (name == "fgColor" || name == "bgColor") &&
          !seen.contains(name) {
          seen[name] = true
          if name == "fgColor" {
            fill.foreground = xlsx_color(element)
          } else {
            fill.background = xlsx_color(element)
          }
        } else if depth == gradient_depth && name == "stop" {
          let value : XlsxGradientStop = {
            position: xlsx_float_or(element, "position", 0.0),
            color: xlsx_default_color(),
          }
          if gradient is Some(g) {
            g.stops.push(value)
          }
          stop = Some(value)
          seen.remove("stopColor")
          if event.kind is Start(_) {
            stop_depth = depth + 1
          }
        } else if depth == stop_depth &&
          name == "color" &&
          !seen.contains("stopColor") {
          seen["stopColor"] = true
          if stop is Some(s) {
            s.color = xlsx_color(element)
          }
        }
        if event.kind is Start(_) {
          depth += 1
        }
      }
      End(_) => {
        depth -= 1
        if depth + 1 == pattern_depth {
          pattern_depth = -1
        }
        if depth + 1 == gradient_depth {
          gradient_depth = -1
        }
        if depth + 1 == stop_depth {
          stop_depth = -1
          stop = None
        }
      }
      Eof => raise InvalidXlsxInput("xlsx: unexpected EOF")
      _ => ()
    }
  }
  if gradient is Some(g) && !g.stops.is_empty() {
    fill.gradient = Some(g)
  }
  fill
}

///|
fn xlsx_read_border_side(
  reader : @xml.NamespaceReader,
  element : @xml.NamespaceElement,
  empty : Bool,
) -> XlsxBorderSide raise {
  let raw = xlsx_attr(element, "style", "")
  let side : XlsxBorderSide = {
    style: if raw == "none" {
      ""
    } else {
      raw
    },
    color: xlsx_default_color(),
  }
  if empty {
    return side
  }
  let mut depth = 1
  let mut seen = false
  while depth > 0 {
    let event = reader.read_event()
    match event.kind {
      Start(e) | Empty(e) => {
        if depth == 1 && e.name.local_name == "color" && !seen {
          side.color = xlsx_color(e)
          seen = true
        }
        if event.kind is Start(_) {
          depth += 1
        }
      }
      End(_) => depth -= 1
      Eof => raise InvalidXlsxInput("xlsx: unexpected EOF")
      _ => ()
    }
  }
  side
}

///|
fn xlsx_read_border(
  reader : @xml.NamespaceReader,
  element : @xml.NamespaceElement,
  empty : Bool,
) -> XlsxBorder raise {
  let sides : Map[String, XlsxBorderSide] = Map([])
  if !empty {
    let mut depth = 1
    while depth > 0 {
      let event = reader.read_event()
      match event.kind {
        Start(e) | Empty(e) => {
          let name = e.name.local_name
          if depth == 1 &&
            [
              "left", "right", "start", "end", "top", "bottom", "diagonal", "vertical",
              "horizontal",
            ].contains(name) {
            let side = xlsx_read_border_side(reader, e, event.kind is Empty(_))
            if !sides.contains(name) {
              sides[name] = side
            }
            continue
          }
          if event.kind is Start(_) {
            depth += 1
          }
        }
        End(_) => depth -= 1
        Eof => raise InvalidXlsxInput("xlsx: unexpected EOF")
        _ => ()
      }
    }
  }
  {
    left: sides
    .get("left")
    .unwrap_or(sides.get("start").unwrap_or(xlsx_empty_side())),
    right: sides
    .get("right")
    .unwrap_or(sides.get("end").unwrap_or(xlsx_empty_side())),
    top: sides.get("top").unwrap_or(xlsx_empty_side()),
    bottom: sides.get("bottom").unwrap_or(xlsx_empty_side()),
    diagonal: sides.get("diagonal").unwrap_or(xlsx_empty_side()),
    diagonal_up: xlsx_bool_or(element, "diagonalUp", false),
    diagonal_down: xlsx_bool_or(element, "diagonalDown", false),
    vertical: sides.get("vertical").unwrap_or(xlsx_empty_side()),
    horizontal: sides.get("horizontal").unwrap_or(xlsx_empty_side()),
  }
}

///|
fn xlsx_read_paint_styles(
  data : Bytes,
) -> (Array[XlsxFill], Array[XlsxBorder]) raise {
  let reader = @xml.NamespaceReader::from_string(
    @utf8.decode_lossy(data[:], ignore_bom=true),
  )
  let fills : Array[XlsxFill] = []
  let borders : Array[XlsxBorder] = []
  let seen : Map[String, Bool] = Map([])
  let mut depth = 0
  let mut block = ""
  let mut block_depth = -1
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(e) | Empty(e) => {
        let name = e.name.local_name
        if depth == 1 &&
          (name == "fills" || name == "borders") &&
          !seen.contains(name) {
          seen[name] = true
          if event.kind is Start(_) {
            block = name
            block_depth = depth + 1
          }
        } else if depth == block_depth && block == "fills" && name == "fill" {
          fills.push(xlsx_read_fill(reader, event.kind is Empty(_)))
          continue
        } else if depth == block_depth && block == "borders" && name == "border" {
          borders.push(xlsx_read_border(reader, e, event.kind is Empty(_)))
          continue
        }
        if event.kind is Start(_) {
          depth += 1
        } else if depth == 0 {
          break
        }
      }
      End(_) => {
        depth -= 1
        if depth + 1 == block_depth {
          block = ""
          block_depth = -1
        }
        if depth == 0 {
          break
        }
      }
      Eof =>
        if depth == 0 {
          break
        } else {
          raise InvalidXlsxInput("xlsx: unexpected EOF")
        }
      _ => ()
    }
  }
  (fills, borders)
}
