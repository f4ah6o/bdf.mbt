///|
#export_name("musicxml_detect_text")
pub fn musicxml_detect_text(data : Bytes) -> String {
  let (little, utf16) = @musicxml.musicxml_utf16_order(data)
  Json::array([
    Json::boolean(little),
    Json::boolean(utf16),
    Json::string(@musicxml.musicxml_head_text(data)),
    Json::boolean(@musicxml.detect_musicxml_text(data)),
  ]).stringify()
}

///|
#export_name("musicxml_text")
pub fn musicxml_text(data : Bytes) -> String {
  let (bytes, warning) = @musicxml.musicxml_to_utf8(data)
  Json::array([
    Json::string(@musicxml.musicxml_declared_encoding(data)),
    Json::array([ for b in bytes => Json::number(b.to_int().to_double()) ]),
    Json::string(warning),
  ]).stringify()
}

///|
#export_name("musicxml_mxl")
pub fn musicxml_mxl(data : Bytes) -> String {
  let head = data[:Int32::min(data.length(), 1024)].to_owned()
  let detect = @musicxml.detect_musicxml(head, data)
  let (bytes, error) = (Some(@musicxml.read_musicxml_input(data)), "") catch {
    @musicxml.InvalidMusicXmlInput(message) => (None, message)
  }
  Json::array([
    Json::boolean(detect),
    match bytes {
      None => Json::null()
      Some(b) =>
        Json::array([ for v in b => Json::number(v.to_int().to_double()) ])
    },
    Json::string(error),
  ]).stringify()
}

///|
#export_name("musicxml_values")
pub fn musicxml_values(text : String) -> String {
  let (n, nok) = @musicxml.musicxml_integer(text)
  let (f, fok) = @musicxml.musicxml_float(text)
  let (endings, more) = @musicxml.musicxml_ending_numbers(text)
  Json::array([
    Json::number(n.to_double()),
    Json::boolean(nok),
    Json::number(f),
    Json::boolean(fok),
    Json::array(endings.map(n => Json::number(n.to_double()))),
    Json::boolean(more),
  ]).stringify()
}

///|
#export_name("musicxml_numbers")
pub fn musicxml_numbers(max : Int32, names_json : String) -> String {
  let names = @json.parse(names_json) catch { _ => return "[]" }
  let numbered = @musicxml.MusicXmlNumbers::new(max)
  let out : Array[Json] = []
  match names {
    Array(items) =>
      for item in items {
        match item {
          String(name) => out.push(Json::number(numbered.get(name).to_double()))
          _ => ()
        }
      }
    _ => ()
  }
  Json::array(out).stringify()
}

///|
fn musicxml_tree_json(node : @musicxml.MusicXmlNode) -> Json {
  Json::array([
    Json::string(node.name),
    Json::array(
      node.attributes.map(a => {
        Json::array([Json::string(a.name), Json::string(a.value)])
      }),
    ),
    Json::string(node.text),
    Json::array(node.children.map(musicxml_tree_json)),
  ])
}

///|
#export_name("musicxml_tree")
pub fn musicxml_tree(data : Bytes) -> String {
  musicxml_tree_json(@musicxml.musicxml_read_tree(data)).stringify() catch {
    _ => "null"
  }
}

///|
#export_name("musicxml_header")
pub fn musicxml_header(data : Bytes) -> String {
  try {
    let header = @musicxml.musicxml_header(@musicxml.musicxml_read_tree(data))
    let parts = header.parts.map(fn(p) {
      let inst = p.instruments.map(fn(v) {
        Json::array([
          Json::string(v.id),
          Json::number(v.channel.to_double()),
          Json::number(v.program.to_double()),
          Json::number(v.unpitched.to_double()),
          Json::number(v.volume.to_double()),
          Json::number(v.pan.to_double()),
        ])
      })
      Json::array([
        Json::string(p.id),
        Json::string(p.name),
        Json::string(p.abbreviation),
        Json::string(p.track_name),
        Json::array(inst),
      ])
    })
    Json::array([
      Json::string(header.title),
      Json::string(header.subtitle),
      Json::string(header.composer),
      Json::string(header.lyricist),
      Json::string(header.arranger),
      Json::string(header.rights),
      Json::array(parts),
      Json::array(header.warnings.map(v => Json::string(v))),
    ]).stringify()
  } catch {
    _ => "null"
  }
}

