///|
// Read embedded pictures and solid-color rectangles. Other drawing
// features remain unsupported until their rendering and relationship semantics exist.
fn XlsxWorkbook::xlsx_simple_picture(
  self : XlsxWorkbook,
  part : String,
  theme_colors : Map[Int32, XlsxRgb],
) -> Array[
  (
    @sheet.GridPicture,
    Bool,
    UInt32?,
    (UInt32, Double)?,
    Bool,
    String,
    String,
    Int64?,
  ),
]? {
  let bytes = self.package.read(part) catch { _ => return None }
  let source = @utf8.decode_lossy(bytes[:], ignore_bom=true)
  if source.contains("<!ENTITY") {
    return None
  }
  for rel in self.package.relationships(part) {
    if rel.kind.has_suffix("/chart") {
      return None
    }
  }
  let reader = @xml.NamespaceReader::from_string(source)
  let parents = Array::make(20, "")
  let mut depth = 0
  let mut kind = -1
  let mut anchors = 0
  let result : Array[
    (
      @sheet.GridPicture,
      Bool,
      UInt32?,
      (UInt32, Double)?,
      Bool,
      String,
      String,
      Int64?,
    ),
  ] = []
  let images : Map[String, Bytes] = Map([])
  let mut image_bytes = 0L
  let mut pictures = 0
  let mut saw_from = false
  let mut saw_to = false
  let mut saw_nv = false
  let mut saw_nvpr = false
  let mut picture_hidden = false
  let mut is_shape = false
  let mut shape_fill : UInt32? = None
  let mut shape_no_fill = false
  let mut saw_shape_fill = false
  let mut saw_line = false
  let mut saw_no_line = false
  let mut saw_line_fill = false
  let mut line_color : UInt32? = None
  let mut theme_alpha_checked = false
  let mut theme_alphas : Map[Int32, Double]? = None
  let mut shape_alpha = 1.0
  let mut line_alpha = 1.0
  let mut shape_invertible = false
  let mut line_invertible = false
  let mut line_width = 0.75
  let mut shape_dash = ""
  let mut saw_dash = false
  let mut saw_blip_fill = false
  let mut saw_sppr = false
  let mut geometry = false
  let mut shape_geometry = ""
  let mut shape_adjustment : Int64? = None
  let mut saw_adjustments = false
  let mut stretch = false
  let mut from_row = -1
  let mut from_column = -1
  let mut to_row = -1
  let mut to_column = -1
  let mut from_x_offset = 0.0
  let mut from_y_offset = 0.0
  let mut to_x_offset = 0.0
  let mut to_y_offset = 0.0
  let mut seen_from_x_offset = false
  let mut seen_from_y_offset = false
  let mut seen_to_x_offset = false
  let mut seen_to_y_offset = false
  let mut x = -1.0
  let mut y = -1.0
  let mut saw_position = false
  let mut width = -1.0
  let mut height = -1.0
  let mut image_id = ""
  let mut alpha : Float? = None
  let mut fill_left = 0.0
  let mut fill_top = 0.0
  let mut fill_right = 0.0
  let mut fill_bottom = 0.0
  let mut saw_fill_rect = false
  let mut crop_left = 0.0
  let mut crop_top = 0.0
  let mut crop_right = 0.0
  let mut crop_bottom = 0.0
  let mut saw_crop = false
  let mut saw_xfrm = false
  let mut saw_xfrm_off = false
  let mut saw_xfrm_ext = false
  let mut frame_width = 0.0
  let mut frame_height = 0.0
  let mut flip_horizontal = false
  let mut flip_vertical = false
  let mut rotation = 0
  let mut description = ""
  let mut title = ""
  let mut text = StringBuilder()
  while true {
    let event = reader.read_event() catch { _ => return None }
    match event.kind {
      Start(element) | Empty(element) => {
        if depth >= parents.length() {
          return None
        }
        let name = element.name.local_name
        let parent = if depth == 0 { "" } else { parents[depth - 1] }
        let good = if depth == 0 {
          name == "wsDr"
        } else if depth == 1 && parent == "wsDr" {
          if name == "twoCellAnchor" {
            kind = 0
          } else if name == "oneCellAnchor" {
            kind = 1
          } else if name == "absoluteAnchor" {
            kind = 2
          } else {
            return None
          }
          anchors += 1
          anchors <= 128 && event.kind is Start(_)
        } else if depth == 2 &&
          (
            parent == "twoCellAnchor" ||
            parent == "oneCellAnchor" ||
            parent == "absoluteAnchor"
          ) {
          if name == "pic" || name == "sp" {
            is_shape = name == "sp"
            pictures += 1
            pictures == 1
          } else if name == "from" {
            if saw_from {
              return None
            }
            saw_from = true
            kind == 0 || kind == 1
          } else if name == "to" {
            if saw_to {
              return None
            }
            saw_to = true
            kind == 0
          } else if name == "pos" && kind == 2 {
            if saw_position {
              return None
            }
            saw_position = true
            let px = xlsx_int(xlsx_attr(element, "x", ""))
            let py = xlsx_int(xlsx_attr(element, "y", ""))
            match (px, py) {
              (Some(a), Some(b)) if a >= -254000000L &&
                b >= -254000000L &&
                a <= 254000000L &&
                b <= 254000000L => {
                x = a.to_double() / 12700.0
                y = b.to_double() / 12700.0
                true
              }
              _ => false
            }
          } else if name == "ext" && (kind == 1 || kind == 2) {
            if width >= 0.0 || height >= 0.0 {
              return None
            }
            let cx = xlsx_int(xlsx_attr(element, "cx", ""))
            let cy = xlsx_int(xlsx_attr(element, "cy", ""))
            match (cx, cy) {
              (Some(a), Some(b)) if a >= 0L &&
                b >= 0L &&
                a <= 254000000L &&
                b <= 254000000L => {
                width = a.to_double() / 12700.0
                height = b.to_double() / 12700.0
                true
              }
              _ => false
            }
          } else {
            name == "clientData"
          }
        } else if depth == 3 && (parent == "from" || parent == "to") {
          ["col", "colOff", "row", "rowOff"].contains(name)
        } else if depth == 3 && (parent == "pic" || parent == "sp") {
          if (name == "nvPicPr" && !is_shape) || (name == "nvSpPr" && is_shape) {
            if saw_nv {
              return None
            }
            saw_nv = true
            true
          } else if name == "blipFill" && !is_shape {
            if saw_blip_fill {
              return None
            }
            saw_blip_fill = true
            true
          } else if name == "spPr" {
            if saw_sppr {
              return None
            }
            saw_sppr = true
            true
          } else {
            false
          }
        } else if depth == 4 && (parent == "nvPicPr" || parent == "nvSpPr") {
          if name == "cNvPr" {
            if saw_nvpr {
              return None
            }
            saw_nvpr = true
            let hidden = xlsx_trim(xlsx_attr(element, "hidden", ""))
            if !["", "0", "false", "off", "1", "true", "on"].contains(hidden) {
              return None
            }
            picture_hidden = ["1", "true", "on"].contains(hidden)
            description = xlsx_trim(xlsx_attr(element, "descr", ""))
            title = xlsx_trim(xlsx_attr(element, "title", ""))
            true
          } else {
            (name == "cNvPicPr" && !is_shape) || (name == "cNvSpPr" && is_shape)
          }
        } else if depth == 4 && parent == "blipFill" {
          if name == "blip" {
            if image_id != "" {
              return None
            }
            image_id = xlsx_rel_id(element, "embed")
            image_id != "" && xlsx_rel_id(element, "link") == ""
          } else if name == "srcRect" {
            if saw_crop {
              return None
            }
            saw_crop = true
            let seen : Map[String, Bool] = Map([])
            for attr in element.attributes {
              let key = attr.name.local_name
              if !["l", "t", "r", "b"].contains(key) ||
                seen.contains(key) ||
                attr.name.namespace_uri is Some(_) {
                return None
              }
              seen[key] = true
              let value = match xlsx_int(attr.value) {
                Some(value) if value >= -100000L && value < 100000L =>
                  value.to_double() / 100000.0
                _ => return None
              }
              if key == "l" {
                crop_left = value
              }
              if key == "t" {
                crop_top = value
              }
              if key == "r" {
                crop_right = value
              }
              if key == "b" {
                crop_bottom = value
              }
            }
            crop_left + crop_right < 1.0 && crop_top + crop_bottom < 1.0
          } else if name == "stretch" {
            if stretch {
              return None
            }
            stretch = true
            true
          } else {
            false
          }
        } else if depth == 5 && parent == "blip" && name == "alphaModFix" {
          if alpha is Some(_) {
            return None
          }
          let value = match xlsx_int(xlsx_attr(element, "amt", "100000")) {
            Some(value) if value >= 0L && value <= 100000L => value
            _ => return None
          }
          alpha = Some(Float::from_double(value.to_double() / 100000.0))
          true
        } else if depth == 5 && parent == "stretch" {
          if name != "fillRect" || saw_fill_rect {
            return None
          }
          saw_fill_rect = true
          let seen : Map[String, Bool] = Map([])
          for attr in element.attributes {
            let key = attr.name.local_name
            if !["l", "t", "r", "b"].contains(key) ||
              seen.contains(key) ||
              attr.name.namespace_uri is Some(_) {
              return None
            }
            seen[key] = true
            let value = match xlsx_int(attr.value) {
              Some(value) if value >= 0L && value <= 100000L =>
                value.to_double() / 100000.0
              _ => return None
            }
            if key == "l" {
              fill_left = value
            }
            if key == "t" {
              fill_top = value
            }
            if key == "r" {
              fill_right = value
            }
            if key == "b" {
              fill_bottom = value
            }
          }
          fill_left + fill_right <= 1.0 && fill_top + fill_bottom <= 1.0
        } else if depth == 4 && parent == "spPr" {
          if name == "xfrm" {
            if saw_xfrm {
              return None
            }
            saw_xfrm = true
            let seen : Map[String, Bool] = Map([])
            for attr in element.attributes {
              let key = attr.name.local_name
              if !["flipH", "flipV", "rot"].contains(key) ||
                seen.contains(key) ||
                attr.name.namespace_uri is Some(_) {
                return None
              }
              seen[key] = true
              if key == "rot" {
                let value = match xlsx_int(attr.value) {
                  Some(value) if value >= -86400000L && value <= 86400000L =>
                    value
                  _ => return None
                }
                rotation = value.to_int()
                continue
              }
              let flag = if attr.value == "1" || attr.value == "true" {
                true
              } else if attr.value == "0" || attr.value == "false" {
                false
              } else {
                return None
              }
              if key == "flipH" {
                flip_horizontal = flag
              } else {
                flip_vertical = flag
              }
            }
            true
          } else if is_shape && name == "solidFill" {
            if saw_shape_fill {
              return None
            }
            saw_shape_fill = true
            true
          } else if is_shape && name == "noFill" {
            if saw_shape_fill ||
              !(event.kind is Empty(_)) ||
              !element.attributes.is_empty() {
              return None
            }
            saw_shape_fill = true
            shape_no_fill = true
            true
          } else if is_shape && name == "ln" {
            if saw_line {
              return None
            }
            saw_line = true
            let mut seen_width = false
            for attr in element.attributes {
              if seen_width ||
                attr.name.local_name != "w" ||
                attr.name.namespace_uri is Some(_) {
                return None
              }
              seen_width = true
              let value = match xlsx_int(attr.value) {
                Some(value) if value >= 0L && value <= 254000000L => value
                _ => return None
              }
              line_width = if value == 0L {
                0.5
              } else {
                value.to_double() / 12700.0
              }
            }
            true
          } else if name == "prstGeom" &&
            [
              "rect", "ellipse", "diamond", "triangle", "rtTriangle", "parallelogram",
              "trapezoid", "homePlate", "chevron", "plus",
            ].contains(xlsx_attr(element, "prst", "")) {
            if geometry {
              return None
            }
            geometry = true
            shape_geometry = if is_shape {
              xlsx_attr(element, "prst", "")
            } else {
              "rect"
            }
            if !is_shape && xlsx_attr(element, "prst", "") != "rect" {
              return None
            }
            true
          } else {
            false
          }
        } else if depth == 5 && parent == "solidFill" && is_shape {
          if ![
              "srgbClr", "schemeClr", "sysClr", "prstClr", "scrgbClr", "hslClr",
            ].contains(name) ||
            shape_fill is Some(_) {
            return None
          }
          if name == "schemeClr" && !theme_alpha_checked {
            theme_alphas = self.xlsx_shape_theme_alphas()
            theme_alpha_checked = true
          }
          if name == "schemeClr" && theme_alphas is None {
            return None
          }
          shape_fill = xlsx_simple_shape_color(
            element,
            theme_colors,
            theme_alphas.unwrap_or(Map([])),
          )
          shape_invertible = !["scrgbClr", "hslClr"].contains(name)
          shape_alpha = xlsx_shape_initial_alpha(
            element,
            theme_alphas.unwrap_or(Map([])),
          )
          shape_fill is Some(_)
        } else if depth == 5 && parent == "ln" && is_shape {
          if name == "prstDash" {
            if saw_dash ||
              !(event.kind is Empty(_)) ||
              element.attributes.length() > 1 {
              return None
            }
            saw_dash = true
            let dash_name = xlsx_attr(element, "val", "solid")
            if element.attributes.length() == 1 &&
              xlsx_attr(element, "val", "") == "" {
              return None
            }
            if ![
                "solid", "dot", "dash", "lgDash", "dashDot", "lgDashDot", "lgDashDotDot",
                "sysDash", "sysDot", "sysDashDot", "sysDashDotDot",
              ].contains(dash_name) {
              return None
            }
            shape_dash = dash_name
            true
          } else if name == "noFill" &&
            event.kind is Empty(_) &&
            !saw_no_line &&
            !saw_line_fill &&
            element.attributes.is_empty() {
            saw_no_line = true
            true
          } else if name == "solidFill" &&
            !saw_no_line &&
            !saw_line_fill &&
            element.attributes.is_empty() {
            saw_line_fill = true
            true
          } else {
            false
          }
        } else if depth == 6 &&
          parent == "solidFill" &&
          parents[4] == "ln" &&
          is_shape {
          if ![
              "srgbClr", "schemeClr", "sysClr", "prstClr", "scrgbClr", "hslClr",
            ].contains(name) ||
            line_color is Some(_) {
            return None
          }
          if name == "schemeClr" && !theme_alpha_checked {
            theme_alphas = self.xlsx_shape_theme_alphas()
            theme_alpha_checked = true
          }
          if name == "schemeClr" && theme_alphas is None {
            return None
          }
          line_color = xlsx_simple_shape_color(
            element,
            theme_colors,
            theme_alphas.unwrap_or(Map([])),
          )
          line_invertible = !["scrgbClr", "hslClr"].contains(name)
          line_alpha = xlsx_shape_initial_alpha(
            element,
            theme_alphas.unwrap_or(Map([])),
          )
          line_color is Some(_)
        } else if depth == 6 &&
          ["srgbClr", "schemeClr", "sysClr", "prstClr", "scrgbClr", "hslClr"].contains(
            parent,
          ) &&
          parents[4] == "solidFill" &&
          is_shape {
          if !(event.kind is Empty(_)) {
            return None
          }
          if name == "inv" {
            if !shape_invertible || !element.attributes.is_empty() {
              return None
            }
            shape_fill = shape_fill.map(color => color ^ 0xffffff00U)
          } else {
            let next = match
              xlsx_shape_alpha_modifier(name, element, shape_alpha) {
              Some(value) => value
              None => return None
            }
            shape_alpha = next
            shape_fill = shape_fill.map(color => {
              (color & 0xffffff00U) | (next * 255.0).round().to_uint()
            })
          }
          shape_fill is Some(_)
        } else if depth == 7 &&
          ["srgbClr", "schemeClr", "sysClr", "prstClr", "scrgbClr", "hslClr"].contains(
            parent,
          ) &&
          parents[5] == "solidFill" &&
          parents[4] == "ln" &&
          is_shape {
          if !(event.kind is Empty(_)) {
            return None
          }
          if name == "inv" {
            if !line_invertible || !element.attributes.is_empty() {
              return None
            }
            line_color = line_color.map(color => color ^ 0xffffff00U)
          } else {
            let next = match
              xlsx_shape_alpha_modifier(name, element, line_alpha) {
              Some(value) => value
              None => return None
            }
            line_alpha = next
            line_color = line_color.map(color => {
              (color & 0xffffff00U) | (next * 255.0).round().to_uint()
            })
          }
          line_color is Some(_)
        } else if depth == 5 && parent == "xfrm" {
          if !(event.kind is Empty(_)) {
            return None
          }
          let keys = if name == "off" {
            if saw_xfrm_off {
              return None
            }
            saw_xfrm_off = true
            ["x", "y"]
          } else if name == "ext" {
            if saw_xfrm_ext {
              return None
            }
            saw_xfrm_ext = true
            ["cx", "cy"]
          } else {
            return None
          }
          let seen : Map[String, Bool] = Map([])
          for attr in element.attributes {
            let key = attr.name.local_name
            if !keys.contains(key) ||
              seen.contains(key) ||
              attr.name.namespace_uri is Some(_) {
              return None
            }
            seen[key] = true
            let value = match xlsx_int(attr.value) {
              Some(value) if value >= 0L &&
                value <= 254000000L &&
                (name != "ext" || value > 0L) => value
              _ => return None
            }
            if name == "ext" {
              if key == "cx" {
                frame_width = value.to_double() / 12700.0
              } else {
                frame_height = value.to_double() / 12700.0
              }
            }
          }
          seen.length() == 2
        } else if depth == 5 && parent == "prstGeom" {
          if name != "avLst" || (saw_adjustments && !(event.kind is Empty(_))) {
            return None
          }
          saw_adjustments = true
          event.kind is Empty(_) ||
          (
            is_shape &&
            [
              "triangle", "parallelogram", "trapezoid", "homePlate", "chevron", "plus",
            ].contains(shape_geometry)
          )
        } else if depth == 6 && parent == "avLst" && parents[4] == "prstGeom" {
          if name != "gd" ||
            !(event.kind is Empty(_)) ||
            shape_adjustment is Some(_) ||
            element.attributes.length() != 2 ||
            xlsx_attr(element, "name", "") != "adj" {
            return None
          }
          for attr in element.attributes {
            if attr.name.namespace_uri is Some(_) ||
              !["name", "fmla"].contains(attr.name.local_name) {
              return None
            }
          }
          let formula = xlsx_attr(element, "fmla", "")
          if !formula.has_prefix("val ") {
            return None
          }
          shape_adjustment = match xlsx_int(formula[4:].to_owned()) {
            Some(value) if value >= 0L && value <= 100000L => Some(value)
            _ => return None
          }
          true
        } else {
          false
        }
        if !good {
          return None
        }
        parents[depth] = name
        if depth == 3 && (parent == "from" || parent == "to") {
          text = StringBuilder()
        }
        if event.kind is Start(_) {
          depth += 1
        } else if depth == 3 && (parent == "from" || parent == "to") {
          return None
        } else if depth == 0 {
          break
        }
      }
      Text(value) | CData(value) =>
        if depth == 4 && (parents[2] == "from" || parents[2] == "to") {
          text.write_string(value)
        } else if xlsx_trim(value) != "" {
          return None
        }
      End(_) => {
        if depth == 4 && (parents[2] == "from" || parents[2] == "to") {
          let name = parents[3]
          let raw = match xlsx_int(xlsx_trim(text.to_string())) {
            Some(value) if value >= -254000000L && value <= 254000000L => value
            _ => return None
          }
          if name == "colOff" || name == "rowOff" {
            let offset = raw.to_double() / 12700.0
            if parents[2] == "from" {
              if name == "colOff" {
                if seen_from_x_offset {
                  return None
                }
                seen_from_x_offset = true
                from_x_offset = offset
              } else {
                if seen_from_y_offset {
                  return None
                }
                seen_from_y_offset = true
                from_y_offset = offset
              }
            } else if name == "colOff" {
              if seen_to_x_offset {
                return None
              }
              seen_to_x_offset = true
              to_x_offset = offset
            } else {
              if seen_to_y_offset {
                return None
              }
              seen_to_y_offset = true
              to_y_offset = offset
            }
          } else if raw < 0L || raw > 16383L {
            return None
          } else if parents[2] == "from" {
            let value = raw.to_int()
            if name == "col" {
              if from_column >= 0 {
                return None
              }
              from_column = value
            } else if name == "row" {
              if from_row >= 0 {
                return None
              }
              from_row = value
            }
          } else if name == "col" {
            let value = raw.to_int()
            if to_column >= 0 {
              return None
            }
            to_column = value
          } else if name == "row" {
            let value = raw.to_int()
            if to_row >= 0 {
              return None
            }
            to_row = value
          }
        }
        if depth == 2 {
          if pictures != 1 ||
            (kind == 2 && !saw_position) ||
            saw_xfrm_off != saw_xfrm_ext ||
            !saw_nv ||
            !saw_nvpr ||
            !saw_sppr ||
            !geometry ||
            (
              is_shape &&
              (
                !saw_shape_fill ||
                (!shape_no_fill && shape_fill is None) ||
                (saw_line && !saw_no_line && line_color is None)
              )
            ) ||
            (!is_shape && (!saw_blip_fill || !stretch || image_id == "")) {
            return None
          }
          match
            self.xlsx_finish_simple_picture(
              part,
              kind,
              from_row,
              from_column,
              to_row,
              to_column,
              from_x_offset,
              from_y_offset,
              to_x_offset,
              to_y_offset,
              x,
              y,
              width,
              height,
              image_id,
              alpha,
              fill_left,
              fill_top,
              fill_right,
              fill_bottom,
              crop_left,
              crop_top,
              crop_right,
              crop_bottom,
              flip_horizontal,
              flip_vertical,
              rotation,
              frame_width,
              frame_height,
              description,
              title,
              images,
              1073741824L - image_bytes,
              is_shape,
            ) {
            Some(picture) => {
              image_bytes += picture.image.length().to_int64()
              if image_bytes > 1073741824L {
                return None
              }
              result.push(
                (
                  picture,
                  picture_hidden,
                  shape_fill,
                  line_color.map(color => (color, line_width)),
                  shape_no_fill,
                  shape_dash,
                  shape_geometry,
                  shape_adjustment,
                ),
              )
            }
            None => return None
          }
          kind = -1
          pictures = 0
          saw_from = false
          saw_to = false
          saw_nv = false
          saw_nvpr = false
          picture_hidden = false
          is_shape = false
          shape_fill = None
          shape_no_fill = false
          saw_shape_fill = false
          saw_line = false
          saw_no_line = false
          saw_line_fill = false
          line_color = None
          shape_alpha = 1.0
          line_alpha = 1.0
          shape_invertible = false
          line_invertible = false
          line_width = 0.75
          shape_dash = ""
          saw_dash = false
          saw_blip_fill = false
          saw_sppr = false
          geometry = false
          shape_geometry = ""
          shape_adjustment = None
          saw_adjustments = false
          stretch = false
          from_row = -1
          from_column = -1
          to_row = -1
          to_column = -1
          from_x_offset = 0.0
          from_y_offset = 0.0
          to_x_offset = 0.0
          to_y_offset = 0.0
          seen_from_x_offset = false
          seen_from_y_offset = false
          seen_to_x_offset = false
          seen_to_y_offset = false
          x = -1.0
          y = -1.0
          saw_position = false
          width = -1.0
          height = -1.0
          image_id = ""
          alpha = None
          fill_left = 0.0
          fill_top = 0.0
          fill_right = 0.0
          fill_bottom = 0.0
          saw_fill_rect = false
          crop_left = 0.0
          crop_top = 0.0
          crop_right = 0.0
          crop_bottom = 0.0
          saw_crop = false
          saw_xfrm = false
          saw_xfrm_off = false
          saw_xfrm_ext = false
          frame_width = 0.0
          frame_height = 0.0
          flip_horizontal = false
          flip_vertical = false
          rotation = 0
          description = ""
          title = ""
        }
        depth -= 1
        if depth == 0 {
          break
        }
      }
      Eof => return None
      _ => ()
    }
  }
  if result.is_empty() {
    None
  } else {
    Some(result)
  }
}

