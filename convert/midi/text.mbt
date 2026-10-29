///|
/// File-wide choice for legacy MIDI metadata encoding.
pub struct MidiTextDecoder {
  shift_jis : Bool
}

///|
fn without_nuls(data : Bytes) -> Bytes {
  let out : Array[Byte] = []
  for b in data {
    if b != 0 {
      out.push(b)
    }
  }
  Bytes::from_array(out)
}

///|
fn valid_shift_jis(data : Bytes) -> Bool {
  let clean = without_nuls(data)
  try {
    ignore(@utf8.decode(clean[:]))
    true
  } catch {
    _ => {
      let text = @csv.decode_charset(clean, "Shift_JIS") catch {
        _ => return false
      }
      for c in text {
        let n = c.to_int()
        if n == 0xfffd || (n >= 0x80 && n < 0xa0) {
          return false
        }
      }
      true
    }
  }
}

///|
/// Select Shift_JIS only when all non-UTF-8 metadata can be decoded as
/// Shift_JIS. Otherwise, use Windows-1252 for every non-UTF-8 field.
pub fn MidiTextDecoder::new(file : MidiRawFile) -> MidiTextDecoder {
  let mut valid = valid_shift_jis(file.input.title) &&
    valid_shift_jis(file.input.copyright)
  for track in file.tracks {
    let t = track.notes
    valid = valid &&
      valid_shift_jis(t.name) &&
      valid_shift_jis(t.instrument) &&
      valid_shift_jis(t.copyright)
    for name in t.channel_names {
      valid = valid && valid_shift_jis(name)
    }
    for text in t.texts {
      valid = valid && valid_shift_jis(text.data)
    }
  }
  { shift_jis: valid, }
}

///|
pub fn MidiTextDecoder::uses_shift_jis(self : MidiTextDecoder) -> Bool {
  self.shift_jis
}

///|
/// Decode a metadata field, dropping NUL bytes and an initial UTF-8 BOM.
pub fn MidiTextDecoder::text(self : MidiTextDecoder, data : Bytes) -> String {
  let clean = without_nuls(data)
  let text = @utf8.decode(clean[:]) catch {
    _ =>
      @csv.decode_charset(
        clean,
        if self.shift_jis {
          "Shift_JIS"
        } else {
          "windows-1252"
        },
      ) catch {
        _ => ""
      }
  }
  if text.has_prefix("\u{feff}") {
    text[1:].to_owned()
  } else {
    text
  }
}

///|
/// Decode a name, replace Unicode control characters, and trim whitespace.
pub fn MidiTextDecoder::name(self : MidiTextDecoder, data : Bytes) -> String {
  let out = StringBuilder()
  let space = StringBuilder()
  let mut started = false
  for c in self.text(data) {
    let n = c.to_int()
    let ch = if n < 0x20 || (n >= 0x7f && n <= 0x9f) { ' ' } else { c }
    if ch.is_whitespace() {
      if started {
        space.write_char(ch)
      }
    } else {
      if started {
        out.write_string(space.to_string())
        space.reset()
      }
      out.write_char(ch)
      started = true
    }
  }
  out.to_string()
}
