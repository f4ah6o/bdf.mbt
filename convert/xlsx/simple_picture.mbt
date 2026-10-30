///|
// Read plain, untransformed embedded pictures. Other drawing features
// remain unsupported until their rendering and relationship semantics exist.
fn XlsxWorkbook::xlsx_simple_picture(
  self : XlsxWorkbook,
  part : String,
) -> Array[@sheet.GridPicture]? {
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
  let result : Array[@sheet.GridPicture] = []
  let images : Map[String, Bytes] = Map([])
  let mut image_bytes = 0L
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
          let name = parents[3]
          let raw = match xlsx_int(xlsx_trim(text.to_string())) {
            Some(value) if value >= 0L && value <= 254000000L => value
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
          } else if raw > 16383L {
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
            !saw_nv ||
            !saw_nvpr ||
            !saw_blip_fill ||
            !saw_sppr ||
            !geometry ||
            !stretch ||
            image_id == "" {
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
              description,
              title,
              images,
              1073741824L - image_bytes,
            ) {
            Some(picture) => {
              image_bytes += picture.image.length().to_int64()
              if image_bytes > 1073741824L {
                return None
              }
              result.push(picture)
            }
            None => return None
          }
          kind = -1
          pictures = 0
          saw_from = false
          saw_to = false
          saw_nv = false
          saw_nvpr = false
          saw_blip_fill = false
          saw_sppr = false
          geometry = false
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
  description : String,
  title : String,
  images : Map[String, Bytes],
  remaining_bytes : Int64,
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
  if kind == 2 && (x < 0.0 || y < 0.0 || width < 0.0 || height < 0.0) {
    return None
  }
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
  // Go has no AVIF image.DecodeConfig registration, so it draws the full
  // image when a crop is present but intrinsic dimensions are unavailable.
  let crop_ignored = image.length() >= 12 &&
    image[4:8] == b"ftyp"[:] &&
    (image[8:12] == b"avif"[:] || image[8:12] == b"avis"[:])
  let crop_left = if crop_ignored { 0.0 } else { crop_left }
  let crop_top = if crop_ignored { 0.0 } else { crop_top }
  let crop_right = if crop_ignored { 0.0 } else { crop_right }
  let crop_bottom = if crop_ignored { 0.0 } else { crop_bottom }
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
        let mut width : Int64? = None
        let mut height : Int64? = None
        for attr in element.attributes {
          if attr.name.namespace_uri is None &&
            (
              attr.name.local_name == "width" ||
              attr.name.local_name == "height"
            ) {
            let value = match xlsx_int(xlsx_trim(attr.value)) {
              Some(value) if value > 0L && value <= 1000000L => value
              _ => return None
            }
            if attr.name.local_name == "width" {
              if width is Some(_) {
                return None
              }
              width = Some(value)
            } else {
              if height is Some(_) {
                return None
              }
              height = Some(value)
            }
          }
        }
        return match (width, height) {
          (Some(w), Some(h)) => Some((w.to_double(), h.to_double()))
          _ => None
        }
      }
      End(_) | Eof => return None
      _ => ()
    }
  }
  None
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