///|
fn XlsxWorkbook::xlsx_shape_theme_alphas(
  self : XlsxWorkbook,
) -> Map[Int32, Double]? {
  let result : Map[Int32, Double] = Map([])
  let rel = match self.package.relationship_of_type(self.part, "/theme") {
    Some(rel) if !rel.external => rel
    Some(_) => return None
    None => return Some(result)
  }
  let data = self.package.read(rel.target) catch { _ => return None }
  let reader = @xml.NamespaceReader::from_string(
    @utf8.decode_lossy(data[:], ignore_bom=true),
  )
  let parents = Array::make(16, "")
  let seen_slots : Map[Int32, Bool] = Map([])
  let mut depth = 0
  let mut slot = -1
  let mut found_color = false
  while true {
    let event = reader.read_event() catch { _ => return None }
    match event.kind {
      Start(element) | Empty(element) => {
        if depth >= parents.length() {
          return None
        }
        let name = element.name.local_name
        let in_scheme = depth >= 3 &&
          parents[0] == "theme" &&
          parents[1] == "themeElements" &&
          parents[2] == "clrScheme"
        if in_scheme && depth == 3 {
          slot = xlsx_theme_slot(name)
          found_color = false
          if slot >= 0 {
            if seen_slots.contains(slot) {
              return None
            }
            seen_slots[slot] = true
          }
        } else if in_scheme &&
          depth == 4 &&
          slot >= 0 &&
          ["srgbClr", "sysClr", "schemeClr", "prstClr", "scrgbClr", "hslClr"].contains(
            name,
          ) {
          if found_color {
            return None
          }
          found_color = true
        } else if in_scheme && ["alpha", "alphaMod", "alphaOff"].contains(name) {
          if depth != 5 ||
            slot < 0 ||
            !found_color ||
            !["srgbClr", "sysClr", "schemeClr", "prstClr", "scrgbClr", "hslClr"].contains(
              parents[4],
            ) ||
            !(event.kind is Empty(_)) ||
            element.attributes.length() != 1 {
            return None
          }
          let value = match xlsx_int(xlsx_attr(element, "val", "")) {
            Some(value) if value <= 100000L &&
              value >= (if name == "alphaOff" { -100000L } else { 0L }) => value
            _ => return None
          }
          result[slot] = xlsx_shape_apply_theme_alpha(
            name,
            result.get(slot).unwrap_or(1.0),
            value,
          )
        }
        parents[depth] = name
        if event.kind is Start(_) {
          depth += 1
        }
      }
      End(_) => {
        depth -= 1
        if depth < 0 {
          return None
        }
        if depth == 3 {
          slot = -1
        }
      }
      Eof => return if depth == 0 { Some(result) } else { None }
      _ => ()
    }
  }
  None
}

