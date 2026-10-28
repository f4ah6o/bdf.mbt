///|
fn exif_value(fields : Map[Int32, Bytes], tag : Int32) -> Bytes {
  fields.get(tag).unwrap_or(b"")
}

///|
fn exif_user_comment(data : Bytes, little : Bool) -> String {
  if data.length() < 8 {
    return ""
  }
  if data[:8] == b"ASCII\x00\x00\x00"[:] {
    metadata_text(data[8:].to_bytes())
  } else if data[:8] == b"UNICODE\x00"[:] {
    metadata_utf16(data[8:].to_bytes(), little)
  } else {
    ""
  }
}

///|
fn exif_list(value : String) -> Array[String] {
  let result : Array[String] = []
  for part in value.split(";") {
    let item = xmp_clean(part.to_string())
    if item != "" {
      result.push(item)
    }
  }
  result
}

///|
fn exif_metadata(fields : ExifFields) -> Map[String, Array[String]] {
  let dc : Map[String, Array[String]] = Map([])
  let primary = fields.primary
  let extra = fields.exif
  xmp_add(dc, "title", [metadata_utf16(exif_value(primary, 0x9c9b), true)])
  let artist = exif_list(metadata_text(exif_value(primary, 0x013b)))
  let creator = if artist.length() > 0 {
    artist
  } else {
    exif_list(metadata_utf16(exif_value(primary, 0x9c9d), true))
  }
  xmp_add(dc, "creator", creator)
  xmp_add(
    dc,
    "subject",
    exif_list(metadata_utf16(exif_value(primary, 0x9c9e), true)),
  )
  for
    description in [
      metadata_text(exif_value(primary, 0x010e)),
      metadata_utf16(exif_value(primary, 0x9c9f), true),
      metadata_utf16(exif_value(primary, 0x9c9c), true),
      exif_user_comment(exif_value(extra, 0x9286), fields.little),
    ] {
    if !xmp_placeholder(description) {
      xmp_add(dc, "description", [description])
      break
    }
  }
  let copyright = exif_value(primary, 0x8298)
  let mut start = 0
  for i in 0..<=copyright.length() {
    if i == copyright.length() || copyright[i] == 0 {
      xmp_add(dc, "rights", [metadata_text(copyright[start:i].to_bytes())])
      start = i + 1
    }
  }
  let original = metadata_exif_date(
    metadata_text(exif_value(extra, 0x9003)),
    metadata_text(exif_value(extra, 0x9011)),
  )
  let created = if original != "" {
    original
  } else {
    metadata_exif_date(
      metadata_text(exif_value(extra, 0x9004)),
      metadata_text(exif_value(extra, 0x9012)),
    )
  }
  xmp_add(dc, "created", [created])
  xmp_add(dc, "modified", [
    metadata_exif_date(
      metadata_text(exif_value(primary, 0x0132)),
      metadata_text(exif_value(extra, 0x9010)),
    ),
  ])
  dc
}
