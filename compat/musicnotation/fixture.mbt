///|
#export_name("spell")
pub fn spell(key : Int32, fifths : Int32, minor : Bool, hint : Int32) -> String {
  let p = @music.spell(key, { fifths, minor, }, hint)
  Json::array([
    Json::number(p.step.to_double()),
    Json::number(p.alter.to_double()),
    Json::number(p.octave.to_double()),
  ]).stringify()
}

///|
#export_name("estimate")
pub fn estimate(values : FixedArray[Double], flats : Int32) -> String {
  let hist : Array[Double] = []
  for x in values {
    hist.push(x)
  }
  let k = @music.estimate_key(hist, flats)
  Json::array([Json::number(k.fifths.to_double()), Json::boolean(k.minor)]).stringify()
}

///|
#export_name("time")
pub fn time(beats : Int32, beat_type : Int32) -> String {
  let sig : @music.TimeSig = { beats, beat_type, symbol: "", }
  let (length, compound) = sig.beat()
  Json::array([
    Json::number(sig.length().to_double()),
    Json::number(length.to_double()),
    Json::boolean(compound),
  ]).stringify()
}

///|
#export_name("timeline")
pub fn timeline(
  end : Int32,
  raw_times : FixedArray[Int32],
  raw_keys : FixedArray[Int32],
  raw_tempos : FixedArray[Double],
  histogram : FixedArray[Double],
  flats : Int32,
  time_override : FixedArray[Int32],
  key_override : FixedArray[Int32],
) -> String {
  let times : Array[@music.TimeChange] = []
  let keys : Array[@music.KeyChange] = []
  let tempos : Array[@music.TempoChange] = []
  let hist : Array[Double] = []
  for i in 0..<(raw_times.length() / 3) {
    times.push({
      tick: raw_times[i * 3].to_int64(),
      time: {
        beats: raw_times[i * 3 + 1],
        beat_type: raw_times[i * 3 + 2],
        symbol: "",
      },
    })
  }
  for i in 0..<(raw_keys.length() / 3) {
    keys.push({
      tick: raw_keys[i * 3].to_int64(),
      key: { fifths: raw_keys[i * 3 + 1], minor: raw_keys[i * 3 + 2] != 0, },
    })
  }
  for i in 0..<(raw_tempos.length() / 2) {
    tempos.push({
      tick: raw_tempos[i * 2].to_int64(),
      bpm: raw_tempos[i * 2 + 1],
    })
  }
  for v in histogram {
    hist.push(v)
  }
  let tm : @music.TimeSig? = if time_override.length() == 0 {
    None
  } else {
    Some({ beats: time_override[0], beat_type: time_override[1], symbol: "", })
  }
  let ky : @music.KeySig? = if key_override.length() == 0 {
    None
  } else {
    Some({ fifths: key_override[0], minor: key_override[1] != 0, })
  }
  let timeline = @music.build_timeline(
    end.to_int64(),
    times,
    keys,
    tempos,
    hist,
    flats,
    time_override=tm,
    key_override=ky,
  )
  let spans = timeline.measures.map(m => {
    let key = match m.key {
      Some(k) =>
        Json::array([Json::number(k.fifths.to_double()), Json::boolean(k.minor)])
      None => Json::null()
    }
    let marks = m.tempo.map(t => {
      Json::array([
        Json::number(t.offset.to_double()),
        Json::number(t.dots.to_double()),
        Json::number(t.per_minute),
      ])
    })
    Json::object({
      "start": Json::number(m.start.to_double()),
      "length": Json::number(m.length.to_double()),
      "time": Json::array([
        Json::number(m.time.beats.to_double()),
        Json::number(m.time.beat_type.to_double()),
      ]),
      "showTime": Json::boolean(m.show_time),
      "key": key,
      "effectiveKey": Json::array([
        Json::number(m.effective_key.fifths.to_double()),
        Json::boolean(m.effective_key.minor),
      ]),
      "tempos": Json::array(marks),
    })
  })
  Json::object({
    "measures": Json::array(spans),
    "warnings": Json::array(timeline.warnings.map(Json::string)),
  }).stringify()
}