///|
fn xlsx_shape_apply_theme_alpha(
  name : String,
  previous : Double,
  value : Int64,
) -> Double {
  let fraction = value.to_double() / 100000.0
  let next = match name {
    "alpha" => fraction
    "alphaMod" => previous * fraction
    _ => previous + fraction
  }
  Double::max(0.0, Double::min(1.0, next))
}

///|
fn xlsx_simple_shape_color(
  element : @xml.NamespaceElement,
  theme_colors : Map[Int32, XlsxRgb],
  theme_alphas : Map[Int32, Double],
) -> UInt32? {
  if element.name.local_name == "schemeClr" {
    if element.attributes.length() != 1 {
      return None
    }
    let name = xlsx_attr(element, "val", "")
    if name == "phClr" {
      return Some(0x000000ffU)
    }
    let mapped = match name {
      "bg1" => "lt1"
      "tx1" => "dk1"
      "bg2" => "lt2"
      "tx2" => "dk2"
      _ => name
    }
    let slot = xlsx_theme_slot(mapped)
    let color = match theme_colors.get(slot) {
      Some(color) => color
      None => return None
    }
    let red = (color.red * 255.0 + 0.5).to_int().to_uint()
    let green = (color.green * 255.0 + 0.5).to_int().to_uint()
    let blue = (color.blue * 255.0 + 0.5).to_int().to_uint()
    return Some(
      (red << 24) |
      (green << 16) |
      (blue << 8) |
      (Double::max(0.0, Double::min(1.0, theme_alphas.get(slot).unwrap_or(1.0))) *
      255.0)
      .round()
      .to_uint(),
    )
  }
  if element.name.local_name == "hslClr" {
    let components : Array[Int64] = [0L, 0L, 0L]
    let seen : Map[String, Bool] = Map([])
    for attr in element.attributes {
      let name = attr.name.local_name
      if !["hue", "sat", "lum"].contains(name) ||
        seen.contains(name) ||
        attr.name.namespace_uri is Some(_) {
        return None
      }
      seen[name] = true
      let limit = if name == "hue" { 21600000L } else { 100000L }
      let value = match xlsx_int(attr.value) {
        Some(value) if value >= 0L && value <= limit => value
        _ => return None
      }
      let index = if name == "hue" { 0 } else if name == "sat" { 1 } else { 2 }
      components[index] = value
    }
    return Some(
      xlsx_shape_hsl_color(components[0], components[1], components[2]),
    )
  }
  if element.name.local_name == "scrgbClr" {
    let components : Array[Int32] = [0, 0, 0]
    let seen : Map[String, Bool] = Map([])
    for attr in element.attributes {
      let name = attr.name.local_name
      if !["r", "g", "b"].contains(name) ||
        seen.contains(name) ||
        attr.name.namespace_uri is Some(_) {
        return None
      }
      seen[name] = true
      let value = match xlsx_int(attr.value) {
        Some(value) if value >= 0L && value <= 100000L => value.to_int()
        _ => return None
      }
      let index = if name == "r" { 0 } else if name == "g" { 1 } else { 2 }
      components[index] = value
    }
    return Some(
      (xlsx_shape_linear_component(components[0]) << 24) |
      (xlsx_shape_linear_component(components[1]) << 16) |
      (xlsx_shape_linear_component(components[2]) << 8) |
      255U,
    )
  }
  if element.name.local_name == "prstClr" {
    if element.attributes.length() != 1 {
      return None
    }
    let color = match xlsx_shape_preset_color(xlsx_attr(element, "val", "")) {
      Some(color) => color
      None => return None
    }
    return Some((color << 8) | 255U)
  }
  if element.name.local_name == "sysClr" {
    let seen : Map[String, Bool] = Map([])
    for attr in element.attributes {
      let name = attr.name.local_name
      if !["val", "lastClr"].contains(name) ||
        seen.contains(name) ||
        attr.name.namespace_uri is Some(_) {
        return None
      }
      seen[name] = true
    }
    let color = match xlsx_theme_hex(xlsx_attr(element, "lastClr", "")) {
      Some(color) => color
      None =>
        xlsx_rgb_from_uint(
          if ["window", "btnHighlight", "highlightText", "menu", "info"].contains(
              xlsx_attr(element, "val", ""),
            ) {
            0xffffffU
          } else {
            0U
          },
        )
    }
    let red = (color.red * 255.0).round().to_uint()
    let green = (color.green * 255.0).round().to_uint()
    let blue = (color.blue * 255.0).round().to_uint()
    return Some((red << 24) | (green << 16) | (blue << 8) | 255U)
  }
  let bytes = @utf8.encode(xlsx_attr(element, "val", ""))
  if bytes.length() != 6 || element.attributes.length() != 1 {
    return None
  }
  let mut rgb = 0U
  for byte in bytes {
    let digit = xlsx_hex(byte)
    if digit < 0 {
      return None
    }
    rgb = rgb * 16U + digit.to_uint()
  }
  Some((rgb << 8) | 255U)
}