///|
#export_name("musicxml_notation")
pub fn musicxml_notation(
  data : Bytes,
  ticks : Int32,
  accidental : String,
  alter : Int32,
) -> String {
  try {
    let root = @musicxml.musicxml_read_tree(data)
    let time = match @musicxml.musicxml_time_sig(root.child("time").unwrap()) {
      None => Json::null()
      Some(t) =>
        Json::array([
          Json::number(t.beats.to_double()),
          Json::number(t.beat_type.to_double()),
          Json::string(t.symbol),
        ])
    }
    let clef = @musicxml.musicxml_clef(root.child("clef").unwrap())
    let (kind, dots) = @musicxml.musicxml_infer_type(ticks)
    Json::array([
      time,
      Json::array([
        Json::number(clef.sign.to_double()),
        Json::number(clef.line.to_double()),
        Json::number(clef.octave.to_double()),
      ]),
      Json::array([
        Json::number(kind.to_double()),
        Json::number(dots.to_double()),
      ]),
      Json::number(@musicxml.musicxml_accidental(accidental, alter).to_double()),
    ]).stringify()
  } catch {
    _ => "null"
  }
}

///|
#export_name("musicxml_pitch_note")
pub fn musicxml_pitch_note(data : Bytes, transpose : Int32) -> String {
  try {
    let node = @musicxml.musicxml_read_tree(data)
    match @musicxml.musicxml_pitch_note(node, transpose~) {
      None => "null"
      Some(n) =>
        Json::array([
          Json::number(n.pitch.step.to_double()),
          Json::number(n.pitch.alter.to_double()),
          Json::number(n.pitch.octave.to_double()),
          Json::number(n.sounding_key.to_double()),
          Json::number(n.accidental.to_double()),
          Json::boolean(n.cautionary),
          Json::number(n.head.to_double()),
          Json::boolean(n.tie_start),
          Json::boolean(n.tie_stop),
          Json::boolean(n.sound_tie_start),
          Json::boolean(n.sound_tie_stop),
          Json::number(n.tab_string.to_double()),
          Json::number(n.tab_fret.to_double()),
          Json::boolean(n.has_alteration),
          Json::boolean(n.has_accidental),
        ]).stringify()
    }
  } catch {
    _ => "null"
  }
}

///|
#export_name("musicxml_unpitched_note")
pub fn musicxml_unpitched_note(
  data : Bytes,
  instruments_json : String,
) -> String {
  try {
    let items = @json.parse(instruments_json).as_array().unwrap()
    let instruments : Array[@musicxml.MusicXmlInstrument] = []
    for item in items {
      let fields = item.as_array().unwrap()
      instruments.push({
        id: fields[0].as_string().unwrap(),
        unpitched: fields[1].as_number().unwrap().to_int(),
        channel: -1,
        program: -1,
        volume: -1,
        pan: -1,
      })
    }
    let node = @musicxml.musicxml_read_tree(data)
    match @musicxml.musicxml_pitch_note(node, instruments~) {
      None => "null"
      Some(n) =>
        Json::array([
          Json::number(n.pitch.step.to_double()),
          Json::number(n.pitch.alter.to_double()),
          Json::number(n.pitch.octave.to_double()),
          Json::number(n.sounding_key.to_double()),
          Json::number(n.accidental.to_double()),
          Json::boolean(n.tie_start),
          Json::boolean(n.tie_stop),
          Json::boolean(n.sound_tie_start),
          Json::boolean(n.sound_tie_stop),
          Json::boolean(!n.pitched),
          Json::boolean(!n.pitched),
        ]).stringify()
    }
  } catch {
    _ => "null"
  }
}
