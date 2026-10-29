///|
fn music_param_trim(text : String) -> String {
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
// Go's %q uses Unicode printability and Go escapes rather than JSON escapes.
fn music_param_quote(text : String) -> String {
  let output = StringBuilder()
  let hex = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
  ]
  output.write_char('"')
  for c in text {
    match c {
      '"' => output.write_string("\\\"")
      '\\' => output.write_string("\\\\")
      '\u{07}' => output.write_string("\\a")
      '\b' => output.write_string("\\b")
      '\u{0c}' => output.write_string("\\f")
      '\n' => output.write_string("\\n")
      '\r' => output.write_string("\\r")
      '\t' => output.write_string("\\t")
      '\u{0b}' => output.write_string("\\v")
      _ => {
        let category = @ucd.general_category(c).group()
        if c == ' ' || (category != @ucd.C && category != @ucd.Z) {
          output.write_char(c)
        } else {
          let code = c.to_int()
          let digits = if code < 0x20 || code == 0x7f {
            output.write_string("\\x")
            2
          } else if code < 0x10000 {
            output.write_string("\\u")
            4
          } else {
            output.write_string("\\U")
            8
          }
          for i = digits - 1; i >= 0; i = i - 1 {
            output.write_char(hex[(code >> (i * 4)) & 15])
          }
        }
      }
    }
  }
  output.write_char('"')
  output.to_string()
}

///|
pub suberror MusicParameterError {
  InvalidMusicParameter(String)
}

///|
fn music_param_int(value : String) -> Int64? {
  let bytes = @utf8.encode(value)
  let mut i = if bytes.length() > 0 && (bytes[0] == b'+' || bytes[0] == b'-') {
    1
  } else {
    0
  }
  if i == bytes.length() {
    return None
  }
  while i < bytes.length() {
    if bytes[i] < b'0' || bytes[i] > b'9' {
      return None
    }
    i += 1
  }
  Some(@string.parse_int64(value)) catch {
    _ => None
  }
}

///|
/// Parse an upstream music time parameter, such as `3/4`, `C` or `cut`.
pub fn parse_music_time(text : String) -> TimeSig raise MusicParameterError {
  let value = music_param_trim(text)
  match value.to_lower() {
    "c" | "common" => return { beats: 4, beat_type: 4, symbol: "common", }
    "c|" | "cut" | "alla breve" =>
      return { beats: 2, beat_type: 2, symbol: "cut", }
    _ => ()
  }
  let pieces : Array[String] = [ for p in value.split("/") => p.to_owned() ]
  if pieces.length() == 2 {
    match
      (
        music_param_int(music_param_trim(pieces[0])),
        music_param_int(music_param_trim(pieces[1])),
      ) {
      (Some(beats), Some(beat_type)) if beats >= 1L &&
        beats <= 99L &&
        beat_type >= 1L &&
        beat_type <= 64L &&
        (beat_type & (beat_type - 1L)) == 0L =>
        return {
          beats: beats.to_int(),
          beat_type: beat_type.to_int(),
          symbol: "",
        }
      _ => ()
    }
  }
  raise InvalidMusicParameter(
    "parameter time: " +
    music_param_quote(text) +
    " is not a time signature such as 3/4",
  )
}

///|
/// Parse an upstream music key parameter, such as `G`, `Bb`, `F#m` or `-2`.
pub fn parse_music_key(text : String) -> KeySig raise MusicParameterError {
  let failure = "parameter key: " +
    music_param_quote(text) +
    " is not a key such as G, Bb or F#m"
  let mut value = music_param_trim(text)
  let mut minor = false
  for
    (suffix, is_minor) in [
      ("minor", true),
      ("Minor", true),
      ("min", true),
      ("major", false),
      ("Major", false),
      ("maj", false),
      ("m", true),
      ("M", false),
    ] {
    if value.has_suffix(suffix) && value.length() > suffix.length() {
      value = music_param_trim(
        value.unsafe_substring(start=0, end=value.length() - suffix.length()),
      )
      minor = is_minor
      break
    }
  }
  let fifths = match music_param_int(value) {
    Some(n) => n
    None => {
      if value == "" {
        raise InvalidMusicParameter(failure)
      }
      let head = value[0].to_int()
      let letter = if head >= 97 && head <= 122 { head - 32 } else { head }
      let base = match letter {
        70 => -1
        67 => 0
        71 => 1
        68 => 2
        65 => 3
        69 => 4
        66 => 5
        _ => raise InvalidMusicParameter(failure)
      }
      let tail = value[1:].to_owned()
      let accidental = match tail {
        "" => 0
        "#" | "♯" => 7
        "b" | "♭" => -7
        _ => raise InvalidMusicParameter(failure)
      }
      (base + accidental - (if minor { 3 } else { 0 })).to_int64()
    }
  }
  if fifths < -7L || fifths > 7L {
    raise InvalidMusicParameter(
      "parameter key: " +
      music_param_quote(text) +
      " has more than 7 sharps or flats",
    )
  }
  { fifths: fifths.to_int(), minor, }
}

///|
/// Parse the TAB parameter using Go's boolean spellings; empty enables TAB.
pub fn parse_music_tab(text : String) -> Bool raise MusicParameterError {
  match text {
    "" | "1" | "t" | "T" | "true" | "TRUE" | "True" => true
    "0" | "f" | "F" | "false" | "FALSE" | "False" => false
    _ =>
      raise InvalidMusicParameter(
        "parameter tab: " + music_param_quote(text) + " is not a boolean",
      )
  }
}
