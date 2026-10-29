///|
/// One MML track before interpretation; kind identifies its PPMCK chip.
pub(all) struct MmlTrackSource {
  name : String
  text : String
  kind : Int32
}

///|
/// MML metadata, track sources and preprocessing warnings.
pub(all) struct MmlSource {
  mut title : String
  mut composer : String
  mut arranger : String
  mut lyricist : String
  mut copyright : String
  mut reverse : Bool
  tracks : Array[MmlTrackSource]
  warnings : Array[String]
  seen : Map[String, Bool]
}

///|
fn mml_source_new() -> MmlSource {
  {
    title: "",
    composer: "",
    arranger: "",
    lyricist: "",
    copyright: "",
    reverse: false,
    tracks: [],
    warnings: [],
    seen: Map([]),
  }
}

///|
fn MmlSource::warn(self : MmlSource, key : String, message : String) -> Unit {
  if !self.seen.contains(key) {
    self.seen[key] = true
    self.warnings.push(message)
  }
}

///|
fn MmlSource::header(self : MmlSource, line : String) -> Unit {
  let bytes = @utf8.encode(line)
  let mut end = 0
  while end < bytes.length() && bytes[end] != b' ' && bytes[end] != b'\t' {
    end += 1
  }
  let name = @utf8.decode_lossy(bytes[:end]).to_upper()
  let mut value = mml_trim(@utf8.decode_lossy(bytes[end:]))
  if value.length() >= 2 && value.has_prefix("\"") && value.has_suffix("\"") {
    value = value[1:value.length() - 1].to_owned()
  }
  match name {
    "#TITLE" => if self.title == "" { self.title = value }
    "#COMPOSER" | "#ARTIST" => if self.composer == "" { self.composer = value }
    "#ARRANGER" | "#CODING" | "#PROGRAMER" | "#PROGRAMMER" =>
      if self.arranger == "" {
        self.arranger = value
      }
    "#LYRICIST" => if self.lyricist == "" { self.lyricist = value }
    "#MAKER" | "#COPYRIGHT" =>
      if self.copyright == "" {
        self.copyright = value
      }
    "#OCTAVE-REV" => self.reverse = value != "0"
    "#INCLUDE" => self.warn("include", "#INCLUDE " + value + " is not read")
    _ => ()
  }
}

///|
/// Remove MML comments, leaving header lines intact.
pub fn strip_mml_comments(text : String, semicolon : Bool) -> String {
  let bytes = @utf8.encode(text)
  let out : Array[Byte] = []
  let mut line_start = true
  let mut i = 0
  while i < bytes.length() {
    if line_start {
      let mut j = i
      while j < bytes.length() && (bytes[j] == b' ' || bytes[j] == b'\t') {
        j += 1
      }
      if j < bytes.length() && bytes[j] == b'#' {
        while i < bytes.length() && bytes[i] != b'\n' {
          out.push(bytes[i])
          i += 1
        }
        line_start = false
        continue
      }
    }
    line_start = false
    if bytes[i] == b'\n' {
      line_start = true
      out.push(bytes[i])
      i += 1
      continue
    }
    if i + 1 < bytes.length() && bytes[i] == b'/' && bytes[i + 1] == b'*' {
      i += 2
      while i + 1 < bytes.length() &&
            !(bytes[i] == b'*' && bytes[i + 1] == b'/') {
        i += 1
      }
      i = if i + 1 < bytes.length() { i + 2 } else { bytes.length() }
      out.push(b' ')
    } else if (semicolon && bytes[i] == b';') ||
      (
        i + 1 < bytes.length() &&
        bytes[i] == b'/' &&
        bytes[i + 1] == b'/' &&
        (i == 0 || bytes[i - 1] != b':') &&
        !(i + 2 < bytes.length() && bytes[i + 2] == b':')
      ) {
      while i < bytes.length() && bytes[i] != b'\n' {
        i += 1
      }
    } else {
      out.push(bytes[i])
      i += 1
    }
  }
  @utf8.decode_lossy(Bytes::from_array(out)[:])
}

///|
fn mml_braces(text : String) -> (Int32, Bool) {
  let mut count = 0
  let mut opened = false
  for c in text {
    if c == '{' {
      count += 1
      opened = true
    } else if c == '}' {
      count -= 1
    }
  }
  (count, opened)
}

