///|
/// Options for converting MIDI to the fixed score view of a BDF document.
pub(all) struct MidiScoreOptions {
  page : @music.MusicPageOptions
  pages : Array[Int32]?
  time : @music.TimeSig?
  key : @music.KeySig?
  no_play : Bool
  no_text_index : Bool
  system_fonts : Bool
  no_subset : Bool
  ignore_restrictions : Bool
  no_woff2 : Bool
}

///|
pub fn MidiScoreOptions::new() -> MidiScoreOptions {
  {
    page: { width: 0.0, height: 0.0, staff_space: 0.0, title: "", },
    pages: None,
    time: None,
    key: None,
    no_play: false,
    no_text_index: false,
    system_fonts: false,
    no_subset: false,
    ignore_restrictions: false,
    no_woff2: false,
  }
}

///|
/// A BDF score view and nonfatal warnings. Guitar TAB views are not included.
pub(all) struct MidiScoreResult {
  bdf : Bytes
  warnings : Array[String]
  pages : Int32
  systems : Int32
  measures : Int32
  parts : Int32
  staves : Int32
  notes : Int32
  embedded_fonts : Int32
}

///|
/// Convert a MIDI file to its score view, with playback and a text index.
/// Font files are supplied by the host in `db`; TAB views are not included.
pub fn convert_score(
  data : Bytes,
  db : @db.Database,
  options~ : MidiScoreOptions = MidiScoreOptions::new(),
) -> MidiScoreResult raise {
  if data.length() > 67108864 {
    raise InvalidMidiInput("midi: the file is larger than 67108864 bytes")
  }
  let file = read_file(data)
  let performance = performance(file)
  let score = notate_file(
    file,
    time_override=options.time,
    key_override=options.key,
  )
  let title = if options.page.title == "" {
    score.title
  } else {
    options.page.title
  }
  let dc : Map[String, Json] = Map([])
  if title != "" {
    dc["title"] = Json::string(title)
  }
  if score.composer != "" {
    dc["creator"] = Json::string(score.composer)
  }
  let contributors : Array[Json] = []
  if score.lyricist != "" {
    contributors.push(Json::string(score.lyricist))
  }
  if score.arranger != "" {
    contributors.push(Json::string(score.arranger))
  }
  if contributors.length() == 1 {
    dc["contributor"] = contributors[0]
  } else if contributors.length() > 1 {
    dc["contributor"] = Json::array(contributors)
  }
  if score.copyright != "" {
    dc["rights"] = Json::string(score.copyright)
  }
  let meta : Map[String, Json] = { "source": Json::string("midi") }
  if !dc.is_empty() {
    meta["dc"] = Json::object(dc)
  }
  let doc = @core.DocumentWriter::new(meta=Json::object(meta))
  let rendered = @music.render_midi_pages(score, db, doc, {
    page: options.page,
    system_fonts: options.system_fonts,
    no_subset: options.no_subset,
    ignore_restrictions: options.ignore_restrictions,
    no_woff2: options.no_woff2,
    document_language: "",
  })
  let warnings = performance.warnings.copy()
  for warning in score.timeline.warnings {
    warnings.push(warning)
  }
  for warning in rendered.warnings {
    warnings.push(warning)
  }
  let selected : Array[Int32] = []
  let keep : Array[Bool] = []
  for _ in rendered.objects {
    keep.push(false)
  }
  match options.pages {
    None =>
      for i in 0..<rendered.objects.length() {
        selected.push(i)
        keep[i] = true
      }
    Some(pages) =>
      for page in pages {
        if page < 1 || page > rendered.objects.length() {
          warnings.push(
            "page " +
            page.to_string() +
            " does not exist (the score has " +
            rendered.objects.length().to_string() +
            ")",
          )
        } else {
          selected.push(page - 1)
          keep[page - 1] = true
        }
      }
  }
  let page_width = Float::from_double(rendered.layout.width)
  let page_height = Float::from_double(rendered.layout.height)
  let pages : Array[Json] = []
  for pi in selected {
    pages.push(
      Json::object({
        "w": Json::number(page_width.to_double(), repr=page_width.to_string()),
        "h": Json::number(page_height.to_double(), repr=page_height.to_string()),
        "layers": Json::array([
          Json::object({
            "role": Json::string("body"),
            "obj": Json::string(rendered.objects[pi]),
          }),
        ]),
      }),
    )
  }
  let view : Map[String, Json] = {
    "id": Json::string("score"),
    "kind": Json::string("fixed"),
  }
  if !pages.is_empty() {
    view["pages"] = Json::array(pages)
  }
  if title != "" {
    view["title"] = Json::string(title)
  }
  if !options.no_play {
    let sequence = match file.smf {
      Some(bytes) => bytes
      None => performance_smf(performance)
    }
    let play : Map[String, Json] = {
      "seq": Json::string(doc.add_part("seq", sequence)),
    }
    let (cues, truncated) = @music.midi_score_cues(
      score,
      rendered.layout,
      performance.division,
      keep=Some(keep),
    )
    if truncated {
      warnings.push(
        "the music has more than 4000000 cues; the rest are left out",
      )
    }
    if !cues.systems.is_empty() {
      play["cues"] = Json::string(doc.add_part("idx", @core.encode_cues(cues)))
    }
    view["play"] = Json::object(play)
  }
  if !options.no_text_index {
    let runs : Array[@core.IndexRun] = []
    for page_index, source in selected {
      let obj = @core.decode_object_resources(rendered.page_data[source])
      let text = @render.extract_text(obj, _ => None)
      for i, run in text.runs {
        runs.push({
          a: page_index,
          b: 0,
          ordinal: run.ordinal,
          separator: if i == 0 {
            2
          } else {
            run.separator
          },
          text: run.text,
        })
      }
    }
    view["textIndex"] = Json::string(
      doc.add_part("idx", @core.encode_text_index(runs)),
    )
  }
  doc.add_view(Json::object(view))
  let mut staves = 0
  let mut notes = 0
  for part in score.parts {
    staves += Int32::max(part.clefs.length(), 1)
    for measure in part.measures {
      for event in measure.events {
        notes += event.notes.length()
      }
    }
  }
  {
    bdf: doc.write_single(),
    warnings,
    pages: pages.length(),
    systems: rendered.layout.systems.length(),
    measures: score.timeline.measures.length(),
    parts: score.parts.length(),
    staves,
    notes,
    embedded_fonts: rendered.embedded_fonts,
  }
}
