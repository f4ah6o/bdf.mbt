///|
struct XmpState {
  dc : Map[String, Array[String]]
  tiff : Map[String, Array[String]]
  created : Array[String]
  digitized : Array[String]
}

///|
fn xmp_clean(value : String) -> String {
  xmp_trim_space(value.trim(chars="\x00").to_string())
}

///|
fn xmp_add(
  dc : Map[String, Array[String]],
  field : String,
  values : Array[String],
) -> Unit {
  for raw in values {
    let value = xmp_clean(raw)
    if value == "" {
      continue
    }
    match dc.get(field) {
      Some(existing) => existing.push(value)
      None => dc[field] = [value]
    }
  }
}

///|
fn xmp_dates(values : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for value in values {
    let date = xmp_date(value)
    if date != "" {
      out.push(date)
    }
  }
  out
}

///|
fn xmp_first(values : Array[String]) -> Array[String] {
  if values.length() == 0 {
    []
  } else {
    [values[0]]
  }
}

///|
fn XmpState::property(
  self : XmpState,
  space : String,
  name : String,
  values : Array[String],
) -> Unit {
  if space == xmp_dc {
    match name {
      "title" | "description" | "rights" =>
        xmp_add(self.dc, name, xmp_first(values))
      "date" => xmp_add(self.dc, name, xmp_dates(values))
      "creator"
      | "subject"
      | "publisher"
      | "contributor"
      | "type"
      | "format"
      | "identifier"
      | "source"
      | "language"
      | "relation"
      | "coverage" => xmp_add(self.dc, name, values)
      _ => ()
    }
  } else if space == "http://purl.org/dc/terms/" {
    if name == "created" || name == "modified" {
      xmp_add(self.dc, name, xmp_dates(values))
    }
  } else if space == "http://ns.adobe.com/photoshop/1.0/" {
    if name == "DateCreated" {
      for value in values {
        self.created.push(value)
      }
    }
  } else if space == "http://ns.adobe.com/exif/1.0/" {
    if name == "DateTimeOriginal" {
      for value in values {
        self.created.push(value)
      }
    }
    if name == "DateTimeDigitized" {
      for value in values {
        self.digitized.push(value)
      }
    }
  } else if space == "http://ns.adobe.com/xap/1.0/" {
    if name == "CreateDate" {
      for value in values {
        self.digitized.push(value)
      }
    }
    if name == "ModifyDate" {
      xmp_add(self.dc, "modified", xmp_dates(values))
    }
  } else if space == "http://ns.adobe.com/tiff/1.0/" {
    match name {
      "ImageDescription" => xmp_add(self.tiff, "description", xmp_first(values))
      "Copyright" => xmp_add(self.tiff, "rights", xmp_first(values))
      "DateTime" => xmp_add(self.tiff, "modified", xmp_dates(values))
      "Artist" =>
        for value in values {
          for part in value.split(";") {
            xmp_add(self.tiff, "creator", [part.to_string()])
          }
        }
      _ => ()
    }
  }
}

///|
fn xmp_placeholder(value : String) -> Bool {
  match xmp_collapse(value).to_upper() {
    ""
    | "OLYMPUS DIGITAL CAMERA"
    | "SONY DSC"
    | "DIGITAL CAMERA"
    | "SAMSUNG DIGITAL CAMERA"
    | "MINOLTA DIGITAL CAMERA"
    | "KONICA MINOLTA DIGITAL CAMERA"
    | "KODAK DIGITAL STILL CAMERA"
    | "EXIF_JPEG_PICTURE"
    | "DEFAULT" => true
    _ => false
  }
}

///|
fn XmpState::walk(self : XmpState, node : XmpNode) -> Unit {
  if !node.is_name(xmp_rdf, "RDF") {
    for child in node.children {
      self.walk(child)
    }
    return
  }
  for description in node.children {
    for attribute in description.attributes {
      if attribute.space != xmp_rdf &&
        attribute.space != xmp_xml &&
        attribute.space != "xmlns" {
        self.property(attribute.space, attribute.name, [attribute.value])
      }
    }
    for property in description.children {
      self.property(property.space, property.name, xmp_values(property))
    }
  }
}

///|
fn xmp_metadata(root : XmpNode) -> Map[String, Array[String]] {
  let state : XmpState = {
    dc: Map([]),
    tiff: Map([]),
    created: [],
    digitized: [],
  }
  state.walk(root)
  if state.dc.get("created") is None {
    let original = xmp_first(xmp_dates(state.created))
    let created = if original.length() > 0 {
      original
    } else {
      xmp_first(xmp_dates(state.digitized))
    }
    xmp_add(state.dc, "created", created)
  }
  for fields in [state.dc, state.tiff] {
    match fields.get("description") {
      Some(values) if values.length() > 0 && xmp_placeholder(values[0]) =>
        fields.remove("description")
      _ => ()
    }
  }
  for key, values in state.tiff {
    if state.dc.get(key) is None {
      state.dc[key] = values
    }
  }
  state.dc
}
