///|
priv struct SfcLayer {
  name : String
  visible : Bool
}

///|
priv struct SfcSfig {
  name : String
  flag : Int
  items : Array[SfcFeature]
}

///|
priv struct SfcSheet {
  typ : Int
  orient : Int
  w : Double
  h : Double
  items : Array[SfcFeature]
}

///|
priv struct SfcModel {
  colors : Map[Int, UInt32]
  types : Map[Int, Array[Double]]
  widths : Map[Int, Double]
  fonts : Array[String]
  layers : Array[SfcLayer]
  sfigs : Map[String, SfcSfig]
  mut sheet : SfcSheet?
  title : Map[String, String]
  mut bg : UInt32?
  unknown : Map[String, Int]
}

///|
fn sfc_predefined_color(code : Int) -> UInt32? {
  let colors : Array[UInt32] = [
    0x000000ffU, 0xff0000ffU, 0x00ff00ffU, 0x0000ffffU, 0xffff00ffU,
    0xff00ffffU, 0x00ffffffU, 0xffffffffU, 0xc00080ffU, 0xc08040ffU,
    0xff8000ffU, 0x80c080ffU, 0x0080ffffU, 0x8040ffffU, 0xc0c0c0ffU,
    0x808080ffU,
  ]
  if code >= 1 && code <= 16 {
    Some(colors[code - 1])
  } else {
    None
  }
}

///|
fn sfc_width(code : Int) -> Double {
  let widths : Array[Double] = [0.13, 0.18, 0.25, 0.35, 0.5, 0.7, 1.0, 1.4, 2.0]
  if code >= 1 && code <= 9 {
    widths[code - 1]
  } else {
    0.25
  }
}

///|
fn sfc_type_pattern(code : Int, width : Double) -> Array[Double] {
  let patterns : Array[Array[Double]] = [
    [],
    [6.0, 1.5],
    [6.0, 6.0],
    [12.0, 1.5, 0.25, 1.5],
    [12.0, 1.5, 0.25, 1.5, 0.25, 1.5],
    [12.0, 1.5, 0.25, 1.5, 0.25, 1.5, 0.25, 1.5],
    [0.25, 1.5],
    [12.0, 1.5, 3.5, 1.5],
    [12.0, 1.5, 3.5, 1.5, 3.5, 1.5],
    [6.0, 1.5, 0.25, 1.5],
    [6.0, 1.5, 6.0, 1.5, 0.25, 1.5],
    [6.0, 1.5, 0.25, 1.5, 0.25, 1.5],
    [6.0, 1.5, 6.0, 1.5, 0.25, 1.5, 0.25, 1.5],
    [6.0, 1.5, 0.25, 1.5, 0.25, 1.5, 0.25, 1.5],
    [6.0, 1.5, 6.0, 1.5, 0.25, 1.5, 0.25, 1.5, 0.25, 1.5],
  ]
  let output : Array[Double] = []
  if code >= 2 && code <= 15 {
    let scale = Double::max(width, 0.13) / 0.5
    for value in patterns[code - 1] {
      output.push(value * scale)
    }
  }
  output
}

///|
fn SfcModel::color(self : SfcModel, code : Int) -> UInt32? {
  match sfc_predefined_color(code) {
    Some(value) => Some(value)
    None => self.colors.get(code)
  }
}

///|
fn SfcModel::width(self : SfcModel, code : Int) -> Double {
  if code >= 1 && code <= 9 {
    sfc_width(code)
  } else {
    match self.widths.get(code) {
      Some(value) => value
      None => 0.25
    }
  }
}

///|
fn SfcModel::pattern(self : SfcModel, code : Int, width : Double) -> Array[Double] {
  let values = if code >= 2 && code <= 15 {
    sfc_type_pattern(code, width)
  } else if code >= 17 {
    match self.types.get(code) {
      Some(value) => value.copy()
      None => []
    }
  } else {
    []
  }
  if values.is_empty() {
    return values
  }
  for index in 0..<values.length() {
    values[index] = if index % 2 == 1 { -values[index].abs() } else { values[index].abs() }
  }
  values
}

///|
fn SfcModel::font(self : SfcModel, code : Int) -> String {
  if code >= 1 && code <= self.fonts.length() {
    self.fonts[code - 1]
  } else {
    ""
  }
}

