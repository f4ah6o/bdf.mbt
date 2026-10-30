///|
// Read one plain, untransformed embedded picture. Other drawing features
// remain unsupported until their rendering and relationship semantics exist.
fn XlsxWorkbook::xlsx_simple_picture(
  self : XlsxWorkbook,
  part : String,
) -> @sheet.GridPicture? {
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
  let mut pictures = 0
  let mut saw_from = false
  let mut saw_to = false
  let mut saw_nv = false
  let mut saw_nvpr = false
  let mut saw_blip_fill = false
  let mut saw_sppr = false
  let mut geometry = false
  let mut stretch = false
  let mut from_row = -1
  let mut from_column = -1
  let mut to_row = -1
  let mut to_column = -1
  let mut x = -1.0
  let mut y = -1.0
  let mut width = -1.0
  let mut height = -1.0
  let mut image_id = ""
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
          anchors == 1
        } else if depth == 2 &&
          (
            parent == "twoCellAnchor" ||
            parent == "oneCellAnchor" ||
            parent == "absoluteAnchor"
          ) {
          if name == "pic" {
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
            if x >= 0.0 || y >= 0.0 {
              return None
            }
            let px = xlsx_int(xlsx_attr(element, "x", ""))
            let py = xlsx_int(xlsx_attr(element, "y", ""))
            match (px, py) {
              (Some(a), Some(b)) if a >= 0L &&
                b >= 0L &&
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
        } else if depth == 3 && parent == "pic" {
          if name == "nvPicPr" {
            if saw_nv {
              return None
            }
            saw_nv = true
            true
          } else if name == "blipFill" {
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
        } else if depth == 4 && parent == "nvPicPr" {
          if name == "cNvPr" {
            if saw_nvpr {
              return None
            }
            saw_nvpr = true
            if xlsx_attr(element, "hidden", "") != "" {
              return None
            }
            description = xlsx_trim(xlsx_attr(element, "descr", ""))
            title = xlsx_trim(xlsx_attr(element, "title", ""))
            true
          } else {
            name == "cNvPicPr"
          }
        } else if depth == 4 && parent == "blipFill" {
          if name == "blip" {
            if image_id != "" {
              return None
            }
            image_id = xlsx_rel_id(element, "embed")
            image_id != "" && xlsx_rel_id(element, "link") == ""
          } else if name == "stretch" {
            if stretch {
              return None
            }
            stretch = true
            true
          } else {
            false
          }
        } else if depth == 5 && parent == "stretch" {
          name == "fillRect" && element.attributes.is_empty()
        } else if depth == 4 && parent == "spPr" {
          if name == "prstGeom" && xlsx_attr(element, "prst", "") == "rect" {
            if geometry {
              return None
            }
            geometry = true
            true
          } else {
            false
          }
        } else if depth == 5 && parent == "prstGeom" {
          name == "avLst" && event.kind is Empty(_)
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
          let value = match xlsx_int(xlsx_trim(text.to_string())) {
            Some(value) if value >= 0L && value <= 16383L => value.to_int()
            _ => return None
          }
          let name = parents[3]
          if name == "colOff" || name == "rowOff" {
            if value != 0 {
              return None
            }
          } else if parents[2] == "from" {
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
            if to_column >= 0 {
              return None
            }
            to_column = value
          } else if name == "row" {
            if to_row >= 0 {
              return None
            }
            to_row = value
          }
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
  if anchors != 1 ||
    pictures != 1 ||
    !saw_nv ||
    !saw_nvpr ||
    !saw_blip_fill ||
    !saw_sppr ||
    !geometry ||
    !stretch ||
    image_id == "" {
    return None
  }
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
  if kind == 2 && (x < 0.0 || y < 0.0 || width < 0.0 || height < 0.0) {
    return None
  }
  let rel = match self.package.target(part, image_id) {
    Some(rel) if !rel.external => rel
    _ => return None
  }
  let image = self.package.read(rel.target) catch { _ => return None }
  if !xlsx_picture_image_format(image) {
    return None
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