///|
#export_name("quantize")
pub fn quantize(
  raw_measures : FixedArray[Int32],
  raw_notes : FixedArray[Int32],
) -> String {
  let measures : Array[@music.MeasureSpan] = []
  for i in 0..<(raw_measures.length() / 4) {
    measures.push({
      start: raw_measures[4 * i].to_int64(),
      length: raw_measures[4 * i + 1].to_int64(),
      time: {
        beats: raw_measures[4 * i + 2],
        beat_type: raw_measures[4 * i + 3],
        symbol: "",
      },
      show_time: false,
      key: None,
      effective_key: { fifths: 0, minor: false, },
      tempo: [],
    })
  }
  let notes : Array[@music.NotationNote] = []
  let onsets : Array[Int64] = []
  for i in 0..<(raw_notes.length() / 5) {
    let tick = raw_notes[5 * i].to_int64()
    notes.push({
      tick,
      duration: raw_notes[5 * i + 1].to_int64(),
      key: raw_notes[5 * i + 2],
      velocity: raw_notes[5 * i + 3],
      spelling: raw_notes[5 * i + 4],
    })
    onsets.push(tick)
  }
  let beats = @music.beat_grids(measures, onsets)
  let quantized = @music.quantize_notes(measures, notes)
  Json::object({
    "beats": Json::array(
      beats.map(b => {
        Json::array([
          Json::number(b.start.to_double()),
          Json::number(b.length.to_double()),
          Json::boolean(b.compound),
          Json::number(b.grid.to_double()),
          Json::boolean(b.triplet),
        ])
      }),
    ),
    "notes": Json::array(
      quantized.map(n => {
        Json::array([
          Json::number(n.on.to_double()),
          Json::number(n.off.to_double()),
          Json::number(n.key.to_double()),
          Json::number(n.velocity.to_double()),
          Json::number(n.spelling.to_double()),
        ])
      }),
    ),
  }).stringify()
}

///|
#export_name("staff")
pub fn staff(
  keys : FixedArray[Int32],
  channel : Int32,
  program : Int32,
) -> String {
  let notes : Array[@music.QuantizedNote] = []
  for key in keys {
    notes.push({ on: 0L, off: 960L, key, velocity: 100, spelling: 0, })
  }
  match @music.plan_staff(notes, channel, program) {
    None => Json::null().stringify()
    Some(plan) =>
      Json::object({
        "percussion": Json::boolean(plan.percussion),
        "clefs": Json::array(
          plan.clefs.map(c => {
            Json::array([
              Json::number(c.sign.to_double()),
              Json::number(c.octave.to_double()),
            ])
          }),
        ),
      }).stringify()
  }
}

///|
#export_name("drum")
pub fn drum(key : Int32) -> String {
  let d = @music.drum_of(key)
  Json::array([
    Json::number(d.pitch.step.to_double()),
    Json::number(d.pitch.octave.to_double()),
    Json::number(d.head.to_double()),
    Json::number(d.voice.to_double()),
  ]).stringify()
}

///|
#export_name("divide_values")
pub fn divide_values(
  start : Int32,
  end : Int32,
  beat : Int32,
  length : Int32,
  compound : Bool,
  rest : Bool,
) -> String {
  let values = @music.divide_values(
    start.to_int64(),
    end.to_int64(),
    beat.to_int64(),
    length.to_int64(),
    compound,
    rest,
  )
  Json::array(
    values.map(v => {
      Json::array([
        Json::number(v.offset.to_double()),
        Json::number(v.ticks.to_double()),
        Json::number(v.kind.to_double()),
        Json::number(v.dots.to_double()),
      ])
    }),
  ).stringify()
}

