///|
fn png_raw_profile(value : String) -> Bytes {
  let out = @buffer.Buffer()
  let mut high = -1
  let mut name_seen = false
  let mut length_seen = false
  for line in value.split("\n") {
    if !name_seen {
      if line.length() > 0 {
        name_seen = true
      }
      continue
    }
    if !length_seen {
      length_seen = true
      continue
    }
    for ch in line {
      if ch.is_whitespace() {
        continue
      }
      let c = ch.to_int()
      let digit = if c >= 48 && c <= 57 {
        c - 48
      } else if c >= 65 && c <= 70 {
        c - 55
      } else if c >= 97 && c <= 102 {
        c - 87
      } else {
        return out.to_bytes()
      }
      if high < 0 {
        high = digit
      } else {
        out.write_byte((high * 16 + digit).to_byte())
        high = -1
      }
    }
  }
  out.to_bytes()
}

///|
fn png_set_text(
  dc : Map[String, Array[String]],
  field : String,
  value : String,
) -> Unit {
  if dc.get(field) is None {
    xmp_add(dc, field, [value])
  }
}

///|
fn png_timestamp(data : Bytes) -> String {
  let year = jpeg_u16(data, 0)
  if year < 1 || year > 9999 {
    return ""
  }
  let padded = if year < 10 {
    "000\{year}"
  } else if year < 100 {
    "00\{year}"
  } else if year < 1000 {
    "0\{year}"
  } else {
    year.to_string()
  }
  xmp_date(
    "\{padded}-\{png_two(data[2].to_int())}-\{png_two(data[3].to_int())}T\{png_two(data[4].to_int())}:\{png_two(data[5].to_int())}:\{png_two(data[6].to_int())}Z",
  )
}

///|
fn read_png(data : Bytes) -> Picture raise {
  if data.length() < 33 || data[12:16] != b"IHDR"[:] {
    raise ImageFailure("image: PNG: the image is truncated")
  }
  let width = metadata_be32(data, 16)
  let height = metadata_be32(data, 20)
  let packets : Array[Bytes] = []
  let blocks : Array[Bytes] = []
  let native : Map[String, Array[String]] = Map([])
  let budget : PngTextBudget = { remaining: 16777216, }
  let mut comment = ""
  let mut animated = false
  let mut offset = 8
  while offset <= data.length() - 12 {
    let length64 = metadata_be32(data, offset)
    if length64 > (data.length() - offset - 12).to_int64() {
      break
    }
    let length = length64.to_int()
    let kind = data[offset + 4:offset + 8].to_bytes()
    let start = offset + 8
    let chunk = data[start:start + length]
    offset += 12 + length
    if kind == b"tEXt" || kind == b"zTXt" || kind == b"iTXt" {
      let name = if kind == b"tEXt" {
        "tEXt"
      } else if kind == b"zTXt" {
        "zTXt"
      } else {
        "iTXt"
      }
      match png_text(name, chunk, budget) {
        Some((key, value)) =>
          match key {
            "XML:com.adobe.xmp" => packets.push(@utf8.encode(value))
            "Raw profile type exif" | "Raw profile type APP1" => {
              let profile = png_raw_profile(value)
              if profile.length() >= 4 &&
                (
                  profile[:4] == b"Exif"[:] ||
                  profile[:4] == b"II\x2a\x00"[:] ||
                  profile[:4] == b"MM\x00\x2a"[:]
                ) {
                blocks.push(profile)
              }
            }
            "Raw profile type xmp" => packets.push(png_raw_profile(value))
            "Title" => png_set_text(native, "title", value)
            "Author" => png_set_text(native, "creator", value)
            "Description" => png_set_text(native, "description", value)
            "Comment" => if comment == "" { comment = xmp_clean(value) }
            "Copyright" => png_set_text(native, "rights", value)
            "Creation Time" =>
              png_set_text(native, "created", png_creation_date(value))
            _ => ()
          }
        None => ()
      }
    } else if kind == b"eXIf" {
      blocks.push(chunk.to_bytes())
    } else if kind == b"tIME" && length == 7 {
      png_set_text(native, "modified", png_timestamp(chunk.to_bytes()))
    } else if kind == b"acTL" {
      animated = length >= 4 && metadata_be32(data, start) > 1
    } else if kind == b"IEND" {
      break
    }
  }
  if native.get("description") is None && !xmp_placeholder(comment) {
    png_set_text(native, "description", comment)
  }
  let dc : Map[String, Array[String]] = Map([])
  for packet in packets {
    metadata_merge(dc, metadata_xmp(packet))
  }
  let mut orientation = 0
  for block in blocks {
    if exif_fields(block) is Some(fields) {
      metadata_merge(dc, exif_metadata(fields))
      if orientation == 0 {
        orientation = fields.orientation
      }
    }
  }
  metadata_merge(dc, native)
  if orientation >= 5 {
    { format: "png", width: height, height: width, dc, animated, warnings: [], }
  } else {
    { format: "png", width, height, dc, animated, warnings: [], }
  }
}