///|
fn xlsx_shape_hsl_color(
  hue_units : Int64,
  sat_units : Int64,
  lum_units : Int64,
) -> UInt32 {
  let hue = hue_units.to_double() / 60000.0 / 360.0
  let sat = sat_units.to_double() / 100000.0
  let lum = lum_units.to_double() / 100000.0
  let color = if sat == 0.0 {
    { red: lum, green: lum, blue: lum, }
  } else {
    let q = if lum < 0.5 {
      lum * (1.0 + sat)
    } else {
      xlsx_fma(-lum, sat, lum + sat)
    }
    let p = 2.0 * lum - q
    {
      red: xlsx_color_component(hue + 1.0 / 3.0, p, q),
      green: xlsx_color_component(hue, p, q),
      blue: xlsx_color_component(hue - 1.0 / 3.0, p, q),
    }
  }
  let red = (xlsx_clamp_color(color.red) * 255.0).round().to_uint()
  let green = (xlsx_clamp_color(color.green) * 255.0).round().to_uint()
  let blue = (xlsx_clamp_color(color.blue) * 255.0).round().to_uint()
  (red << 24) | (green << 16) | (blue << 8) | 255U
}

///|
fn xlsx_shape_initial_alpha(
  element : @xml.NamespaceElement,
  alphas : Map[Int32, Double],
) -> Double {
  if element.name.local_name != "schemeClr" {
    return 1.0
  }
  let name = xlsx_attr(element, "val", "")
  let mapped = match name {
    "bg1" => "lt1"
    "tx1" => "dk1"
    "bg2" => "lt2"
    "tx2" => "dk2"
    _ => name
  }
  if name == "phClr" {
    1.0
  } else {
    alphas.get(xlsx_theme_slot(mapped)).unwrap_or(1.0)
  }
}