///|
#export_name("voices")
pub fn voices(
  raw_measures : FixedArray[Int32],
  raw_beats : FixedArray[Int32],
  raw_notes : FixedArray[Int32],
  percussion : Bool,
) -> String {
  let measures : Array[@music.MeasureSpan] = []
  for i in 0..<(raw_measures.length() / 2) {
    measures.push({
      start: raw_measures[2 * i].to_int64(),
      length: raw_measures[2 * i + 1].to_int64(),
      time: { beats: 4, beat_type: 4, symbol: "", },
      show_time: false,
      key: None,
      effective_key: { fifths: 0, minor: false, },
      tempo: [],
    })
  }
  let beats : Array[@music.BeatGrid] = []
  for i in 0..<(raw_beats.length() / 3) {
    beats.push({
      start: raw_beats[3 * i].to_int64(),
      length: raw_beats[3 * i + 1].to_int64(),
      grid: raw_beats[3 * i + 2].to_int64(),
      compound: false,
      triplet: false,
    })
  }
  let notes : Array[@music.VoiceNote] = []
  for i in 0..<(raw_notes.length() / 6) {
    notes.push({
      note: {
        on: raw_notes[6 * i].to_int64(),
        off: raw_notes[6 * i + 1].to_int64(),
        key: raw_notes[6 * i + 2],
        velocity: raw_notes[6 * i + 3],
        spelling: raw_notes[6 * i + 4],
      },
      voice_hint: raw_notes[6 * i + 5],
    })
  }
  let result = @music.assign_voices(notes, measures, beats, percussion)
  Json::array(
    result.map(v => {
      Json::array(
        v.map(ch => {
          Json::array([
            Json::number(ch.on.to_double()),
            Json::number(ch.off.to_double()),
            Json::array(
              ch.notes.map(n => {
                Json::array([
                  Json::number(n.note.on.to_double()),
                  Json::number(n.note.off.to_double()),
                  Json::number(n.note.key.to_double()),
                  Json::number(n.note.velocity.to_double()),
                  Json::number(n.note.spelling.to_double()),
                  Json::number(n.voice_hint.to_double()),
                ])
              }),
            ),
          ])
        }),
      )
    }),
  ).stringify()
}

///|
#export_name("staff_events")
pub fn staff_events(
  raw_measures : FixedArray[Int32],
  raw_beats : FixedArray[Int32],
  raw_notes : FixedArray[Int32],
  lyric_ticks : FixedArray[Int32],
  lyric_texts : FixedArray[String],
  staff : Int32,
  percussion : Bool,
) -> String {
  let measures : Array[@music.MeasureSpan] = []
  for i in 0..<(raw_measures.length() / 6) {
    measures.push({
      start: raw_measures[6 * i].to_int64(),
      length: raw_measures[6 * i + 1].to_int64(),
      time: {
        beats: raw_measures[6 * i + 2],
        beat_type: raw_measures[6 * i + 3],
        symbol: "",
      },
      show_time: false,
      key: None,
      effective_key: {
        fifths: raw_measures[6 * i + 4],
        minor: raw_measures[6 * i + 5] != 0,
      },
      tempo: [],
    })
  }
  let beats : Array[@music.BeatGrid] = []
  for i in 0..<(raw_beats.length() / 5) {
    beats.push({
      start: raw_beats[5 * i].to_int64(),
      length: raw_beats[5 * i + 1].to_int64(),
      grid: raw_beats[5 * i + 2].to_int64(),
      compound: raw_beats[5 * i + 3] != 0,
      triplet: raw_beats[5 * i + 4] != 0,
    })
  }
  let notes : Array[@music.VoiceNote] = []
  for i in 0..<(raw_notes.length() / 6) {
    notes.push({
      note: {
        on: raw_notes[6 * i].to_int64(),
        off: raw_notes[6 * i + 1].to_int64(),
        key: raw_notes[6 * i + 2],
        velocity: raw_notes[6 * i + 3],
        spelling: raw_notes[6 * i + 4],
      },
      voice_hint: raw_notes[6 * i + 5],
    })
  }
  let lyrics : Array[@music.NotationLyric] = []
  for i in 0..<lyric_ticks.length() {
    lyrics.push({ tick: lyric_ticks[i].to_int64(), text: lyric_texts[i], })
  }
  let result = @music.write_staff_events(
    notes, measures, beats, lyrics, staff, percussion,
  )
  Json::array(
    result.map(measure => {
      Json::array(
        measure.map(e => {
          let triplet = match e.tuplet_beat {
            Some(tick) => Json::number(tick.to_double())
            None => Json::null()
          }
          let lyric = match e.lyric {
            Some(l) =>
              Json::array([
                Json::string(l.text),
                Json::number(l.syllabic.to_double()),
              ])
            None => Json::null()
          }
          let notes = e.notes.map(n => {
            Json::array([
              Json::number(n.pitch.step.to_double()),
              Json::number(n.pitch.alter.to_double()),
              Json::number(n.pitch.octave.to_double()),
              Json::number(n.head.to_double()),
              Json::boolean(n.tie_start),
              Json::boolean(n.tie_stop),
            ])
          })
          Json::array([
            Json::number(e.offset.to_double()),
            Json::number(e.duration.to_double()),
            Json::number(e.staff.to_double()),
            Json::number(e.voice.to_double()),
            Json::number(e.kind.to_double()),
            Json::number(e.dots.to_double()),
            Json::boolean(e.rest),
            Json::boolean(e.measure_rest),
            triplet,
            Json::array(notes),
            lyric,
          ])
        }),
      )
    }),
  ).stringify()
}