///|
fn SfcModel::layer_visible(self : SfcModel, code : Int) -> Bool {
  if code >= 1 && code <= self.layers.length() {
    self.layers[code - 1].visible
  } else {
    true
  }
}

///|
fn sfc_background_attribute(name : String) -> UInt32? {
  if !name.has_prefix("$$ATRU$$") {
    return None
  }
  let parts = name.split("$$").collect()
  let mut index = 0
  while index + 2 < parts.length() {
    if parts[index] == "背景色" {
      let rgb = parts[index + 2].split("_").collect()
      if rgb.length() != 3 {
        return None
      }
      let r = @string.parse_int(rgb[0]) catch { _ => return None }
      let g = @string.parse_int(rgb[1]) catch { _ => return None }
      let b = @string.parse_int(rgb[2]) catch { _ => return None }
      return Some(((r & 255) << 24).to_uint() | ((g & 255) << 16).to_uint() | ((b & 255) << 8).to_uint() | 255U)
    }
    index += 1
  }
  None
}

///|
fn build_sfc_model(features : Array[SfcFeature]) -> SfcModel {
  let model : SfcModel = {
    colors: Map([]),
    types: Map([]),
    widths: Map([]),
    fonts: [],
    layers: [],
    sfigs: Map([]),
    sheet: None,
    title: Map([]),
    bg: None,
    unknown: Map([]),
  }
  let pending : Array[SfcFeature] = []
  for feature in features {
    match feature.name {
      "pre_defined_colour_feature" | "pre_defined_font_feature" => ()
      "user_defined_colour_feature" => {
        let red = feature.int(0)
        let green = feature.int(1)
        let blue = feature.int(2)
        model.colors[17 + model.colors.size()] =
          (((red & 255) << 24) | ((green & 255) << 16) | ((blue & 255) << 8) | 255).to_uint()
      }
      "user_defined_font_feature" => {
        model.types[17 + model.types.size()] = sfc_list(feature.args[2].text)
      }
      "width_feature" => {
        let value = feature.num(0)
        let mut predefined = false
        for candidate in [0.13, 0.18, 0.25, 0.35, 0.5, 0.7, 1.0, 1.4, 2.0] {
          if (candidate - value).abs() < 1.0e-6 {
            predefined = true
          }
        }
        if !predefined {
          model.widths[11 + model.widths.size()] = value
        }
      }
      "text_font_feature" => model.fonts.push(sfc_trim(feature.str(0)))
      "layer_feature" => model.layers.push({
        name: feature.str(0),
        visible: feature.int(1) != 0,
      })
      "drawing_attribute_feature" => {
        let keys = [
          "project", "construction", "contract", "title", "number", "type",
          "scale", "year", "month", "day", "contractor", "owner",
        ]
        for index in 0..<keys.length() {
          model.title[keys[index]] = sfc_trim(feature.str(index))
        }
      }
      "composite_curve_org_feature" => pending.clear()
      "sfig_org_feature" => {
        let name = feature.str(0)
        model.sfigs[name] = {
          name,
          flag: feature.int(1),
          items: pending.copy(),
        }
        match sfc_background_attribute(name) {
          Some(value) => model.bg = Some(value)
          None => ()
        }
        pending.clear()
      }
      "drawing_sheet_feature" => {
        model.sheet = Some({
          typ: feature.int(1),
          orient: feature.int(2),
          w: feature.num(3),
          h: feature.num(4),
          items: pending.copy(),
        })
        pending.clear()
      }
      _ => pending.push(feature)
    }
  }
  if model.sheet is None && !pending.is_empty() {
    model.sheet = Some({ typ: -1, orient: 0, w: 0.0, h: 0.0, items: pending.copy() })
  }
  model
}

///|
fn SfcModel::sheet_size(self : SfcModel) -> (Double, Double) {
  match self.sheet {
    None => (0.0, 0.0)
    Some(sheet) => {
      let a : Array[(Double, Double)] = [
        (841.0, 1189.0), (594.0, 841.0), (420.0, 594.0),
        (297.0, 420.0), (210.0, 297.0),
      ]
      if sheet.typ >= 0 && sheet.typ <= 4 {
        let (w, h) = a[sheet.typ]
        if sheet.orient == 1 { (h, w) } else { (w, h) }
      } else if sheet.w > 0.0 && sheet.h > 0.0 {
        (sheet.w, sheet.h)
      } else {
        (0.0, 0.0)
      }
    }
  }
}