///|
fn xlsx_shape_alpha_modifier(
  name : String,
  element : @xml.NamespaceElement,
  previous : Double,
) -> Double? {
  if !["alpha", "alphaMod", "alphaOff"].contains(name) ||
    element.attributes.length() != 1 {
    return None
  }
  let value = match xlsx_int(xlsx_attr(element, "val", "")) {
    Some(value) if value <= 100000L &&
      value >= (if name == "alphaOff" { -100000L } else { 0L }) => value
    _ => return None
  }
  Some(xlsx_shape_apply_theme_alpha(name, previous, value))
}

///|
fn XlsxWorkbook::xlsx_finish_simple_picture(
  self : XlsxWorkbook,
  part : String,
  kind : Int32,
  from_row : Int32,
  from_column : Int32,
  input_to_row : Int32,
  input_to_column : Int32,
  from_x_offset : Double,
  from_y_offset : Double,
  to_x_offset : Double,
  to_y_offset : Double,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  image_id : String,
  alpha : Float?,
  fill_left : Double,
  fill_top : Double,
  fill_right : Double,
  fill_bottom : Double,
  crop_left : Double,
  crop_top : Double,
  crop_right : Double,
  crop_bottom : Double,
  flip_horizontal : Bool,
  flip_vertical : Bool,
  rotation : Int32,
  frame_width : Double,
  frame_height : Double,
  description : String,
  title : String,
  images : Map[String, Bytes],
  remaining_bytes : Int64,
  is_shape : Bool,
) -> @sheet.GridPicture? {
  let mut to_row = input_to_row
  let mut to_column = input_to_column
  if kind == 0 &&
    (
      from_row < 0 ||
      from_column < 0 ||
      to_row < from_row ||
      to_column < from_column
    ) {
    return None
  }
  if kind == 1 &&
    (from_row < 0 || from_column < 0 || width < 0.0 || height < 0.0) {
    return None
  }
  if kind == 2 && (width < 0.0 || height < 0.0) {
    return None
  }
  let image = if is_shape {
    b""
  } else {
    let rel = match self.package.target(part, image_id) {
      Some(rel) if !rel.external => rel
      _ => return None
    }
    if self.package.part_size(rel.target).unwrap_or(0).to_int64() >
      remaining_bytes {
      return None
    }
    let image = match images.get(rel.target) {
      Some(image) => image
      None => {
        let image = self.package.read(rel.target) catch { _ => return None }
        images[rel.target] = image
        image
      }
    }
    if !xlsx_picture_image_format(image) {
      return None
    }
    image
  }
  // Go has no AVIF image.DecodeConfig registration, so it draws the full
  // image when a crop is present but intrinsic dimensions are unavailable.
  let crop_ignored = image.length() >= 12 &&
    image[4:8] == b"ftyp"[:] &&
    (image[8:12] == b"avif"[:] || image[8:12] == b"avis"[:])
  let mut crop_left = if crop_ignored { 0.0 } else { crop_left }
  let mut crop_top = if crop_ignored { 0.0 } else { crop_top }
  let mut crop_right = if crop_ignored { 0.0 } else { crop_right }
  let mut crop_bottom = if crop_ignored { 0.0 } else { crop_bottom }
  let (image_width, image_height) = if crop_left != 0.0 ||
    crop_top != 0.0 ||
    crop_right != 0.0 ||
    crop_bottom != 0.0 {
    match xlsx_crop_image_size(image) {
      Some(size) => size
      None => return None
    }
  } else {
    (0.0, 0.0)
  }
  if image_width == 0.0 && image_height == 0.0 {
    crop_left = 0.0
    crop_top = 0.0
    crop_right = 0.0
    crop_bottom = 0.0
  }
  if kind == 1 {
    to_row = from_row + (height / 15.0).to_int() + 1
    to_column = from_column + (width / 48.0).to_int() + 1
  }
  if kind == 2 {
    to_row = ((y + height) / 15.0).to_int() + 1
    to_column = ((x + width) / 48.0).to_int() + 1
  }
  if to_row >= 1048576 || to_column >= 16384 {
    return None
  }
  Some({
    kind,
    from_row,
    from_column,
    to_row,
    to_column,
    from_x_offset,
    from_y_offset,
    to_x_offset,
    to_y_offset,
    x,
    y,
    width,
    height,
    description: if description != "" {
      description
    } else {
      title
    },
    image,
    alpha,
    fill_left,
    fill_top,
    fill_right,
    fill_bottom,
    crop_left,
    crop_top,
    crop_right,
    crop_bottom,
    image_width,
    image_height,
    flip_horizontal,
    flip_vertical,
    rotation,
    frame_width,
    frame_height,
  })
}