///|
#export_name("glyph")
pub fn glyph(name : String) -> String {
  match @music.music_glyph(name) {
    None => Json::null().stringify()
    Some(g) => {
      let (x0, y0, x1, y1) = g.bbox
      let anchors : Map[String, Json] = Map([])
      for (key, (x, y)) in g.anchors {
        anchors[key] = Json::array([Json::number(x), Json::number(y)])
      }
      Json::object({
        "name": Json::string(g.name),
        "codepoint": Json::number(g.codepoint.to_double()),
        "advance": Json::number(g.advance),
        "bbox": Json::array([
          Json::number(x0),
          Json::number(y0),
          Json::number(x1),
          Json::number(y1),
        ]),
        "anchors": Json::object(anchors),
        "verbs": Json::array(
          g.verbs.to_array().map(v => Json::number(v.to_double())),
        ),
        "coordinates": Json::array(g.coordinates.map(v => Json::number(v))),
      }).stringify()
    }
  }
}

///|
#export_name("positions")
pub fn positions(
  fifths : Int32,
  sign : Int32,
  line : Int32,
  octave : Int32,
  raw_events : FixedArray[Int32],
  raw_notes : FixedArray[Int32],
) -> String {
  let key : @music.KeySig = { fifths, minor: false, }
  let clef : @music.EngravingClef = { sign, line, octave, }
  let events : Array[@music.EngravingEvent] = []
  for i in 0..<(raw_events.length() / 5) {
    let notes : Array[@music.EngravingNote] = []
    let start = raw_events[i * 5 + 3]
    let end = raw_events[i * 5 + 4]
    for n in start..<end {
      notes.push({
        pitch: {
          step: raw_notes[n * 6],
          alter: raw_notes[n * 6 + 1],
          octave: raw_notes[n * 6 + 2],
        },
        accidental: raw_notes[n * 6 + 3],
        cautionary: raw_notes[n * 6 + 4] != 0,
        tie_stop: raw_notes[n * 6 + 5] != 0,
      })
    }
    events.push({
      offset: raw_events[i * 5].to_int64(),
      voice: raw_events[i * 5 + 1],
      grace: raw_events[i * 5 + 2] != 0,
      notes,
    })
  }
  let signs = @music.resolve_accidentals(key, events)
  let all_signs : Array[Json] = []
  let all_positions : Array[Json] = []
  let all_placements : Array[Json] = []
  for i, event in events {
    all_signs.push(
      Json::array(
        signs[i].map(s => {
          match s {
            Some(n) => Json::number(n.to_double())
            None => Json::null()
          }
        }),
      ),
    )
    all_positions.push(
      Json::array(
        event.notes.map(n => {
          Json::number(@music.staff_position(clef, n.pitch).to_double())
        }),
      ),
    )
    all_placements.push(
      Json::array(
        @music.place_accidentals(clef, event.notes, signs[i]).map(p => {
          Json::array([
            Json::number(p.note.to_double()),
            Json::number(p.accidental.to_double()),
            Json::number(p.position.to_double()),
            Json::number(p.column.to_double()),
          ])
        }),
      ),
    )
  }
  Json::object({
    "signs": Json::array(all_signs),
    "positions": Json::array(all_positions),
    "placements": Json::array(all_placements),
    "keyPositions": Json::array(
      @music.key_positions(clef, key).map(v => Json::number(v.to_double())),
    ),
    "keyAlters": Json::array(
      @music.key_alters(key).map(v => Json::number(v.to_double())),
    ),
  }).stringify()
}