///|
fn mml_split_generic(text : String, source : MmlSource) -> Unit {
  let body = StringBuilder()
  let mut braces = 0
  for line in strip_mml_comments(text, false).split("\n") {
    let line = line.to_owned()
    let t = mml_trim(line)
    if braces > 0 {
      braces += mml_braces(t).0
      continue
    }
    if t.has_prefix("#") {
      source.header(t)
      let mut name = ""
      for item in t.split(" ") {
        name = item.to_owned()
        break
      }
      if name.contains("@") {
        braces = Int32::max(mml_braces(t).0, 0)
      }
      continue
    }
    body.write_string(line)
    body.write_char('\n')
  }
  let macros : MmlMacros = { defs: Map([]), total: 0L, source, }
  for segment in body.to_string().split(";") {
    let segment = segment.to_owned()
    let trimmed = mml_trim(segment)
    if trimmed == "" {
      continue
    }
    let (definition, name, value) = mml_macro_definition(trimmed, source)
    if definition {
      if name != "" {
        macros.defs[name] = macros.expand(value)
      }
      continue
    }
    let expanded = macros.expand(segment)
    if mml_trim(expanded) != "" {
      source.tracks.push({ name: "", text: expanded, kind: 0, })
    }
  }
}

///|
fn mml_split_mabinogi(text : String, source : MmlSource) -> Unit {
  let data = @utf8.encode(text)
  let blocks : Array[Array[String]] = []
  let mut i = mml_mabinogi_at(text)
  while i >= 0 {
    i += 4
    let next = mml_mabinogi_at(text, start=i)
    let mut end = if next < 0 { data.length() } else { next }
    for j in i..<end {
      if data[j] == b';' {
        end = j
        break
      }
    }
    let content = @utf8.decode_lossy(data[i:end])
    blocks.push([ for part in content.split(",") => part.to_owned() ])
    i = next
  }
  for bi, block in blocks {
    for pi, track in block {
      let mut name = if pi == 0 { "Melody" } else { "Chord " + pi.to_string() }
      if blocks.length() > 1 {
        name += " (" + (bi + 1).to_string() + ")"
      }
      source.tracks.push({ name, text: track, kind: 0, })
    }
  }
}

///|
fn mml_split_ppmck(text : String, source : MmlSource) -> Unit {
  let buffers : Array[StringBuilder] = [ for _ in 0..<26 => StringBuilder() ]
  let used : Array[Bool] = [ for _ in 0..<26 => false ]
  let mut previous : Array[Int32] = []
  let mut in_definition = false
  let mut braces = 0
  let mut opened = false
  let mut total = 0L
  for line in strip_mml_comments(text, true).split("\n") {
    let line = line.to_owned()
    let t = mml_trim(line)
    if in_definition {
      if !opened && t != "" && !t.has_prefix("{") {
        in_definition = false
      } else {
        let (delta, has_open) = mml_braces(t)
        braces += delta
        opened = opened || has_open
        in_definition = !opened || braces > 0
        continue
      }
    }
    if t == "" {
      continue
    }
    if t.has_prefix("#") {
      source.header(t)
      continue
    }
    if t.has_prefix("@") {
      let (delta, has_open) = mml_braces(t)
      braces = delta
      opened = has_open
      in_definition = !opened || braces > 0
      continue
    }
    let bytes = @utf8.encode(line)
    let mut n = 0
    while n < bytes.length() && bytes[n] >= b'A' && bytes[n] <= b'Z' {
      n += 1
    }
    let names = n > 0 &&
      n <= 26 &&
      (n == bytes.length() || bytes[n] == b' ' || bytes[n] == b'\t')
    let rest = if names {
      previous = [ for i in 0..<n => bytes[i].to_int() - 65 ]
      @utf8.decode_lossy(bytes[n:])
    } else if bytes[0] == b' ' || bytes[0] == b'\t' {
      line
    } else {
      source.warn("no-track", "lines that start with no track name are skipped")
      continue
    }
    for index in previous {
      total += @utf8.encode(rest).length().to_int64() + 1L
      if total > 16777216L {
        source.warn(
          "ppmck-size", "the tracks hold more than 16 MiB of MML; the rest is left out",
        )
        break
      }
      buffers[index].write_string(rest)
      buffers[index].write_char('\n')
      used[index] = true
    }
  }
  for i in 0..<26 {
    if !used[i] {
      continue
    }
    let kind = match i {
      0 | 1 => 1
      2 => 2
      3 => 3
      4 => 4
      _ => 5
    }
    let name = (i + 65).unsafe_to_char().to_string()
    source.tracks.push({ name, text: buffers[i].to_string(), kind, })
  }
}

///|
/// Split decoded MML into tracks and read headers for the selected dialect.
/// Passing an empty dialect chooses it from the text.
pub fn split_mml_source(text : String, dialect : String) -> MmlSource {
  let source = mml_source_new()
  let chosen = if dialect == "" || dialect == "auto" {
    detect_mml_dialect(text)
  } else {
    dialect
  }
  match chosen {
    "mabinogi" => mml_split_mabinogi(text, source)
    "ppmck" => mml_split_ppmck(text, source)
    _ => mml_split_generic(text, source)
  }
  source
}