///|
// Match the upstream image-format sniff used when images are kept unchanged.
fn xlsx_picture_image_format(image : Bytes) -> Bool {
  if image.length() >= 8 && image[:8] == b"\x89PNG\r\n\x1a\n"[:] {
    return true
  }
  if image.length() >= 3 && image[:3] == b"\xff\xd8\xff"[:] {
    return true
  }
  if image.length() >= 6 &&
    (image[:6] == b"GIF87a"[:] || image[:6] == b"GIF89a"[:]) {
    return true
  }
  if image.length() >= 2 && image[:2] == b"BM"[:] {
    return true
  }
  if image.length() >= 12 &&
    image[:4] == b"RIFF"[:] &&
    image[8:12] == b"WEBP"[:] {
    return true
  }
  if image.length() >= 12 &&
    image[4:8] == b"ftyp"[:] &&
    (image[8:12] == b"avif"[:] || image[8:12] == b"avis"[:]) {
    return true
  }
  @utf8.decode_lossy(image[:Int32::min(image.length(), 512)]).contains("<svg")
}

///|
fn xlsx_crop_image_size(image : Bytes) -> (Double, Double)? {
  if image.length() >= 13 &&
    (image[:6] == b"GIF87a"[:] || image[:6] == b"GIF89a"[:]) {
    let flags = image[10].to_int()
    let palette_size = if (flags & 0x80) != 0 {
      3 * (1 << ((flags & 7) + 1))
    } else {
      0
    }
    if image.length() < 13 + palette_size {
      return None
    }
    let width = image[6].to_int() | (image[7].to_int() << 8)
    let height = image[8].to_int() | (image[9].to_int() << 8)
    if width <= 0 || height <= 0 {
      return None
    }
    return Some((width.to_double(), height.to_double()))
  }
  if image.length() >= 54 &&
    image[:2] == b"BM"[:] &&
    image[6:10] == b"\x00\x00\x00\x00"[:] {
    let le32 = fn(offset : Int32) -> Int64 {
      image[offset].to_int64() |
      (image[offset + 1].to_int64() << 8) |
      (image[offset + 2].to_int64() << 16) |
      (image[offset + 3].to_int64() << 24)
    }
    let bits = image[28].to_int() | (image[29].to_int() << 8)
    if le32(10) != 54L ||
      le32(14) != 40L ||
      image[26] != 1 ||
      image[27] != 0 ||
      (bits != 24 && bits != 32) ||
      le32(30) != 0L {
      return None
    }
    let width = le32(18)
    let raw_height = le32(22)
    let height = if raw_height >= 2147483648L {
      4294967296L - raw_height
    } else {
      raw_height
    }
    if width <= 0L || width > 1000000L || height <= 0L || height > 1000000L {
      return None
    }
    return Some((width.to_double(), height.to_double()))
  }
  if image.length() >= 30 &&
    image[:4] == b"RIFF"[:] &&
    image[8:16] == b"WEBPVP8X"[:] {
    let riff_size = image[4].to_int64() |
      (image[5].to_int64() << 8) |
      (image[6].to_int64() << 16) |
      (image[7].to_int64() << 24)
    if riff_size < 22L || image[16:20] != b"\x0a\x00\x00\x00"[:] {
      return None
    }
    let width = 1L +
      image[24].to_int64() +
      (image[25].to_int64() << 8) +
      (image[26].to_int64() << 16)
    let height = 1L +
      image[27].to_int64() +
      (image[28].to_int64() << 8) +
      (image[29].to_int64() << 16)
    if width * height > 2147483647L {
      return None
    }
    return Some((width.to_double(), height.to_double()))
  }
  if image.length() >= 25 &&
    image[:4] == b"RIFF"[:] &&
    image[8:12] == b"WEBP"[:] &&
    (image[12:16] == b"VP8 "[:] || image[12:16] == b"VP8L"[:]) {
    let riff_size = image[4].to_int64() |
      (image[5].to_int64() << 8) |
      (image[6].to_int64() << 16) |
      (image[7].to_int64() << 24)
    let chunk_size = image[16].to_int64() |
      (image[17].to_int64() << 8) |
      (image[18].to_int64() << 16) |
      (image[19].to_int64() << 24)
    if riff_size < 12L ||
      chunk_size > riff_size - 12L ||
      chunk_size > 2147483647L {
      return None
    }
    if image[12:16] == b"VP8L"[:] {
      if chunk_size < 5L || image[20] != 0x2f || image[24].to_int() >> 5 != 0 {
        return None
      }
      let bits = image[21].to_int64() |
        (image[22].to_int64() << 8) |
        (image[23].to_int64() << 16) |
        (image[24].to_int64() << 24)
      return Some(
        (
          (1L + (bits & 0x3fffL)).to_double(),
          (1L + ((bits >> 14) & 0x3fffL)).to_double(),
        ),
      )
    }
    if chunk_size < 10L ||
      image.length() < 30 ||
      (image[20].to_int() & 1) != 0 ||
      image[23:26] != b"\x9d\x01\x2a"[:] {
      return None
    }
    let width = image[26].to_int() | ((image[27].to_int() & 63) << 8)
    let height = image[28].to_int() | ((image[29].to_int() & 63) << 8)
    if width <= 0 || height <= 0 {
      return None
    }
    return Some((width.to_double(), height.to_double()))
  }
  if image.length() >= 3 && image[:3] == b"\xff\xd8\xff"[:] {
    return xlsx_crop_jpeg_size(image)
  }
  if xlsx_crop_png_size(image) is Some(size) {
    return Some(size)
  }
  xlsx_crop_svg_size(image)
}

