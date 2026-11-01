///|
priv struct IdmlColor {
  red : Int32
  green : Int32
  blue : Int32
  alpha : Double
}

///|
priv struct IdmlResources {
  colors : Map[String, IdmlColor]
  tints : Map[String, (String, Double)]
  gradients : Map[String, IdmlColor]
  grad_words : Map[String, Bool]
}

///|
fn idml_clamp(value : Double) -> Int32 {
  if value <= 0.0 {
    0
  } else if value >= 255.0 {
    255
  } else {
    value.round().to_int()
  }
}

///|
fn idml_cmyk(c : Double, m : Double, y : Double, k : Double) -> IdmlColor {
  let c = c * 255.0 / 100.0
  let m = m * 255.0 / 100.0
  let y = y * 255.0 / 100.0
  let k = k * 255.0 / 100.0
  let ci = idml_clamp(c).to_int64()
  let mi = idml_clamp(m).to_int64()
  let yi = idml_clamp(y).to_int64()
  let ki = idml_clamp(k).to_int64()
  let weight = 0xffffL - ki * 0x101L
  let red = ((0xffffL - ci * 0x101L) * weight / 0xffffL) >> 8
  let green = ((0xffffL - mi * 0x101L) * weight / 0xffffL) >> 8
  let blue = ((0xffffL - yi * 0x101L) * weight / 0xffffL) >> 8
  { red: red.to_int(), green: green.to_int(), blue: blue.to_int(), alpha: 1.0 }
}

///|
fn idml_lab(l : Double, a : Double, b : Double) -> IdmlColor {
  let fy = (l + 16.0) / 116.0
  let fx = fy + a / 500.0
  let fz = fy - b / 200.0
  let xyz = fn(value : Double) -> Double {
    let cube = value * value * value
    if cube > 0.008856 { cube } else { (value - 16.0 / 116.0) / 7.787 }
  }
  let x = 0.95047 * xyz(fx)
  let y = 1.00000 * xyz(fy)
  let z = 1.08883 * xyz(fz)
  let r = 3.2404542 * x - 1.5371385 * y - 0.4985314 * z
  let g = -0.9692660 * x + 1.8760108 * y + 0.0415560 * z
  let bl = 0.0556434 * x - 0.2040259 * y + 1.0572252 * z
  let gamma = fn(value : Double) -> Double {
    if value <= 0.0031308 { 12.92 * value } else { 1.055 * @math.pow(value, 1.0 / 2.4) - 0.055 }
  }
  {
    red: idml_clamp(gamma(r) * 255.0),
    green: idml_clamp(gamma(g) * 255.0),
    blue: idml_clamp(gamma(bl) * 255.0),
    alpha: 1.0,
  }
}

///|
fn idml_parse_color_node(node : IdmlXmlNode) -> IdmlColor? {
  let space = idml_attr(Some(node), "Space", "RGB")
  let values = idml_numbers(idml_attr(Some(node), "ColorValue", ""))
  if values.length() < 3 {
    return None
  }
  match space {
    "CMYK" =>
      Some(
        idml_cmyk(
          values[0],
          values[1],
          values[2],
          if values.length() > 3 { values[3] } else { 0.0 },
        ),
      )
    "LAB" => Some(idml_lab(values[0], values[1], values[2]))
    _ =>
      Some({
        red: idml_clamp(values[0]),
        green: idml_clamp(values[1]),
        blue: idml_clamp(values[2]),
        alpha: 1.0,
      })
  }
}

///|
fn idml_mix_white(color : IdmlColor, tint : Double) -> IdmlColor {
  let ratio = (tint / 100.0).max(0.0).min(1.0)
  {
    red: idml_clamp(color.red.to_double() * ratio + 255.0 * (1.0 - ratio)),
    green: idml_clamp(color.green.to_double() * ratio + 255.0 * (1.0 - ratio)),
    blue: idml_clamp(color.blue.to_double() * ratio + 255.0 * (1.0 - ratio)),
    alpha: color.alpha,
  }
}

///|
fn idml_resolve_color(
  resources : IdmlResources,
  name : String,
  depth : Int32,
) -> IdmlColor? {
  if name == "" || name == "Swatch/None" || name == "None" {
    return None
  }
  if depth > 8 {
    return None
  }
  match resources.colors.get(name) {
    Some(color) => Some(color)
    None =>
      match resources.tints.get(name) {
        Some((base, tint)) =>
          match idml_resolve_color(resources, base, depth + 1) {
            Some(color) => Some(idml_mix_white(color, tint))
            None => None
          }
        None =>
          match resources.gradients.get(name) {
            Some(color) => Some(color)
            None => None
          }
      }
  }
}

///|
fn idml_read_resources(package : @ooxml.OoxmlPackage) -> IdmlResources {
  let colors : Map[String, IdmlColor] = Map([])
  let tints : Map[String, (String, Double)] = Map([])
  let gradients : Map[String, IdmlColor] = Map([])
  let grad_words : Map[String, Bool] = Map([])
  let root = try {
    idml_read_xml(package, "Resources/Graphic.xml")
  } catch {
    _ => return { colors, tints, gradients, grad_words, }
  }
  for node in root.children {
    let self = idml_attr(Some(node), "Self", "")
    if self == "" {
      continue
    }
    match node.element.name.local_name {
      "Color" => match idml_parse_color_node(node) {
        Some(color) => colors[self] = color
        None => ()
      }
      "Tint" => {
        let base = idml_attr(Some(node), "BaseColor", "")
        let tint = idml_numbers(idml_attr(Some(node), "TintValue", "100"))
        tints[self] = (base, if tint.is_empty() { 100.0 } else { tint[0] })
      }
      "Gradient" => {
        let mut best : (Double, IdmlColor)? = None
        for stop in node.children {
          if stop.element.name.local_name != "GradientStop" {
            continue
          }
          let location = idml_numbers(idml_attr(Some(stop), "Location", "0"))
          let at = if location.is_empty() { 0.0 } else { location[0] }
          let stop_name = idml_attr(Some(stop), "StopColor", "")
          if stop_name != "" {
            // Stops may point at colours or tints that appear before them.
            match idml_resolve_color({ colors, tints, gradients, grad_words, }, stop_name, 1) {
              Some(color) =>
                if best is None || at < best.unwrap().0 {
                  best = Some((at, color))
                }
              None => ()
            }
          }
        }
        match best {
          Some((_, color)) => {
            gradients[self] = color
            grad_words[self] = true
          }
          None => ()
        }
      }
      _ => ()
    }
  }
  // Resolve tints after all colours are known.
  for name in tints.keys() {
    match tints.get(name) {
      Some((base, tint)) =>
        match idml_resolve_color({ colors, tints, gradients, grad_words, }, base, 1) {
          Some(color) => colors[name] = idml_mix_white(color, tint)
          None => ()
        }
      None => ()
    }
  }
  { colors, tints, gradients, grad_words, }
}
