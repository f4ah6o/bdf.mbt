///|
/// Resolved cell styles for stencil and AWS shapes, a port of the upstream
/// converter's style.go: named styles merge, "key=none" removes a key, a
/// leading ";" drops the default style, and "default" colors become the
/// light theme's white/black.

///|
/// The default vertex style (mxStylesheet defaults).
fn drawio_default_vertex_style() -> Map[String, String] {
  {
    "shape": "label",
    "perimeter": "rectanglePerimeter",
    "fontSize": "12",
    "fontFamily": "Helvetica",
    "align": "center",
    "verticalAlign": "middle",
    "fillColor": "default",
    "strokeColor": "default",
    "fontColor": "default",
  }
}

///|
/// The default edge style.
fn drawio_default_edge_style() -> Map[String, String] {
  {
    "shape": "connector",
    "labelBackgroundColor": "default",
    "endArrow": "classic",
    "fontSize": "11",
    "fontFamily": "Helvetica",
    "align": "center",
    "verticalAlign": "middle",
    "rounded": "1",
    "strokeColor": "default",
    "fontColor": "default",
  }
}

///|
/// The named styles of draw.io's default stylesheet.
fn drawio_named_styles(name : String) -> Map[String, String]? {
  let text : Map[String, String] = {
    "fillColor": "none",
    "gradientColor": "none",
    "strokeColor": "none",
    "align": "left",
    "verticalAlign": "top",
  }
  let fancy : Map[String, String] = {
    "shadow": "1",
    "glass": "1",
  }
  match name {
    "text" => Some(text)
    "edgeLabel" => {
      let s = drawio_style_clone(text)
      s["labelBackgroundColor"] = "default"
      s["fontSize"] = "11"
      Some(s)
    }
    "label" =>
      Some({
        "fontStyle": "1",
        "align": "left",
        "verticalAlign": "middle",
        "spacing": "2",
        "spacingLeft": "52",
        "imageWidth": "42",
        "imageHeight": "42",
        "rounded": "1",
      })
    "icon" => {
      let s = drawio_style_clone(text)
      for (k, v) in {
        "fontStyle": "1",
        "align": "center",
        "imageAlign": "center",
        "verticalLabelPosition": "bottom",
        "verticalAlign": "top",
        "labelBackgroundColor": "default",
        "spacing": "0",
        "spacingLeft": "0",
        "spacingTop": "6",
        "imageWidth": "48",
        "imageHeight": "48",
      } {
        s[k] = v
      }
      Some(s)
    }
    "swimlane" => Some({ "shape": "swimlane", "fontSize": "12", "fontStyle": "1", "startSize": "23" })
    "group" =>
      Some({
        "verticalAlign": "top",
        "fillColor": "none",
        "strokeColor": "none",
        "gradientColor": "none",
        "pointerEvents": "0",
      })
    "ellipse" => Some({ "shape": "ellipse", "perimeter": "ellipsePerimeter" })
    "rhombus" => Some({ "shape": "rhombus", "perimeter": "rhombusPerimeter" })
    "triangle" => Some({ "shape": "triangle", "perimeter": "trianglePerimeter" })
    "line" =>
      Some({
        "shape": "line",
        "strokeWidth": "4",
        "labelBackgroundColor": "default",
        "verticalAlign": "top",
        "spacingTop": "8",
      })
    "image" =>
      Some({
        "shape": "image",
        "labelBackgroundColor": "default",
        "verticalAlign": "top",
        "verticalLabelPosition": "bottom",
      })
    "roundImage" => {
      let s = drawio_style_clone(fancy)
      s["shape"] = "image"
      s["labelBackgroundColor"] = "default"
      s["verticalAlign"] = "top"
      s["verticalLabelPosition"] = "bottom"
      s["perimeter"] = "ellipsePerimeter"
      Some(s)
    }
    "rhombusImage" => {
      let s = drawio_style_clone(fancy)
      s["shape"] = "image"
      s["labelBackgroundColor"] = "default"
      s["verticalAlign"] = "top"
      s["verticalLabelPosition"] = "bottom"
      s["perimeter"] = "rhombusPerimeter"
      Some(s)
    }
    "arrow" => Some({ "shape": "arrow", "edgeStyle": "none", "fillColor": "default" })
    "fancy" => Some(fancy)
    _ => {
      // The colored families: gray/blue/... and plain-<name>.
      let colors : Map[String, (String, String, String)] = {
        "gray": ("#B3B3B3", "#F5F5F5", "#666666"),
        "blue": ("#7EA6E0", "#DAE8FC", "#6C8EBF"),
        "green": ("#97D077", "#D5E8D4", "#82B366"),
        "turquoise": ("#67AB9F", "#D5E8D4", "#6A9153"),
        "yellow": ("#FFD966", "#FFF2CC", "#D6B656"),
        "orange": ("#FFA500", "#FFCD28", "#D79B00"),
        "red": ("#EA6B66", "#F8CECC", "#B85450"),
        "pink": ("#B5739D", "#E6D0DE", "#996185"),
        "purple": ("#8C6C9C", "#E1D5E7", "#9673A6"),
      }
      let mut key = name
      let mut plain = false
      if key.has_prefix("plain-") {
        plain = true
        key = key[6:].to_owned()
      }
      match colors.get(key) {
        Some((grad, fill, stroke)) => {
          let s = if plain {
            Map([])
          } else {
            drawio_style_clone(fancy)
          }
          s["gradientColor"] = grad
          s["fillColor"] = fill
          s["strokeColor"] = stroke
          Some(s)
        }
        None => None
      }
    }
  }
}