///|
fn xlsx_crop_svg_size(image : Bytes) -> (Double, Double)? {
  if image.length() > 4194304 {
    return None
  }
  let source = @utf8.decode(image[:], ignore_bom=true) catch {
    _ => return None
  }
  if source.contains("<!ENTITY") {
    return None
  }
  let reader = @xml.NamespaceReader::from_string(source)
  while true {
    let event = reader.read_event() catch { _ => return None }
    match event.kind {
      Start(element) | Empty(element) => {
        if element.name.local_name != "svg" {
          return None
        }
        let mut width : Double? = None
        let mut height : Double? = None
        let mut seen_width = false
        let mut seen_height = false
        let mut view_box : String? = None
        for attr in element.attributes {
          if attr.name.namespace_uri is None &&
            attr.name.local_name == "viewBox" {
            if view_box is Some(_) {
              return None
            }
            view_box = Some(attr.value)
          } else if attr.name.namespace_uri is None &&
            (
              attr.name.local_name == "width" ||
              attr.name.local_name == "height"
            ) {
            let raw = @utf8.encode(attr.value)
            let mut end = raw.length()
            while end > 0 &&
                  [b' ', b'\t', b'\r', b'\n', b'\x0c'].contains(raw[end - 1]) {
              end -= 1
            }
            let relative = end > 0 && raw[end - 1] == b'%'
            let value = if relative {
              None
            } else {
              match xlsx_crop_svg_length(attr.value, true) {
                Some(value) => Some(value)
                None => return None
              }
            }
            if attr.name.local_name == "width" {
              if seen_width {
                return None
              }
              seen_width = true
              width = value
            } else {
              if seen_height {
                return None
              }
              seen_height = true
              height = value
            }
          }
        }
        if (width, height) is (Some(w), Some(h)) {
          return Some((w, h))
        }
        let box = match view_box {
          Some(box) => box
          None => return Some((0.0, 0.0))
        }
        let (vw, vh) = match xlsx_crop_svg_viewbox(box) {
          Some(size) => size
          None => return None
        }
        let (w, h) = match (width, height) {
          (Some(w), None) => (w, w * vh / vw)
          (None, Some(h)) => (h * vw / vh, h)
          (None, None) => (vw, vh)
          (Some(w), Some(h)) => (w, h)
        }
        if w <= 0.0 ||
          h <= 0.0 ||
          w > 1000000.0 ||
          h > 1000000.0 ||
          w.is_inf() ||
          h.is_inf() {
          return None
        }
        return Some((w, h))
      }
      End(_) | Eof => return None
      _ => ()
    }
  }
  None
}

///|
fn xlsx_crop_svg_viewbox(value : String) -> (Double, Double)? {
  let fields : Array[String] = []
  let word = StringBuilder()
  for ch in value {
    if ch == ',' || ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n' {
      let part = word.to_string()
      if part != "" {
        fields.push(part)
        word.reset()
      }
    } else {
      word.write_char(ch)
    }
    if fields.length() > 4 {
      return None
    }
  }
  let part = word.to_string()
  if part != "" {
    fields.push(part)
  }
  if fields.length() != 4 {
    return None
  }
  let w = match xlsx_crop_svg_length(fields[2], false) {
    Some(v) => v
    None => return None
  }
  let h = match xlsx_crop_svg_length(fields[3], false) {
    Some(v) => v
    None => return None
  }
  Some((w, h))
}

