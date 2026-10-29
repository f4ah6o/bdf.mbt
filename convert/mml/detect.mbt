///|
fn mml_trim(text : String) -> String {
  let output = StringBuilder()
  let pending = StringBuilder()
  let mut started = false
  for c in text {
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
fn mml_letter(c : Int32) -> Bool {
  (c >= 65 && c <= 90) || (c >= 97 && c <= 122)
}

///|
fn mml_digit(c : Int32) -> Bool {
  c >= 48 && c <= 57
}

///|
fn mml_ident(c : Int32) -> Bool {
  c == 95 || mml_digit(c) || mml_letter(c)
}

///|
fn mml_has_char(text : String, c : Int32) -> Bool {
  for v in text {
    if v.to_int() == c {
      return true
    }
  }
  false
}

///|
/// Report whether text consists of MML syntax and count numbered commands and notes.
pub fn mml_like(text : String) -> (Bool, Int32, Int32) {
  let data = @utf8.encode(text)
  let mut tokens = 0
  let mut notes = 0
  for i in 0..<data.length() {
    let c = data[i].to_int()
    if (c >= 97 && c <= 103) || (c >= 65 && c <= 71) {
      notes += 1
    } else if mml_digit(c) ||
      c == 32 ||
      c == 9 ||
      mml_has_char("<>[]{}&^.+-#|:/%,@;$=()_!", c) ||
      mml_has_char("rolnqtvkswxypRLOMNPQTVKSWXY", c) {
      ()
    } else {
      return (false, 0, 0)
    }
    if i + 1 < data.length() &&
      mml_digit(data[i + 1].to_int()) &&
      mml_has_char("abcdefgrlotvnq@ABCDEFGRLOTVNQ", c) {
      tokens += 1
    }
  }
  (true, tokens, notes)
}

///|
fn mml_header_dialect(text : String) -> String {
  let mut name = ""
  for segment in text.to_upper().split(" ") {
    name = segment.to_owned()
    break
  }
  for segment in name.split("\t") {
    name = segment.to_owned()
    break
  }
  if [
      "#COMPOSER", "#MAKER", "#PROGRAMER", "#PROGRAMMER", "#OCTAVE-REV", "#INCLUDE",
      "#BANK-CHANGE", "#SETBANK", "#EFFECT-INCLUDE", "#DPCM-RESTSTOP", "#GATE-DENOM",
      "#PITCH-CORRECTION", "#AUTO-BANKSWITCH", "#NO-BANKSWITCH",
    ].contains(name) ||
    name.has_prefix("#EX-") {
    "ppmck"
  } else if [
      "#ARTIST", "#CODING", "#COMMENT", "#OCTAVE", "#VELOCITY", "#FMGAIN", "#USING",
      "#PRAGMA",
    ].contains(name) ||
    name.has_prefix("#WAV") ||
    name.has_prefix("#OPM@") ||
    name.has_prefix("#OPN@") {
    "generic"
  } else {
    ""
  }
}

///|
fn mml_definition(text : String) -> Bool {
  let b = @utf8.encode(text)
  if b.length() < 2 || b[0] != b'@' {
    return false
  }
  let mut i = 1
  while i < b.length() && mml_letter(b[i].to_int()) && i < 8 {
    i += 1
  }
  let start = i
  while i < b.length() && mml_digit(b[i].to_int()) {
    i += 1
  }
  if i == start {
    return false
  }
  while i < b.length() && (b[i] == b' ' || b[i] == b'\t') {
    i += 1
  }
  i < b.length() && b[i] == b'='
}

///|
fn mml_track_line(text : String) -> Bool {
  let data = @utf8.encode(text)
  let mut i = 0
  while i < data.length() && data[i] >= b'A' && data[i] <= b'Z' {
    i += 1
  }
  if i == 0 ||
    i > 26 ||
    (i < data.length() && data[i] != b' ' && data[i] != b'\t') {
    return false
  }
  let start = i
  while i < data.length() && data[i] != b';' {
    i += 1
  }
  let (ok, tokens, _) = mml_like(@utf8.decode_lossy(data[start:i]))
  ok && tokens >= 1
}

///|
fn mml_mabinogi_at(text : String, start~ : Int32 = 0) -> Int32 {
  let data = @utf8.encode(text)
  let mut i = start
  while i + 4 <= data.length() {
    let is_match = (data[i].to_int() | 32) == 109 &&
      (data[i + 1].to_int() | 32) == 109 &&
      (data[i + 2].to_int() | 32) == 108 &&
      data[i + 3] == b'@'
    if is_match {
      let start = i + 4
      let mut end = Int32::min(data.length(), start + 32)
      for j in start..<end {
        if data[j] == b',' || data[j] == b';' || data[j] == b'\n' {
          end = j
          break
        }
      }
      let (ok, _, _) = mml_like(@utf8.decode_lossy(data[start:end]))
      if ok &&
        (
          i == 0 ||
          (
            !mml_ident(data[i - 1].to_int()) &&
            data[i - 1] != b'.' &&
            data[i - 1] != b'-'
          )
        ) {
        return i
      }
    }
    i += 1
  }
  -1
}

///|
/// Detect the MML dialect from decoded text.
pub fn detect_mml_dialect(text : String) -> String {
  if mml_mabinogi_at(text) >= 0 {
    return "mabinogi"
  }
  let mut ppmck = 0
  let mut generic = 0
  let mut tracks = 0
  let mut others = 0
  for line in text.split("\n") {
    let line = line.to_owned()
    let t = mml_trim(line)
    if t == "" || t.has_prefix(";") || t.has_prefix("//") || t.has_prefix("/*") {
      continue
    }
    if t.has_prefix("#") {
      match mml_header_dialect(t) {
        "ppmck" => ppmck += 1
        "generic" => generic += 1
        _ => ()
      }
    } else if mml_definition(t) {
      ppmck += 1
    } else if mml_track_line(line) {
      tracks += 1
    } else {
      others += 1
    }
  }
  if ppmck > generic || (generic == 0 && tracks >= 2 && tracks >= others) {
    "ppmck"
  } else {
    "generic"
  }
}

///|
/// Detect recognizable MML content from an input header (up to 1024 bytes).
pub fn detect_mml(head : Bytes) -> Bool {
  let mut start = 0
  if head.has_prefix(b"\xef\xbb\xbf") {
    start = 3
  }
  if start == head.length() {
    return false
  }
  for b in head[start:] {
    if b == 0 {
      return false
    }
  }
  let builder = StringBuilder()
  for c in @utf8.decode_lossy(head[start:]) {
    builder.write_char(if c == '\r' { '\n' } else { c })
  }
  let text = builder.to_string()
  let mut mabinogi = false
  let mut fence = false
  let mut headers = 0
  let mut defs = 0
  let mut tracks = 0
  let mut lines = 0
  for line in text.split("\n") {
    let line = line.to_owned()
    let t = mml_trim(line)
    if t == "" {
      continue
    }
    if t.has_prefix("```") || t.has_prefix("~~~") {
      fence = true
    } else if t.length() > 4 && t[:4].to_owned().to_lower() == "mml@" {
      let data = @utf8.encode(t)
      let (ok, tokens, _) = mml_like(
        @utf8.decode_lossy(data[4:Int32::min(data.length(), 68)]),
      )
      if ok && tokens >= 1 {
        mabinogi = true
      }
    } else if t.has_prefix("#") {
      let replaced = t.replace(old="\t", new=" ")
      let mut name = ""
      for segment in replaced.split(" ") {
        name = segment.to_owned()
        break
      }
      if name == name.to_upper() &&
        (name == "#TITLE" || mml_header_dialect(name) != "") {
        headers += 1
      }
    } else if mml_definition(t) {
      defs += 1
    } else if mml_track_line(line) {
      tracks += 1
    } else {
      let mut before = t
      for segment in t.split("//") {
        before = segment.to_owned()
        break
      }
      let (ok, tokens, notes) = mml_like(before)
      if ok && tokens >= 1 && tokens + notes >= 3 {
        lines += 1
      }
    }
  }
  !fence &&
  (mabinogi || tracks >= 2 || (headers > 0 && tracks + defs + lines > 0))
}
