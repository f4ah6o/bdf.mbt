///|
/// Error while converting an MML file.
pub suberror MmlInputError {
  InvalidMmlInput(String)
}

///|
/// Convert MML to a BDF score, with playback and optional guitar TAB views.
pub fn convert(
  data : Bytes,
  db : @db.Database,
  options~ : @midi.MidiScoreOptions = @midi.MidiScoreOptions::new(),
  dialect~ : String = "",
  octave~ : Int32 = 0,
  program~ : Int32 = -1,
  guitar_tab~ : Bool = true,
  page_ranges~ : Array[@convert.PageSpan]? = None,
) -> @midi.MidiScoreResult raise {
  if data.length() > 16777216 {
    raise InvalidMmlInput("mml: the file is larger than 16 MiB")
  }
  let result = parse_mml(data, dialect~, octave~, program~)
  let p = match result.performance {
    Some(performance) => performance
    None => raise InvalidMmlInput(result.error)
  }
  let notation_tracks : Array[@music.PerformanceTrack] = []
  let midi_tracks : Array[@midi.MidiPerformanceTrack] = []
  for tr in p.tracks {
    let notes : Array[@music.NotationNote] = []
    let midi_notes : Array[@midi.MidiPlayNote] = []
    for n in tr.notes {
      notes.push({
        tick: n.tick.to_int64(),
        duration: n.duration.to_int64(),
        key: n.key,
        velocity: n.velocity,
        spelling: n.spelling,
      })
      midi_notes.push({
        tick: n.tick.to_int64(),
        duration: n.duration.to_int64(),
        key: n.key,
        velocity: n.velocity,
      })
    }
    let controls : Array[@midi.MidiPlayControl] = [
      for c in tr.controls => {
        {
          tick: c.tick.to_int64(),
          kind: c.kind,
          number: c.number,
          value: c.value,
        }
      }
    ]
    notation_tracks.push({
      name: tr.name,
      channel: tr.channel,
      program: tr.program,
      notes,
      lyrics: [],
    })
    midi_tracks.push({
      name: tr.name,
      channel: tr.channel,
      program: tr.program,
      volume: tr.volume,
      pan: tr.pan,
      notes: midi_notes,
      controls,
      lyrics: [],
      source_track: 0,
    })
  }
  let tempos : Array[@music.TempoChange] = [
    for t in p.tempos => { tick: t.tick.to_int64(), bpm: t.bpm, }
  ]
  let midi_tempos : Array[@midi.MidiRawTempo] = [
    for t in p.tempos => { tick: t.tick.to_int64(), bpm: t.bpm, }
  ]
  let score = @music.notate(
    {
      title: p.title,
      subtitle: "",
      composer: p.composer,
      lyricist: p.lyricist,
      arranger: p.arranger,
      copyright: p.copyright,
      tracks: notation_tracks,
      times: [],
      keys: [],
      tempos,
      end: p.end.to_int64(),
    },
    time_override=options.time,
    key_override=options.key,
  )
  let playback : @midi.MidiPerformance = {
    credits: {
      title: p.title,
      composer: p.composer,
      lyricist: p.lyricist,
      arranger: p.arranger,
      copyright: p.copyright,
    },
    tracks: midi_tracks,
    tempos: midi_tempos,
    times: [],
    keys: [],
    end: p.end.to_int64(),
    division: 960,
    warnings: result.warnings,
  }
  @midi.render_music_performance(
    score,
    playback,
    db,
    options,
    "mml",
    guitar_tab~,
    page_ranges~,
  )
}
