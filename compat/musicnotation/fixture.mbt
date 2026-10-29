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
