///|
fn xlsx_theme_slot(name : String) -> Int32 {
  match name {
    "lt1" => 0
    "dk1" => 1
    "lt2" => 2
    "dk2" => 3
    "accent1" => 4
    "accent2" => 5
    "accent3" => 6
    "accent4" => 7
    "accent5" => 8
    "accent6" => 9
    "hlink" => 10
    "folHlink" => 11
    _ => -1
  }
}

///|
fn xlsx_theme_hex(value : String) -> XlsxRgb? {
  let text = xlsx_trim(value)
  let text = if text.has_prefix("#") { text[1:].to_owned() } else { text }
  let bytes = @utf8.encode(text)
  if bytes.length() != 6 {
    return None
  }
  let mut rgb = 0U
  for b in bytes {
    let digit = xlsx_hex(b)
    if digit < 0 {
      return None
    }
    rgb = rgb * 16U + digit.to_uint()
  }
  Some(xlsx_rgb_from_uint(rgb))
}

///|
fn xlsx_theme_choice(
  reader : @xml.NamespaceReader,
  element : @xml.NamespaceElement,
  empty : Bool,
) -> (Int32, XlsxRgb?) raise {
  let name = element.name.local_name
  let (initial_status, color) = match name {
    "srgbClr" =>
      match xlsx_theme_hex(xlsx_attr(element, "val", "")) {
        Some(c) => (1, Some(c))
        None => (0, None)
      }
    "sysClr" => {
      let c = match xlsx_theme_hex(xlsx_attr(element, "lastClr", "")) {
        Some(c) => c
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
      (1, Some(c))
    }
    "schemeClr" =>
      if xlsx_attr(element, "val", "") == "phClr" {
        (1, Some(xlsx_rgb_from_uint(0U)))
      } else {
        (0, None)
      }
    _ => (2, None)
  }
  let mut status = initial_status
  if !empty {
    let mut depth = 1
    while depth > 0 {
      let event = reader.read_event()
      match event.kind {
        Start(e) | Empty(e) => {
          if depth == 1 &&
            [
              "lumMod", "lumOff", "satMod", "satOff", "hueMod", "hueOff", "hue",
              "sat", "lum", "tint", "shade", "comp", "inv", "gray", "gamma", "invGamma",
              "red", "redMod", "redOff", "green", "greenMod", "greenOff", "blue",
              "blueMod", "blueOff",
            ].contains(e.name.local_name) &&
            status == 1 {
            status = 2
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
  (status, color)
}

///|
fn xlsx_theme_entry(
  reader : @xml.NamespaceReader,
  empty : Bool,
) -> (Int32, XlsxRgb?) raise {
  if empty {
    return (0, None)
  }
  let mut depth = 1
  let mut found = false
  let mut status = 0
  let mut color : XlsxRgb? = None
  while depth > 0 {
    let event = reader.read_event()
    match event.kind {
      Start(e) | Empty(e) => {
        if depth == 1 &&
          !found &&
          ["srgbClr", "schemeClr", "sysClr", "prstClr", "scrgbClr", "hslClr"].contains(
            e.name.local_name,
          ) {
          found = true
          let (s, c) = xlsx_theme_choice(reader, e, event.kind is Empty(_))
          status = s
          color = c
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
  (status, color)
}

///|
fn XlsxWorkbook::xlsx_plain_theme_colors(
  self : XlsxWorkbook,
) -> Map[Int32, XlsxRgb] raise {
  let defaults : Array[UInt32] = [
    0xffffffU, 0x000000U, 0xe7e6e6U, 0x44546aU, 0x4472c4U, 0xed7d31U, 0xa5a5a5U,
    0xffc000U, 0x5b9bd5U, 0x70ad47U, 0x0563c1U, 0x954f72U,
  ]
  let result : Map[Int32, XlsxRgb] = Map([])
  for i, rgb in defaults {
    result[i] = xlsx_rgb_from_uint(rgb)
  }
  let rel = match self.package.relationship_of_type(self.part, "/theme") {
    Some(r) => r
    None => return result
  }
  let data = self.package.read(rel.target) catch {
    @ooxml.InvalidOoxml(message) =>
      raise InvalidXlsxInput("xlsx: theme: " + message)
  }
  let text = @utf8.decode_lossy(data[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    raise InvalidXlsxInput("xlsx: the theme declares entities")
  }
  let reader = @xml.NamespaceReader::from_string(text)
  let mut depth = 0
  let mut elements_depth = -1
  let mut colors_depth = -1
  let mut seen_elements = false
  let mut seen_colors = false
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(e) | Empty(e) => {
        let name = e.name.local_name
        if depth == 1 && name == "themeElements" && !seen_elements {
          seen_elements = true
          if event.kind is Start(_) {
            elements_depth = depth + 1
          }
        } else if depth == elements_depth && name == "clrScheme" && !seen_colors {
          seen_colors = true
          if event.kind is Start(_) {
            colors_depth = depth + 1
          }
        } else if depth == colors_depth {
          let slot = xlsx_theme_slot(name)
          let (status, color) = xlsx_theme_entry(reader, event.kind is Empty(_))
          if slot >= 0 {
            if status == 2 {
              result.remove(slot)
            } else if status == 1 {
              if color is Some(c) {
                result[slot] = c
              }
            }
          }
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
        if depth + 1 == elements_depth {
          elements_depth = -1
        }
        if depth + 1 == colors_depth {
          colors_depth = -1
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
  result
}