///|
fn xlsx_crop_svg_length(value : String, allow_units : Bool) -> Double? {
  let data = @utf8.encode(value)
  let mut i = 0
  while i < data.length() &&
        [b' ', b'\t', b'\r', b'\n', b'\x0c'].contains(data[i]) {
    i += 1
  }
  let start = i
  if i < data.length() && data[i] == b'+' {
    i += 1
  }
  let mut digits = 0
  while i < data.length() && data[i] >= b'0' && data[i] <= b'9' {
    i += 1
    digits += 1
  }
  if i < data.length() && data[i] == b'.' {
    i += 1
    while i < data.length() && data[i] >= b'0' && data[i] <= b'9' {
      i += 1
      digits += 1
    }
  }
  if digits == 0 {
    return None
  }
  if i < data.length() && (data[i] == b'e' || data[i] == b'E') {
    let marker = i
    i += 1
    if i < data.length() && (data[i] == b'+' || data[i] == b'-') {
      i += 1
    }
    let exponent_start = i
    while i < data.length() && data[i] >= b'0' && data[i] <= b'9' {
      i += 1
    }
    if i == exponent_start {
      i = marker
    }
  }
  let number = @utf8.decode(data[start:i]) catch { _ => return None }
  let parsed = @string.parse_double(number) catch { _ => return None }
  while i < data.length() &&
        [b' ', b'\t', b'\r', b'\n', b'\x0c'].contains(data[i]) {
    i += 1
  }
  let unit_start = i
  while i < data.length() &&
        (
          (data[i] >= b'a' && data[i] <= b'z') ||
          (data[i] >= b'A' && data[i] <= b'Z')
        ) {
    i += 1
  }
  let unit = @utf8.decode(data[unit_start:i]) catch { _ => return None }
  while i < data.length() &&
        [b' ', b'\t', b'\r', b'\n', b'\x0c'].contains(data[i]) {
    i += 1
  }
  if i != data.length() || parsed <= 0.0 || parsed.is_nan() || parsed.is_inf() {
    return None
  }
  if !allow_units && unit != "" {
    return None
  }
  let size = match unit.to_lower() {
    "" | "px" => parsed
    "pt" => parsed * (96.0 / 72.0)
    "pc" | "em" => parsed * 16.0
    "in" => parsed * 96.0
    "cm" => parsed * (96.0 / 2.54)
    "mm" => parsed * (96.0 / 25.4)
    "q" => parsed * (96.0 / 101.6)
    "ex" => parsed * 8.0
    _ => return None
  }
  if size > 1000000.0 || size.is_inf() {
    return None
  }
  Some(size)
}

///|
fn xlsx_crop_jpeg_size(image : Bytes) -> (Double, Double)? {
  let mut offset = 2
  let mut width = 0
  let mut height = 0
  let mut frame_seen = false
  let mut segments = 0
  while offset < image.length() {
    if image[offset] != 0xff {
      return None
    }
    while offset < image.length() && image[offset] == 0xff {
      offset += 1
    }
    if offset >= image.length() {
      return None
    }
    let marker = image[offset].to_int()
    offset += 1
    if marker >= 0xd0 && marker <= 0xd7 {
      continue
    }
    if marker == 0xd9 {
      return None
    }
    if offset > image.length() - 2 {
      return None
    }
    let length = (image[offset].to_int() << 8) | image[offset + 1].to_int()
    if length < 2 || length > image.length() - offset {
      return None
    }
    let start = offset + 2
    let data_len = length - 2
    segments += 1
    if segments > 4096 {
      return None
    }
    if marker == 0xc0 || marker == 0xc1 || marker == 0xc2 {
      if frame_seen || data_len < 9 || image[start] != 8 {
        return None
      }
      let components = image[start + 5].to_int()
      if (components != 1 && components != 3) || data_len != 6 + 3 * components {
        return None
      }
      height = (image[start + 1].to_int() << 8) | image[start + 2].to_int()
      width = (image[start + 3].to_int() << 8) | image[start + 4].to_int()
      if width <= 0 || height <= 0 {
        return None
      }
      let ids : Map[Int32, Bool] = Map([])
      let hs : Array[Int32] = []
      let vs : Array[Int32] = []
      let mut max_h = 0
      let mut max_v = 0
      for i in 0..<components {
        let id = image[start + 6 + i * 3].to_int()
        let sampling = image[start + 7 + i * 3].to_int()
        let h = sampling >> 4
        let v = sampling & 15
        let table = image[start + 8 + i * 3].to_int()
        if ids.contains(id) ||
          ![1, 2, 4].contains(h) ||
          ![1, 2, 4].contains(v) ||
          table > 3 {
          return None
        }
        ids[id] = true
        hs.push(h)
        vs.push(v)
        max_h = Int32::max(max_h, h)
        max_v = Int32::max(max_v, v)
      }
      if components == 3 {
        for i in 0..<components {
          if max_h % hs[i] != 0 || max_v % vs[i] != 0 {
            return None
          }
        }
      }
      frame_seen = true
    } else if marker == 0xda {
      if !frame_seen {
        return None
      }
      return Some((width.to_double(), height.to_double()))
    } else if !(marker == 0xc4 ||
      marker == 0xdb ||
      marker == 0xdd ||
      marker == 0xfe ||
      (marker >= 0xe0 && marker <= 0xef)) {
      return None
    }
    offset += length
  }
  None
}

///|
fn xlsx_crop_png_size(image : Bytes) -> (Double, Double)? {
  if image.length() < 33 ||
    image[:8] != b"\x89PNG\r\n\x1a\n"[:] ||
    image[8:16] != b"\x00\x00\x00\x0dIHDR"[:] {
    return None
  }
  let mut crc = 0xffffffffU
  for byte in image[12:29] {
    crc = crc ^ byte.to_uint()
    for _ in 0..<8 {
      crc = if (crc & 1U) != 0U { (crc >> 1) ^ 0xedb88320U } else { crc >> 1 }
    }
  }
  crc = crc ^ 0xffffffffU
  let crc_expected = (image[29].to_uint() << 24) |
    (image[30].to_uint() << 16) |
    (image[31].to_uint() << 8) |
    image[32].to_uint()
  if crc != crc_expected || image[26] != 0 || image[27] != 0 || image[28] > 1 {
    return None
  }
  let bit_depth = image[24].to_int()
  let color_type = image[25].to_int()
  if !((bit_depth == 8 || bit_depth == 16) && [0, 2, 4, 6].contains(color_type)) {
    return None
  }
  let w = (image[16].to_int64() << 24) |
    (image[17].to_int64() << 16) |
    (image[18].to_int64() << 8) |
    image[19].to_int64()
  let h = (image[20].to_int64() << 24) |
    (image[21].to_int64() << 16) |
    (image[22].to_int64() << 8) |
    image[23].to_int64()
  if w <= 0L || h <= 0L || w > 1000000L || h > 1000000L {
    return None
  }
  Some((w.to_double(), h.to_double()))
}
