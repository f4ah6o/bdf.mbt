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
/// A MIDI conversion result and nonfatal warnings.
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
  seconds : Double
}

///|
/// Convert a MIDI file to its score view, with playback and a text index.
/// Font files are supplied by the host in `db`; TAB views are not included.
pub fn convert_score(
  data : Bytes,
  db : @db.Database,
  options~ : MidiScoreOptions = MidiScoreOptions::new(),
) -> MidiScoreResult raise {
  convert_midi(data, db, options, false, None)
}

///|
/// Convert a MIDI file into a score with the upstream guitar TAB views.
pub fn convert(
  data : Bytes,
  db : @db.Database,
  options~ : MidiScoreOptions = MidiScoreOptions::new(),
  guitar_tab~ : Bool = true,
  page_ranges~ : Array[@convert.PageSpan]? = None,
) -> MidiScoreResult raise {
  convert_midi(data, db, options, guitar_tab, page_ranges)
}

///|
priv struct PendingMidiTab {
  rendered : @music.MusicRenderedTab
  view : Map[String, Json]
  selected : Array[Int32]
  keep : Array[Bool]
}

///|
fn midi_text_index(
  doc : @core.DocumentWriter,
  data : Array[Bytes],
  selected : Array[Int32],
) -> String raise {
  let runs : Array[@core.IndexRun] = []
  for page_index, source in selected {
    let obj = @core.decode_object_resources(data[source])
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
  doc.add_part("idx", @core.encode_text_index(runs))
}

///|
fn convert_midi(
  data : Bytes,
  db : @db.Database,
  options : MidiScoreOptions,
  guitar_tab : Bool,
  page_ranges : Array[@convert.PageSpan]?,
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
  render_music_performance(
    score,
    performance,
    db,
    options,
    "midi",
    sequence=file.smf,
    guitar_tab~,
    page_ranges~,
  )
}

///|
/// Write a score and its performed music as a BDF document.
pub fn render_music_performance(
  score : @music.NotatedScore,
  performance : MidiPerformance,
  db : @db.Database,
  options : MidiScoreOptions,
  source : String,
  sequence~ : Bytes? = None,
  guitar_tab~ : Bool = true,
  page_ranges~ : Array[@convert.PageSpan]? = None,
) -> MidiScoreResult raise {
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
  let meta : Map[String, Json] = { "source": Json::string(source) }
  if !dc.is_empty() {
    meta["dc"] = Json::object(dc)
  }
  let doc = @core.DocumentWriter::new(meta=Json::object(meta))
  let rendered = @music.render_midi_pages(
    score,
    db,
    doc,
    {
      page: options.page,
      system_fonts: options.system_fonts,
      no_subset: options.no_subset,
      ignore_restrictions: options.ignore_restrictions,
      no_woff2: options.no_woff2,
      document_language: "",
    },
    guitar_tab~,
  )
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
  let requested : Array[Int64]? = match page_ranges {
    Some(_) =>
      @convert.page_numbers(page_ranges, rendered.objects.length().to_int64())
    None =>
      match options.pages {
        Some(pages) => Some(pages.map(page => page.to_int64()))
        None => None
      }
  }
  match requested {
    None =>
      for i in 0..<rendered.objects.length() {
        selected.push(i)
        keep[i] = true
      }
    Some(pages) =>
      for page in pages {
        if page < 1L || page > rendered.objects.length().to_int64() {
          warnings.push(
            "page " +
            page.to_string() +
            " does not exist (the score has " +
            rendered.objects.length().to_string() +
            ")",
          )
        } else {
          let index = page.to_int() - 1
          selected.push(index)
          keep[index] = true
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
  let tabs : Array[PendingMidiTab] = []
  for tab in rendered.tabs {
    let tab_selected : Array[Int32] = []
    let tab_keep : Array[Bool] = []
    for _ in tab.objects {
      tab_keep.push(false)
    }
    let requested = match page_ranges {
      Some(_) =>
        @convert.page_numbers(page_ranges, tab.objects.length().to_int64())
      None =>
        match options.pages {
          Some(pages) => Some(pages.map(page => page.to_int64()))
          None => None
        }
    }
    match requested {
      None =>
        for i in 0..<tab.objects.length() {
          tab_selected.push(i)
          tab_keep[i] = true
        }
      Some(pages) =>
        for n in pages {
          if n >= 1L && n <= tab.objects.length().to_int64() {
            let index = n.to_int() - 1
            tab_selected.push(index)
            tab_keep[index] = true
          }
        }
    }
    let tab_pages : Array[Json] = []
    for index in tab_selected {
      let page = tab.view.pages[index]
      let w = Float::from_double(page.width)
      let h = Float::from_double(page.height)
      tab_pages.push(
        Json::object({
          "w": Json::number(w.to_double(), repr=w.to_string()),
          "h": Json::number(h.to_double(), repr=h.to_string()),
          "layers": Json::array([
            Json::object({
              "role": Json::string("body"),
              "obj": Json::string(tab.objects[index]),
            }),
          ]),
        }),
      )
    }
    let tab_view : Map[String, Json] = {
      "id": Json::string(tab.view.id),
      "kind": Json::string("fixed"),
      "title": Json::string(tab.view.title),
    }
    if !tab_pages.is_empty() {
      tab_view["pages"] = Json::array(tab_pages)
    }
    tabs.push({
      rendered: tab,
      view: tab_view,
      selected: tab_selected,
      keep: tab_keep,
    })
  }
  if !options.no_play {
    let sequence = match sequence {
      Some(bytes) => bytes
      None => performance_smf(performance)
    }
    let sequence_hash = doc.add_part("seq", sequence)
    let play : Map[String, Json] = { "seq": Json::string(sequence_hash) }
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
    for tab in tabs {
      let tab_play : Map[String, Json] = { "seq": Json::string(sequence_hash) }
      let (cues, truncated) = @music.guitar_tab_cues(
        score,
        tab.rendered.view,
        performance.division,
        keep=Some(tab.keep),
      )
      if truncated {
        warnings.push(
          "the music has more than 4000000 cues; the rest are left out",
        )
      }
      if !cues.systems.is_empty() {
        tab_play["cues"] = Json::string(
          doc.add_part("idx", @core.encode_cues(cues)),
        )
      }
      tab.view["play"] = Json::object(tab_play)
    }
  }
  if !options.no_text_index {
    view["textIndex"] = Json::string(
      midi_text_index(doc, rendered.page_data, selected),
    )
    for tab in tabs {
      let data : Array[Bytes] = [
        for page in tab.rendered.view.pages => page.object
      ]
      tab.view["textIndex"] = Json::string(
        midi_text_index(doc, data, tab.selected),
      )
    }
  }
  doc.add_view(Json::object(view))
  for tab in tabs {
    doc.add_view(Json::object(tab.view))
  }
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
    seconds: if options.no_play {
      0.0
    } else {
      performance_seconds(performance)
    },
  }
}
