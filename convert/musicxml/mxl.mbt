///|
pub suberror MusicXmlInputError {
  InvalidMusicXmlInput(String)
}

///|
priv struct MusicXmlRoot {
  path : String
  media_type : String
}

///|
fn musicxml_clean_path(path : String) -> String {
  let components : Array[String] = []
  let normalized = StringBuilder()
  for c in path {
    normalized.write_char(if c == '\\' { '/' } else { c })
  }
  for component in normalized.to_string().split("/") {
    let part = component.to_owned()
    if part == "" || part == "." {
      continue
    }
    if part == ".." {
      if !components.is_empty() {
        ignore(components.pop())
      }
    } else {
      components.push(part)
    }
  }
  components.join("/")
}

///|
fn musicxml_score_path(path : String) -> Bool {
  let lower = path.to_lower()
  lower.has_suffix(".xml") || lower.has_suffix(".musicxml")
}

///|
fn musicxml_zip_entry(
  archive : @zip.ZipArchive,
  path : String,
) -> @zip.ZipEntry? {
  let target = musicxml_clean_path(path)
  for entry in archive.entries {
    if musicxml_clean_path(entry.name) == target {
      return Some(entry)
    }
  }
  None
}

///|
fn musicxml_trim(value : String) -> String {
  let output = StringBuilder()
  let pending = StringBuilder()
  let mut started = false
  for c in value {
    if c.is_whitespace() {
      if started {
        pending.write_char(c)
      }
    } else {
      if started {
        output.write_string(pending.to_string())
        pending.reset()
      }
      output.write_char(c)
      started = true
    }
  }
  output.to_string()
}

///|
fn musicxml_container_roots(data : Bytes) -> (Array[MusicXmlRoot], Bool) {
  let roots : Array[MusicXmlRoot] = []
  let (prepared, _) = musicxml_to_utf8(data)
  let text = @utf8.decode_lossy(prepared[:])
  let reader = @xml.Reader::from_string(text)
  let mut depth = 0
  while true {
    let event = reader.read_event() catch {
      @xml.At(error=@xml.InvalidSyntax(message), span~) => {
        let offset = span.start.offset
        if depth == 0 &&
          (
            message == "content after root element" ||
            message == "character reference after root element"
          ) &&
          (offset >= text.length() || text[offset] != 60) {
          return (roots, true)
        }
        return (roots, false)
      }
      _ => return (roots, false)
    }
    match event.kind {
      Start(element) | Empty(element) => {
        let mut local = ""
        for name in element.name.split(":") {
          local = name.to_owned()
        }
        if event.kind is Start(_) {
          depth += 1
        }
        if local == "rootfile" {
          let mut path = ""
          let mut media_type = ""
          for attribute in element.attributes {
            let mut name = ""
            for part in attribute.name.split(":") {
              name = part.to_owned()
            }
            if name == "full-path" {
              path = attribute.value
            } else if name == "media-type" {
              media_type = musicxml_trim(attribute.value)
            }
          }
          if path != "" {
            roots.push({ path, media_type, })
          }
        }
      }
      End(_) => depth -= 1
      Eof => return (roots, true)
      _ => ()
    }
  }
  (roots, true)
}

///|
fn musicxml_mxl_roots(archive : @zip.ZipArchive) -> (Array[MusicXmlRoot], Bool) {
  match musicxml_zip_entry(archive, "META-INF/container.xml") {
    None => ([], true)
    Some(entry) => {
      if entry.size > 1048576 {
        return ([], true)
      }
      let data = archive.read(entry, 1048576) catch { _ => return ([], false) }
      musicxml_container_roots(data)
    }
  }
}

///|
fn musicxml_mxl_magic(head : Bytes) -> Bool {
  if head.length() < 30 {
    return false
  }
  let n = head[26].to_int() | (head[27].to_int() << 8)
  let extra = head[28].to_int() | (head[29].to_int() << 8)
  if n != 8 || 30 + n > head.length() || head[30:38] != b"mimetype"[:] {
    return false
  }
  let start = Int32::min(30 + n + extra, head.length())
  let mime = b"application/vnd.recordare.musicxml"
  if mime.length() > head.length() - start {
    return false
  }
  for i in 0..<mime.length() {
    if head[start + i] != mime[i] {
      return false
    }
  }
  true
}

///|
/// Detect MusicXML from a prefix and complete archive bytes.
pub fn detect_musicxml(head : Bytes, data : Bytes) -> Bool {
  if !head.has_prefix(b"PK\x03\x04") {
    return detect_musicxml_text(head)
  }
  if musicxml_mxl_magic(head) {
    return true
  }
  let archive = @zip.open_zip(data) catch { _ => return false }
  let (roots, valid) = musicxml_mxl_roots(archive)
  if !valid {
    return false
  }
  for root in roots {
    if root.media_type == "application/vnd.recordare.musicxml+xml" {
      return true
    }
    if root.media_type == "" && musicxml_score_path(root.path) {
      match musicxml_zip_entry(archive, root.path) {
        None => ()
        Some(entry) => {
          let head = archive.read_prefix(entry, 1024) catch { _ => continue }
          if detect_musicxml_text(head) {
            return true
          }
        }
      }
    }
  }
  false
}

///|
/// Read an uncompressed score or select and expand one from an MXL archive.
pub fn read_musicxml_input(data : Bytes) -> Bytes raise MusicXmlInputError {
  if !data.has_prefix(b"PK\x03\x04") {
    if data.length() > 67108864 {
      raise InvalidMusicXmlInput("musicxml: the file is larger than 64 MiB")
    }
    return data
  }
  let archive = @zip.open_zip(data) catch {
    _ =>
      raise InvalidMusicXmlInput(
        "musicxml: compressed file: zip: not a valid zip file",
      )
  }
  let (roots, _) = musicxml_mxl_roots(archive)
  let mut selected : @zip.ZipEntry? = None
  for root in roots {
    if root.media_type == "application/vnd.recordare.musicxml+xml" ||
      (root.media_type == "" && musicxml_score_path(root.path)) {
      match musicxml_zip_entry(archive, root.path) {
        Some(entry) => {
          selected = Some(entry)
          break
        }
        None => ()
      }
    }
  }
  if selected is None {
    for entry in archive.entries {
      let name = musicxml_clean_path(entry.name)
      if !name.has_prefix("META-INF/") && musicxml_score_path(name) {
        selected = Some(entry)
        break
      }
    }
  }
  let entry = match selected {
    Some(entry) => entry
    None =>
      raise InvalidMusicXmlInput("musicxml: the compressed file holds no score")
  }
  if entry.size > 67108864 {
    raise InvalidMusicXmlInput("musicxml: the score is larger than 64 MiB")
  }
  archive.read(entry, 67108864) catch {
    @zip.InvalidZip(error) =>
      raise InvalidMusicXmlInput("musicxml: " + entry.name + ": " + error)
  }
}