///|
#export_name("curve")
pub fn curve(values : FixedArray[Double]) -> String {
  let c = @music.music_curve(
    values[0],
    values[1],
    values[2],
    values[3],
    values[4],
    values[5],
    values[6],
  )
  let (x0, y0, x1, y1) = c.bounds()
  Json::object({
    "verbs": Json::array(
      c.verbs.to_array().map(b => Json::number(b.to_double())),
    ),
    "coordinates": Json::array(c.coordinates.map(v => Json::number(v))),
    "bounds": Json::array([
      Json::number(x0),
      Json::number(y0),
      Json::number(x1),
      Json::number(y1),
    ]),
  }).stringify()
}

///|
#export_name("drawing")
pub fn drawing(
  ops : FixedArray[Double],
  queries : FixedArray[Double],
) -> String {
  let d = @music.MusicDrawing::new()
  let names = ["gClef", "noteheadBlack", "accidentalSharp", "restQuarter"]
  for i in 0..<(ops.length() / 9) {
    let j = i * 9
    match ops[j].to_int() {
      0 => d.rect(ops[j + 1], ops[j + 2], ops[j + 3], ops[j + 4])
      1 =>
        d.line(
          ops[j + 1],
          ops[j + 2],
          ops[j + 3],
          ops[j + 4],
          ops[j + 5],
          ops[j + 6],
        )
      2 =>
        d.glyph(names[ops[j + 1].to_int()], ops[j + 2], ops[j + 3], ops[j + 4])
      3 =>
        d.fill(
          @music.music_quad(
            ops[j + 1],
            ops[j + 2],
            ops[j + 3],
            ops[j + 4],
            ops[j + 5],
            ops[j + 6],
            ops[j + 7],
            ops[j + 8],
          ),
        )
      _ => ()
    }
  }
  let prims = d
    .primitives()
    .map(p => {
      Json::array([
        Json::number(p.kind.to_double()),
        Json::string(p.glyph),
        Json::number(p.x),
        Json::number(p.y),
        Json::number(p.w),
        Json::number(p.h),
        Json::number(p.scale),
        Json::number(p.width),
        Json::number(p.dash),
      ])
    })
  let sky : Array[Json] = []
  for i in 0..<(queries.length() / 4) {
    let j = i * 4
    sky.push(
      Json::number(
        d.skyline(
          queries[j],
          queries[j + 1],
          queries[j + 2],
          queries[j + 3] != 0.0,
        ),
      ),
    )
  }
  Json::object({
    "primitives": Json::array(prims),
    "skylines": Json::array(sky),
  }).stringify()
}

///|
#export_name("paginate")
pub fn paginate(
  raw : FixedArray[Double],
  page_height : Double,
  staff_space : Double,
  title_height : Double,
) -> String {
  let systems : Array[@music.MusicSystemExtent] = []
  let mut i = 0
  while i < raw.length() {
    let page_break = raw[i] != 0.0
    let count = raw[i + 1].to_int()
    i += 2
    let staves : Array[@music.MusicStaffExtent] = []
    for _ in 0..<count {
      staves.push({
        part: raw[i].to_int(),
        above: raw[i + 1],
        below: raw[i + 2],
      })
      i += 3
    }
    systems.push({ staves, page_break, })
  }
  let positions = @music.paginate_systems(
    systems, page_height, staff_space, title_height,
  )
  Json::array(
    positions.map(p => {
      Json::array([
        Json::array(p.staff_y.map(v => Json::number(v))),
        Json::number(p.above),
        Json::number(p.below),
        Json::number(p.top),
        Json::number(p.page.to_double()),
      ])
    }),
  ).stringify()
}

///|
#export_name("barline")
pub fn barline(
  kind : Int32,
  x : Double,
  top : Double,
  bottom : Double,
  tops : FixedArray[Double],
  left : Bool,
) -> String {
  let drawing = @music.MusicDrawing::new()
  let staff_tops : Array[Double] = []
  for y in tops {
    staff_tops.push(y)
  }
  @music.draw_barline(drawing, kind, x, top, bottom, staff_tops, left)
  Json::array(
    drawing
    .primitives()
    .map(p => {
      Json::array([
        Json::number(p.kind.to_double()),
        Json::string(p.glyph),
        Json::number(p.x),
        Json::number(p.y),
        Json::number(p.w),
        Json::number(p.h),
        Json::number(p.scale),
        Json::number(p.width),
        Json::number(p.dash),
      ])
    }),
  ).stringify()
}
