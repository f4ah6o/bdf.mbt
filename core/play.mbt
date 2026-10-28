///|
/// A view's MIDI bytes and optional score cues.
pub(all) struct MusicData {
  seq : Bytes
  cues : Cues?
}

///|
/// A view's recording, safe audio MIME type, and optional timing cues.
pub(all) struct AudioData {
  data : Bytes
  media_type : String
  cues : Cues?
}

///|
fn audio_media_type(value : String) -> String {
  let bytes = @utf8.encode(value)
  if bytes.length() <= 6 ||
    bytes[0] != b'a' ||
    bytes[1] != b'u' ||
    bytes[2] != b'd' ||
    bytes[3] != b'i' ||
    bytes[4] != b'o' ||
    bytes[5] != b'/' {
    return ""
  }
  for i in 6..<bytes.length() {
    let c = bytes[i].to_int()
    if !((c >= 65 && c <= 90) ||
      (c >= 97 && c <= 122) ||
      (c >= 48 && c <= 57) ||
      c == 95 ||
      c == 46 ||
      c == 43 ||
      c == 45) {
      return ""
    }
  }
  value
}

///|
fn play_cues(play : Play, load : (String) -> Bytes raise) -> Cues? raise {
  match play.cues {
    Some(hash) => Some(decode_cues(load(hash)))
    None => None
  }
}

///|
fn read_music(view : View, load : (String) -> Bytes raise) -> MusicData? raise {
  if view.play is Some(play) && play.seq is Some(hash) {
    Some({ seq: load(hash), cues: play_cues(play, load), })
  } else {
    None
  }
}

///|
fn read_audio(view : View, load : (String) -> Bytes raise) -> AudioData? raise {
  if view.play is Some(play) && play.audio is Some(hash) {
    Some({
      data: load(hash),
      media_type: audio_media_type(play.media_type),
      cues: play_cues(play, load),
    })
  } else {
    None
  }
}

///|
pub fn Document::play(self : Document, view : View) -> MusicData? raise {
  read_music(view, hash => self.part(hash))
}

///|
pub fn Document::audio(self : Document, view : View) -> AudioData? raise {
  read_audio(view, hash => self.part(hash))
}

///|
pub fn SplitDocument::play(
  self : SplitDocument,
  view : View,
) -> MusicData? raise {
  read_music(view, hash => self.part(hash))
}

///|
pub fn SplitDocument::audio(
  self : SplitDocument,
  view : View,
) -> AudioData? raise {
  read_audio(view, hash => self.part(hash))
}
