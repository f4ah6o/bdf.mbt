// General MIDI program names follow shibukawa/bdf converter/internal/music.

///|
let program_names : Array[String] = [
  "Acoustic Grand Piano", "Bright Acoustic Piano", "Electric Grand Piano", "Honky-tonk Piano",
  "Electric Piano 1", "Electric Piano 2", "Harpsichord", "Clavinet", "Celesta", "Glockenspiel",
  "Music Box", "Vibraphone", "Marimba", "Xylophone", "Tubular Bells", "Dulcimer",
  "Drawbar Organ", "Percussive Organ", "Rock Organ", "Church Organ", "Reed Organ",
  "Accordion", "Harmonica", "Tango Accordion", "Acoustic Guitar (nylon)", "Acoustic Guitar (steel)",
  "Electric Guitar (jazz)", "Electric Guitar (clean)", "Electric Guitar (muted)",
  "Overdriven Guitar", "Distortion Guitar", "Guitar Harmonics", "Acoustic Bass",
  "Electric Bass (finger)", "Electric Bass (pick)", "Fretless Bass", "Slap Bass 1",
  "Slap Bass 2", "Synth Bass 1", "Synth Bass 2", "Violin", "Viola", "Cello", "Contrabass",
  "Tremolo Strings", "Pizzicato Strings", "Orchestral Harp", "Timpani", "String Ensemble 1",
  "String Ensemble 2", "Synth Strings 1", "Synth Strings 2", "Choir Aahs", "Voice Oohs",
  "Synth Voice", "Orchestra Hit", "Trumpet", "Trombone", "Tuba", "Muted Trumpet",
  "French Horn", "Brass Section", "Synth Brass 1", "Synth Brass 2", "Soprano Sax",
  "Alto Sax", "Tenor Sax", "Baritone Sax", "Oboe", "English Horn", "Bassoon", "Clarinet",
  "Piccolo", "Flute", "Recorder", "Pan Flute", "Blown Bottle", "Shakuhachi", "Whistle",
  "Ocarina", "Lead 1 (square)", "Lead 2 (sawtooth)", "Lead 3 (calliope)", "Lead 4 (chiff)",
  "Lead 5 (charang)", "Lead 6 (voice)", "Lead 7 (fifths)", "Lead 8 (bass + lead)",
  "Pad 1 (new age)", "Pad 2 (warm)", "Pad 3 (polysynth)", "Pad 4 (choir)", "Pad 5 (bowed)",
  "Pad 6 (metallic)", "Pad 7 (halo)", "Pad 8 (sweep)", "FX 1 (rain)", "FX 2 (soundtrack)",
  "FX 3 (crystal)", "FX 4 (atmosphere)", "FX 5 (brightness)", "FX 6 (goblins)", "FX 7 (echoes)",
  "FX 8 (sci-fi)", "Sitar", "Banjo", "Shamisen", "Koto", "Kalimba", "Bagpipe", "Fiddle",
  "Shanai", "Tinkle Bell", "Agogo", "Steel Drums", "Woodblock", "Taiko Drum", "Melodic Tom",
  "Synth Drum", "Reverse Cymbal", "Guitar Fret Noise", "Breath Noise", "Seashore",
  "Bird Tweet", "Telephone Ring", "Helicopter", "Applause", "Gunshot",
]

///|
/// Return the General MIDI program name.
pub fn program_name(program : Int32) -> String {
  program_names[program & 127]
}

///|
/// The track names and textual credits extracted before notation.
pub(all) struct MidiCredits {
  title : String
  composer : String
  lyricist : String
  arranger : String
  copyright : String
}