///|
fn drawio_style_clone(m : Map[String, String]) -> Map[String, String] {
  let out : Map[String, String] = Map([])
  for k, v in m {
    out[k] = v
  }
  out
}

///|
/// Resolve "default" colors to the light theme's shape colors
/// (Graph.replaceDefaultColors).
fn drawio_replace_default_colors(s : Map[String, String]) -> Unit {
  let keys : Array[(String, Bool)] = [
    ("fontColor", false),
    ("fillColor", true),
    ("gradientColor", false),
    ("strokeColor", false),
    ("imageBorder", false),
    ("imageBackground", true),
    ("labelBorderColor", false),
    ("swimlaneFillColor", true),
    ("labelBackgroundColor", true),
  ]
  for (key, is_bg) in keys {
    if s.get(key) != Some("default") {
      continue
    }
    let mut bg = is_bg
    let cap = if key.length() > 0 {
      (key[:1].to_upper() + key[1:]).to_owned()
    } else {
      key
    }
    if s.get("default" + cap) == Some("invert") {
      bg = !bg
    }
    s[key] = if bg { "#ffffff" } else { "#000000" }
  }
}

///|
/// Parse and resolve a cell style string (mxStylesheet.getCellStyle).
fn drawio_parse_style(style_str : String, edge~ : Bool) -> Map[String, String] {
  let s = if style_str == "" || style_str[0] != ';' {
    if edge { drawio_default_edge_style() } else { drawio_default_vertex_style() }
  } else {
    Map([])
  }
  for tok in style_str.split(";") {
    if tok == "" {
      continue
    }
    let eq = tok.find("=")
    match eq {
      Some(i) => {
        let key = tok[:i].to_owned()
        let value = tok[i + 1:].to_owned()
        if value == "none" {
          s.remove(key)
        } else {
          s[key] = value
        }
      }
      None => match drawio_named_styles(tok.to_string()) {
        Some(named) => for k, v in named { s[k] = v }
        None => ()
      }
    }
  }
  drawio_replace_default_colors(s)
  s
}

///|
/// Style lookup with a default, on the resolved style.
fn drawio_rstyle_get(s : Map[String, String], key : String, default : String) -> String {
  match s.get(key) {
    Some(v) => v
    None => default
  }
}

///|
/// Numeric style value (parseFloat semantics: a leading number is enough).
fn drawio_rstyle_num(s : Map[String, String], key : String, default : Double) -> Double {
  match s.get(key) {
    Some(v) =>
      match drawio_leading_float(v) {
        Some(f) => f
        None => default
      }
    None => default
  }
}

///|
/// Flag style value: "1"/"true"/nonzero number.
fn drawio_rstyle_flag(s : Map[String, String], key : String, default~ : Bool) -> Bool {
  match s.get(key) {
    Some(v) => {
      let t = sfc_drawio_trim(v)
      if t == "true" {
        true
      } else {
        match drawio_leading_float(v) {
          Some(f) => f != 0.0
          None => default
        }
      }
    }
    None => default
  }
}

///|
/// JavaScript parseFloat: the leading number of s, or None.
fn drawio_leading_float(s : String) -> Double? {
  let t = sfc_drawio_trim(s)
  let bytes = t.to_array()
  let mut end = 0
  let mut seen_digit = false
  let mut seen_dot = false
  let mut seen_exp = false
  while end < bytes.length() {
    let c = bytes[end]
    if c >= '0' && c <= '9' {
      seen_digit = true
    } else if (c == '+' || c == '-') &&
      (end == 0 || bytes[end - 1] == 'e' || bytes[end - 1] == 'E') {
    } else if c == '.' && !seen_dot && !seen_exp {
      seen_dot = true
    } else if (c == 'e' || c == 'E') && seen_digit && !seen_exp {
      seen_exp = true
    } else {
      break
    }
    end += 1
  }
  while end > 0 {
    match (try Ok(@string.parse_double(t[:end].to_owned())) catch { e => Err(e) }) {
      Ok(f) => return Some(f)
      Err(_) => end -= 1
    }
  }
  None
}
