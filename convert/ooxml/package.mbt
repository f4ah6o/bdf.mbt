///|
/// An Open Packaging Conventions package backed by a ZIP archive.
pub struct OoxmlPackage {
  archive : @zip.ZipArchive
  files : Map[String, @zip.ZipEntry]
}

///|
pub suberror OoxmlError {
  InvalidOoxml(String)
}

///|
fn ooxml_name(name : String, replace_backslashes : Bool) -> String {
  let out = StringBuilder()
  let mut first = true
  for source in name {
    let c = if replace_backslashes && source == '\\' { '/' } else { source }
    if first && c == '/' {
      first = false
      continue
    }
    first = false
    out.write_char(c)
  }
  out.to_string().to_lower()
}

///|
/// Open an OOXML ZIP directory, matching part names case-insensitively.
pub fn open_ooxml(data : Bytes) -> OoxmlPackage raise OoxmlError {
  let archive = @zip.open_zip(data) catch {
    @zip.InvalidZip(message) => raise InvalidOoxml(message)
  }
  let files : Map[String, @zip.ZipEntry] = Map([])
  for entry in archive.entries {
    files[ooxml_name(entry.name, true)] = entry
  }
  { archive, files, }
}

///|
/// Tell whether a package contains a part.
pub fn OoxmlPackage::has(self : OoxmlPackage, name : String) -> Bool {
  self.files.contains(ooxml_name(name, false))
}

///|
/// Return a part's uncompressed size if it exists.
pub fn OoxmlPackage::part_size(self : OoxmlPackage, name : String) -> Int32? {
  self.files.get(ooxml_name(name, false)).map(entry => entry.size)
}

///|
/// Read a package part, bounded at one GiB.
pub fn OoxmlPackage::read(
  self : OoxmlPackage,
  name : String,
) -> Bytes raise OoxmlError {
  let entry = match self.files.get(ooxml_name(name, false)) {
    Some(entry) => entry
    None => raise InvalidOoxml("missing part " + name)
  }
  if entry.size > 1073741824 {
    raise InvalidOoxml(name + ": part too large")
  }
  self.archive.read(entry, 1073741824) catch {
    @zip.InvalidZip(message) => raise InvalidOoxml(name + ": " + message)
  }
}

///|
/// A package relationship and its resolved target.
pub(all) struct OoxmlRelationship {
  id : String
  kind : String
  target : String
  external : Bool
}

///|
fn ooxml_clean(path : String) -> String {
  let parts : Array[String] = []
  for part in path.split("/") {
    let part = part.to_owned()
    if part == "" || part == "." {
      continue
    }
    if part == ".." {
      if !parts.is_empty() {
        ignore(parts.pop())
      }
    } else {
      parts.push(part)
    }
  }
  parts.join("/")
}

///|
/// Resolve a relationship target against its containing part directory.
pub fn resolve_ooxml_part(directory : String, target : String) -> String {
  if target.has_prefix("/") {
    ooxml_clean(target)
  } else {
    ooxml_clean("/" + directory + target)
  }
}

///|
fn ooxml_local(name : String) -> String {
  let mut local = ""
  for part in name.split(":") {
    local = part.to_owned()
  }
  local
}

///|
fn ooxml_part_directory(part : String) -> (String, String) {
  let data = @utf8.encode(part)
  let mut i = data.length() - 1
  while i >= 0 && data[i] != b'/' {
    i -= 1
  }
  (@utf8.decode_lossy(data[:i + 1]), @utf8.decode_lossy(data[i + 1:]))
}

///|
/// Read the relationships of a package part; invalid or absent parts are empty.
pub fn OoxmlPackage::relationships(
  self : OoxmlPackage,
  source : String,
) -> Array[OoxmlRelationship] {
  let source = if source.has_prefix("/") {
    source[1:].to_owned()
  } else {
    source
  }
  let (directory, base) = ooxml_part_directory(source)
  let bytes = self.read(directory + "_rels/" + base + ".rels") catch {
    _ => return []
  }
  let reader = @xml.Reader::from_string(
    @utf8.decode_lossy(bytes[:], ignore_bom=true),
  )
  let result : Array[OoxmlRelationship] = []
  let mut depth = 0
  while true {
    let event = reader.read_event() catch { _ => return [] }
    match event.kind {
      Start(element) | Empty(element) => {
        if depth == 1 && ooxml_local(element.name) == "Relationship" {
          let mut id = ""
          let mut kind = ""
          let mut target = ""
          let mut external = false
          for attr in element.attributes {
            match ooxml_local(attr.name) {
              "Id" => id = attr.value
              "Type" => kind = attr.value
              "Target" => target = attr.value
              "TargetMode" => external = attr.value.to_lower() == "external"
              _ => ()
            }
          }
          let relationship : OoxmlRelationship = {
            id,
            kind,
            target: if external {
              target
            } else {
              resolve_ooxml_part(directory, target)
            },
            external,
          }
          let mut replaced = false
          for i in 0..<result.length() {
            if result[i].id == id {
              result[i] = relationship
              replaced = true
              break
            }
          }
          if !replaced {
            result.push(relationship)
          }
        }
        if event.kind is Start(_) {
          depth += 1
        }
      }
      End(_) => depth -= 1
      Eof => break
      _ => ()
    }
  }
  result
}

///|
fn ooxml_id_less(a : String, b : String) -> Bool {
  let left = @utf8.encode(a)
  let right = @utf8.encode(b)
  if left.length() != right.length() {
    return left.length() < right.length()
  }
  for i in 0..<left.length() {
    if left[i] != right[i] {
      return left[i] < right[i]
    }
  }
  false
}

///|
/// Resolve a relationship by ID when it has a nonempty target.
pub fn OoxmlPackage::target(
  self : OoxmlPackage,
  source : String,
  id : String,
) -> OoxmlRelationship? {
  for relationship in self.relationships(source) {
    if relationship.id == id && relationship.target != "" {
      return Some(relationship)
    }
  }
  None
}

///|
/// Find the first relationship of a given type suffix, ordered by ID.
pub fn OoxmlPackage::relationship_of_type(
  self : OoxmlPackage,
  source : String,
  suffix : String,
) -> OoxmlRelationship? {
  let mut best : OoxmlRelationship? = None
  for relationship in self.relationships(source) {
    if !relationship.kind.has_suffix(suffix) {
      continue
    }
    match best {
      None => best = Some(relationship)
      Some(previous) =>
        if ooxml_id_less(relationship.id, previous.id) {
          best = Some(relationship)
        }
    }
  }
  best
}