///|
fn trim_text(text : String) -> String {
  let out = StringBuilder()
  let pending = StringBuilder()
  let mut started = false
  for c in text {
    if c.is_whitespace() {
      if started {
        pending.write_char(c)
      }
    } else {
      if started {
        out.write_string(pending.to_string())
        pending.reset()
      }
      started = true
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn credit(text : String) -> (String, String) {
  let labels = [
    ("composer", "composer"),
    ("composed by", "composer"),
    ("music", "composer"),
    ("music by", "composer"),
    ("作曲", "composer"),
    ("lyricist", "lyricist"),
    ("lyrics", "lyricist"),
    ("lyrics by", "lyricist"),
    ("words", "lyricist"),
    ("words by", "lyricist"),
    ("作詞", "lyricist"),
    ("arranger", "arranger"),
    ("arranged by", "arranger"),
    ("arrangement", "arranger"),
    ("編曲", "arranger"),
  ]
  for (label, field) in labels {
    if text.length() <= label.length() ||
      text[:label.length()].to_owned().to_lower() != label {
      continue
    }
    let suffix = text[label.length():].to_owned()
    let mut i = 0
    while i < suffix.length() && (suffix[i] == 0x20 || suffix[i] == 0x09) {
      i += 1
    }
    let mut rest = suffix[i:].to_owned()
    if rest.has_prefix(":") || rest.has_prefix("：") {
      rest = rest[1:].to_owned()
    } else if !label.has_suffix(" by") || i == 0 {
      continue
    }
    let value = trim_text(rest)
    if value != "" {
      return (field, value)
    }
  }
  ("", "")
}

///|
fn karaoke(track : MidiTrackNotes, decoder : MidiTextDecoder) -> Bool {
  if decoder.name(track.name).to_lower() == "words" {
    return true
  }
  for text in track.texts {
    if text.kind == 1 &&
      text.data.length() >= 2 &&
      text.data[0] == b'@' &&
      (text.data[1] == b'L' || text.data[1] == b'T') {
      return true
    }
  }
  false
}

///|
/// Build the textual credits from all tracks and RIFF INFO fields.
pub fn credits(file : MidiRawFile) -> MidiCredits {
  let decoder = MidiTextDecoder::new(file)
  let mut title = ""
  let mut composer = ""
  let mut lyricist = ""
  let mut arranger = ""
  let mut copyright = ""
  for track in file.tracks {
    for text in track.notes.texts {
      if text.kind == 1 && title == "" && text.data.has_prefix(b"@T") {
        title = decoder.name(text.data[2:].to_owned())
      }
    }
  }
  let first = file.tracks[0].notes
  let name = decoder.name(first.name)
  let placeholders = [
    "untitled", "tempo", "tempo track", "tempo map", "conductor", "conductor track",
    "setup", "system setup", "global", "sequence", "track 0", "track 1",
  ]
  if title == "" &&
    (file.header.format == 0 || first.notes.is_empty()) &&
    !placeholders.contains(name.to_lower()) {
    title = name
  }
  if title == "" {
    title = decoder.name(file.input.title)
  }
  for track in file.tracks {
    for text in track.notes.texts {
      if text.kind != 1 {
        continue
      }
      let (field, value) = credit(decoder.name(text.data))
      if field == "composer" && composer == "" {
        composer = value
      } else if field == "lyricist" && lyricist == "" {
        lyricist = value
      } else if field == "arranger" && arranger == "" {
        arranger = value
      }
    }
  }
  if title == "" && !karaoke(first, decoder) {
    for text in first.texts {
      if text.kind != 1 || text.tick != 0L {
        continue
      }
      let name = decoder.name(text.data)
      if name != "" && !name.has_prefix("@") && credit(name).0 == "" {
        title = name
        break
      }
    }
  }
  for track in file.tracks {
    let name = decoder.name(track.notes.copyright)
    if name != "" {
      copyright = name
      break
    }
  }
  if copyright == "" {
    copyright = decoder.name(file.input.copyright)
  }
  { title, composer, lyricist, arranger, copyright, }
}

///|
/// Name a channel according to track metadata and its initial program.
pub fn track_name(
  file : MidiRawFile,
  track : Int32,
  channel : Int32,
  has_program : Bool,
  program : Int32,
) -> String {
  let decoder = MidiTextDecoder::new(file)
  let item = file.tracks[track].notes
  let channel_name = decoder.name(item.channel_names[channel])
  if channel_name != "" {
    return channel_name
  }
  let titled = file.header.format == 0 && track == 0
  let mut name = if titled { "" } else { decoder.name(item.name) }
  if name == "" {
    name = decoder.name(item.instrument)
  }
  let channels : Map[Int32, Bool] = Map([])
  for note in item.notes {
    channels[note.channel] = true
  }
  if name != "" && channels.length() > 1 {
    return "\{name} (ch \{channel + 1})"
  }
  if name != "" {
    return name
  }
  if channel == 9 {
    return "Drums"
  }
  if has_program {
    return program_name(program)
  }
  "Channel \{channel + 1}"
}
