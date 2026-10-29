///|
#export_name("detect")
pub fn detect(data : Bytes) -> Bool {
  @midi.detect(data)
}

///|
#export_name("unwrap")
pub fn unwrap(data : Bytes) -> String {
  try {
    let result = @midi.unwrap_rmid(data)
    Json::object({
      "error": Json::string(""),
      "smf": Json::array(
        result.smf.to_array().map(b => Json::number(b.to_double())),
      ),
      "title": Json::array(
        result.title.to_array().map(b => Json::number(b.to_double())),
      ),
      "copyright": Json::array(
        result.copyright.to_array().map(b => Json::number(b.to_double())),
      ),
    }).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("header")
pub fn header(data : Bytes, tick : Int32) -> String {
  try {
    let h = @midi.read_header(data)
    Json::object({
      "error": Json::string(""),
      "format": Json::number(h.format.to_double()),
      "tracks": Json::number(h.tracks.to_double()),
      "division": Json::number(h.division.to_double()),
      "length": Json::number(h.header_length.to_double()),
      "smpte": Json::boolean(h.smpte),
      "num": Json::number(h.timing_numerator.to_double()),
      "den": Json::number(h.timing_denominator.to_double()),
      "maxTick": Json::number(h.max_tick.to_double()),
      "ppq": Json::number(h.ppq(tick.to_int64()).to_double()),
      "warnings": Json::array(h.warnings.map(Json::string)),
    }).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("varlen")
pub fn varlen(data : Bytes) -> String {
  let (value, count) = @midi.read_varlen(data)
  Json::array([Json::number(value.to_double()), Json::number(count.to_double())]).stringify()
}

///|
#export_name("scan_track")
pub fn scan_track(data : Bytes, max_tick : Int32) -> String {
  let track = @midi.scan_track(data, max_tick.to_int64())
  Json::object({
    "parsed": Json::number(track.parsed.to_double()),
    "sawEnd": Json::boolean(track.saw_end),
    "damaged": Json::boolean(track.damaged),
    "endTick": Json::number(track.end_tick.to_double()),
    "problem": Json::string(track.problem),
  }).stringify()
}

///|
#export_name("track_notes")
pub fn track_notes(data : Bytes, max_tick : Int32) -> String {
  let reader = @midi.MidiTrackReader::new()
  try {
    let track = @midi.scan_track(data, max_tick.to_int64())
    let result = reader.read(track, 0)
    let notes : Array[Json] = []
    let controls : Array[Json] = []
    for ch in 0..<16 {
      for note in result.notes {
        if note.channel == ch {
          notes.push(
            Json::array([
              Json::number(ch.to_double()),
              Json::number(note.on.to_double()),
              Json::number(note.off.to_double()),
              Json::number(note.key.to_double()),
              Json::number(note.velocity.to_double()),
            ]),
          )
        }
      }
      for control in result.controls {
        if control.channel == ch {
          controls.push(
            Json::array([
              Json::number(ch.to_double()),
              Json::number(control.tick.to_double()),
              Json::number(control.kind.to_double()),
              Json::number(control.number.to_double()),
              Json::number(control.value.to_double()),
            ]),
          )
        }
      }
    }
    Json::object({
      "error": Json::string(""),
      "notes": Json::array(notes),
      "controls": Json::array(controls),
      "warnings": Json::array(reader.warnings().map(Json::string)),
    }).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("read_file")
pub fn read_file(data : Bytes) -> String {
  try {
    let file = @midi.read_file(data)
    let smf = match file.smf {
      Some(bytes) =>
        Json::array(bytes.to_array().map(b => Json::number(b.to_double())))
      None => Json::null()
    }
    Json::object({
      "error": Json::string(""),
      "format": Json::number(file.header.format.to_double()),
      "tracks": Json::number(file.tracks.length().to_double()),
      "smf": smf,
      "warnings": Json::array(file.warnings.map(Json::string)),
    }).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("track_meta")
pub fn track_meta(data : Bytes) -> String {
  let reader = @midi.MidiTrackReader::new()
  try {
    let result = reader.read(@midi.scan_track(data, 1000000L), 0)
    let names = result.channel_names.map(bytes => {
      Json::array(bytes.to_array().map(b => Json::number(b.to_double())))
    })
    let texts = result.texts.map(item => {
      Json::array([
        Json::number(item.tick.to_double()),
        Json::number(item.kind.to_double()),
        Json::array(item.data.to_array().map(b => Json::number(b.to_double()))),
      ])
    })
    let tempos = result.tempos.map(item => {
      Json::array([Json::number(item.tick.to_double()), Json::number(item.bpm)])
    })
    let times = result.times.map(item => {
      Json::array([
        Json::number(item.tick.to_double()),
        Json::number(item.beats.to_double()),
        Json::number(item.beat_type.to_double()),
      ])
    })
    let keys = result.keys.map(item => {
      Json::array([
        Json::number(item.tick.to_double()),
        Json::number(item.fifths.to_double()),
        Json::boolean(item.minor),
      ])
    })
    Json::object({
      "name": Json::array(
        result.name.to_array().map(b => Json::number(b.to_double())),
      ),
      "instrument": Json::array(
        result.instrument.to_array().map(b => Json::number(b.to_double())),
      ),
      "copyright": Json::array(
        result.copyright.to_array().map(b => Json::number(b.to_double())),
      ),
      "channels": Json::array(names),
      "texts": Json::array(texts),
      "tempos": Json::array(tempos),
      "times": Json::array(times),
      "keys": Json::array(keys),
      "warnings": Json::array(reader.warnings().map(Json::string)),
    }).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("decode_text")
pub fn decode_text(data : Bytes) -> String {
  try {
    let file = @midi.read_file(data)
    let decoder = @midi.MidiTextDecoder::new(file)
    let texts : Array[Json] = []
    let names : Array[Json] = []
    for track in file.tracks {
      for field in track.notes.texts {
        texts.push(Json::string(decoder.text(field.data)))
        names.push(Json::string(decoder.name(field.data)))
      }
    }
    Json::object({
      "shiftJis": Json::boolean(decoder.uses_shift_jis()),
      "texts": Json::array(texts),
      "names": Json::array(names),
    }).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("file_credits")
pub fn file_credits(data : Bytes) -> String {
  try {
    let file = @midi.read_file(data)
    let credits = @midi.credits(file)
    let names : Array[Json] = []
    for channel in 0..<16 {
      names.push(
        Json::array([
          Json::string(@midi.track_name(file, 0, channel, false, 0)),
          Json::string(@midi.track_name(file, 0, channel, true, channel * 7)),
        ]),
      )
    }
    Json::object({
      "title": Json::string(credits.title),
      "composer": Json::string(credits.composer),
      "lyricist": Json::string(credits.lyricist),
      "arranger": Json::string(credits.arranger),
      "copyright": Json::string(credits.copyright),
      "names": Json::array(names),
    }).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("performance")
pub fn performance(data : Bytes) -> String {
  try {
    let p = @midi.performance(@midi.read_file(data))
    let tracks = p.tracks.map(t => {
      Json::object({
        "name": Json::string(t.name),
        "channel": Json::number(t.channel.to_double()),
        "program": Json::number(t.program.to_double()),
        "volume": Json::number(t.volume.to_double()),
        "pan": Json::number(t.pan.to_double()),
        "notes": Json::array(
          t.notes.map(n => {
            Json::array([
              Json::number(n.tick.to_double()),
              Json::number(n.duration.to_double()),
              Json::number(n.key.to_double()),
              Json::number(n.velocity.to_double()),
            ])
          }),
        ),
        "controls": Json::array(
          t.controls.map(c => {
            Json::array([
              Json::number(c.tick.to_double()),
              Json::number(c.kind.to_double()),
              Json::number(c.number.to_double()),
              Json::number(c.value.to_double()),
            ])
          }),
        ),
      })
    })
    Json::object({
      "tracks": Json::array(tracks),
      "end": Json::number(p.end.to_double()),
      "division": Json::number(p.division.to_double()),
      "warnings": Json::array(p.warnings.map(Json::string)),
      "tempos": Json::array(
        p.tempos.map(t => {
          Json::array([Json::number(t.tick.to_double()), Json::number(t.bpm)])
        }),
      ),
      "times": Json::array(
        p.times.map(t => {
          Json::array([
            Json::number(t.tick.to_double()),
            Json::number(t.beats.to_double()),
            Json::number(t.beat_type.to_double()),
          ])
        }),
      ),
      "keys": Json::array(
        p.keys.map(k => {
          Json::array([
            Json::number(k.tick.to_double()),
            Json::number(k.fifths.to_double()),
            Json::boolean(k.minor),
          ])
        }),
      ),
    }).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("lyrics")
pub fn lyrics(data : Bytes) -> String {
  try {
    let p = @midi.performance(@midi.read_file(data))
    Json::array(
      p.tracks.map(t => {
        Json::array(
          t.lyrics.map(l => {
            Json::array([Json::number(l.tick.to_double()), Json::string(l.text)])
          }),
        )
      }),
    ).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("score")
pub fn score(data : Bytes) -> String {
  try {
    let result = @midi.notate_file(@midi.read_file(data))
    let measures = result.timeline.measures.map(m => {
      let time = if m.show_time {
        Json::array([
          Json::number(m.time.beats.to_double()),
          Json::number(m.time.beat_type.to_double()),
          Json::string(m.time.symbol),
        ])
      } else {
        Json::null()
      }
      let tempos = m.tempo.map(t => {
        Json::array([
          Json::number(t.offset.to_double()),
          Json::number(t.dots.to_double()),
          Json::number(t.per_minute),
        ])
      })
      Json::array([
        Json::number(m.length.to_double()),
        time,
        Json::array(tempos),
      ])
    })
    let parts = result.parts.map(p => {
      let clefs = p.clefs.map(c => {
        Json::array([
          Json::number(c.sign.to_double()),
          Json::number(c.octave.to_double()),
        ])
      })
      let pms = p.measures.map(m => {
        let key = match m.key {
          Some(k) =>
            Json::array([
              Json::number(k.fifths.to_double()),
              Json::boolean(k.minor),
            ])
          None => Json::null()
        }
        let events = m.events.map(e => {
          let ns = e.notes.map(n => {
            Json::array([
              Json::number(n.pitch.step.to_double()),
              Json::number(n.pitch.alter.to_double()),
              Json::number(n.pitch.octave.to_double()),
              Json::number(n.head.to_double()),
              Json::boolean(n.tie_start),
              Json::boolean(n.tie_stop),
            ])
          })
          let lyric = match e.lyric {
            Some(l) =>
              Json::array([
                Json::string(l.text),
                Json::number(l.syllabic.to_double()),
              ])
            None => Json::null()
          }
          Json::array([
            Json::number(e.offset.to_double()),
            Json::number(e.duration.to_double()),
            Json::number(e.staff.to_double()),
            Json::number(e.voice.to_double()),
            Json::number(e.kind.to_double()),
            Json::number(e.dots.to_double()),
            Json::boolean(e.rest),
            Json::boolean(e.measure_rest),
            Json::boolean(e.tuplet_beat is Some(_)),
            Json::array(ns),
            lyric,
          ])
        })
        Json::array([key, Json::array(events)])
      })
      Json::object({
        "name": Json::string(p.name),
        "percussion": Json::boolean(p.percussion),
        "clefs": Json::array(clefs),
        "measures": Json::array(pms),
      })
    })
    Json::object({
      "title": Json::string(result.title),
      "composer": Json::string(result.composer),
      "lyricist": Json::string(result.lyricist),
      "arranger": Json::string(result.arranger),
      "copyright": Json::string(result.copyright),
      "error": Json::string(result.error),
      "warnings": Json::array(result.timeline.warnings.map(Json::string)),
      "measures": Json::array(measures),
      "parts": Json::array(parts),
    }).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("prepare_score")
pub fn prepare_score(data : Bytes) -> String {
  try {
    let p = @music.prepare_score(@midi.notate_file(@midi.read_file(data)))
    let staves = p.staves.map(s => {
      Json::array([
        Json::number(s.part.to_double()),
        Json::number(s.staff.to_double()),
      ])
    })
    let rows = p.measures.map(row => {
      Json::array(
        row.map(m => {
          let signs = m.accidentals.map(group => {
            Json::array(
              group.map(a => {
                match a {
                  Some(v) => Json::number(v.to_double())
                  None => Json::null()
                }
              }),
            )
          })
          let events = m.events.map(e => {
            Json::array([
              Json::number(e.offset.to_double()),
              Json::number(e.voice.to_double()),
              Json::boolean(e.rest),
              Json::boolean(e.measure_rest),
            ])
          })
          Json::object({
            "clef": Json::array([
              Json::number(m.clef.sign.to_double()),
              Json::number(m.clef.line.to_double()),
              Json::number(m.clef.octave.to_double()),
            ]),
            "clefChange": Json::boolean(m.clef_change),
            "key": Json::array([
              Json::number(m.key.fifths.to_double()),
              Json::boolean(m.key.minor),
            ]),
            "previousKey": Json::array([
              Json::number(m.previous_key.fifths.to_double()),
              Json::boolean(m.previous_key.minor),
            ]),
            "keyChange": Json::boolean(m.key_change),
            "events": Json::array(events),
            "signs": Json::array(signs),
            "voices": Json::number(m.voices.to_double()),
          })
        }),
      )
    })
    Json::object({
      "staves": Json::array(staves),
      "grand": Json::boolean(p.grand),
      "starts": Json::array(p.starts.map(v => Json::number(v.to_double()))),
      "times": Json::array(
        p.times.map(t => {
          Json::array([
            Json::number(t.beats.to_double()),
            Json::number(t.beat_type.to_double()),
          ])
        }),
      ),
      "counts": Json::array(p.counts.map(v => Json::number(v.to_double()))),
      "measures": Json::array(rows),
    }).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("score_columns")
pub fn score_columns(
  data : Bytes,
  texts : FixedArray[String],
  widths : FixedArray[Double],
) -> String {
  try {
    let score = @midi.notate_file(@midi.read_file(data))
    let prepared = @music.prepare_score(score)
    let map : Map[String, Double] = Map([])
    for i in 0..<texts.length() {
      map[texts[i]] = widths[i]
    }
    let columns = @music.build_columns(score, prepared, text => {
      map.get(text).unwrap_or(0.0)
    })
    Json::array(
      columns.map(c => {
        Json::object({
          "header": Json::number(c.header),
          "lead": Json::number(c.lead),
          "slots": Json::array(
            c.slots.map(s => {
              Json::array([
                Json::number(s.offset.to_double()),
                Json::number(s.duration.to_double()),
                Json::number(s.pre),
                Json::number(s.head),
                Json::number(s.post),
                Json::number(s.lyric),
                Json::number(s.ideal),
                Json::number(s.minimum),
              ])
            }),
          ),
        })
      }),
    ).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("score_systems")
pub fn score_systems(
  data : Bytes,
  texts : FixedArray[String],
  widths : FixedArray[Double],
  width : Double,
  indent : Double,
) -> String {
  try {
    let score = @midi.notate_file(@midi.read_file(data))
    let prepared = @music.prepare_score(score)
    let map : Map[String, Double] = Map([])
    for i in 0..<texts.length() {
      map[texts[i]] = widths[i]
    }
    let columns = @music.build_columns(score, prepared, text => {
      map.get(text).unwrap_or(0.0)
    })
    let systems = @music.break_systems(score, prepared, columns, width, indent)
    Json::array(
      systems.map(s => {
        Json::array([
          Json::number(s.first.to_double()),
          Json::number(s.last.to_double()),
          Json::number(s.header),
          Json::number(s.width),
          Json::array(
            s.columns.map(c => {
              Json::array([
                Json::number(c.index.to_double()),
                Json::number(c.x),
                Json::number(c.width),
                Json::number(c.body_start),
                Json::array(c.slots.map(slot => Json::number(slot.x))),
              ])
            }),
          ),
        ])
      }),
    ).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("score_headers")
pub fn score_headers(
  data : Bytes,
  texts : FixedArray[String],
  widths : FixedArray[Double],
  width : Double,
  indent : Double,
) -> String {
  try {
    let score = @midi.notate_file(@midi.read_file(data))
    let prepared = @music.prepare_score(score)
    let map : Map[String, Double] = Map([])
    for i in 0..<texts.length() {
      map[texts[i]] = widths[i]
    }
    let columns = @music.build_columns(score, prepared, text => {
      map.get(text).unwrap_or(0.0)
    })
    let systems = @music.break_systems(score, prepared, columns, width, indent)
    let out : Array[Json] = []
    for sys in systems {
      let staves : Array[Json] = []
      for i in 0..<prepared.staves.length() {
        let drawing = @music.staff_header(score, prepared, sys, i)
        for m in sys.first..<=sys.last {
          @music.staff_measure_header(drawing, score, prepared, sys, i, m)
        }
        let p = drawing
          .primitives()
          .map(v => {
            Json::array([
              Json::number(v.kind.to_double()),
              Json::string(v.glyph),
              Json::number(v.x),
              Json::number(v.y),
              Json::number(v.w),
              Json::number(v.h),
              Json::number(v.scale),
            ])
          })
        staves.push(
          Json::object({
            "primitives": Json::array(p),
            "above": Json::number(drawing.skyline(-1.0e9, 1.0e9, 0.0, true)),
            "below": Json::number(drawing.skyline(-1.0e9, 1.0e9, 4.0, false)),
          }),
        )
      }
      out.push(Json::array(staves))
    }
    Json::array(out).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("score_rests")
pub fn score_rests(
  data : Bytes,
  texts : FixedArray[String],
  widths : FixedArray[Double],
  width : Double,
  indent : Double,
) -> String {
  try {
    let score = @midi.notate_file(@midi.read_file(data))
    let prepared = @music.prepare_score(score)
    let map : Map[String, Double] = Map([])
    for i in 0..<texts.length() {
      map[texts[i]] = widths[i]
    }
    let columns = @music.build_columns(score, prepared, text => {
      map.get(text).unwrap_or(0.0)
    })
    let systems = @music.break_systems(score, prepared, columns, width, indent)
    let out : Array[Json] = []
    for sys in systems {
      for staff in 0..<prepared.staves.length() {
        for mi in sys.first..<=sys.last {
          let col = sys.columns[mi - sys.first]
          for event in prepared.measures[mi][staff].events {
            if !event.rest {
              continue
            }
            for slot in col.slots {
              if slot.slot.offset != event.offset {
                continue
              }
              let d = @music.MusicDrawing::new()
              let l = @music.draw_staff_rest(
                d,
                score,
                prepared,
                sys,
                staff,
                mi,
                event,
                col.x + slot.x,
              )
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
                  ])
                })
              out.push(
                Json::array([
                  Json::number(mi.to_double()),
                  Json::number(staff.to_double()),
                  Json::number(event.offset.to_double()),
                  Json::array([
                    Json::number(l.x),
                    Json::number(l.right),
                    Json::number(l.top),
                    Json::number(l.bottom),
                  ]),
                  Json::array(prims),
                ]),
              )
              break
            }
          }
        }
      }
    }
    Json::array(out).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("score_notes")
pub fn score_notes(
  data : Bytes,
  texts : FixedArray[String],
  widths : FixedArray[Double],
  width : Double,
  indent : Double,
) -> String {
  try {
    let score = @midi.notate_file(@midi.read_file(data))
    let prepared = @music.prepare_score(score)
    let map : Map[String, Double] = Map([])
    for i in 0..<texts.length() {
      map[texts[i]] = widths[i]
    }
    let columns = @music.build_columns(score, prepared, text => {
      map.get(text).unwrap_or(0.0)
    })
    let systems = @music.break_systems(score, prepared, columns, width, indent)
    let out : Array[Json] = []
    for sys in systems {
      for staff in 0..<prepared.staves.length() {
        for mi in sys.first..<=sys.last {
          let col = sys.columns[mi - sys.first]
          let sm = prepared.measures[mi][staff]
          for i, event in sm.events {
            if event.rest {
              continue
            }
            for slot in col.slots {
              if slot.slot.offset != event.offset {
                continue
              }
              let d = @music.MusicDrawing::new()
              let l = @music.arrange_staff_note(
                d,
                sm,
                event,
                sm.accidentals[i],
                col.x + slot.x,
                1.0,
              )
              @music.draw_isolated_stem(d, l, 1.0)
              let heads = l.heads.map(h => {
                Json::array([
                  Json::number(h.note.to_double()),
                  Json::number(h.position.to_double()),
                  Json::number(h.x),
                  Json::string(h.glyph),
                ])
              })
              let layout = Json::array([
                Json::boolean(l.up),
                Json::boolean(l.stem),
                Json::number(l.stem_x),
                Json::number(l.stem_y0),
                Json::number(l.stem_y1),
                Json::number(l.top),
                Json::number(l.bottom),
                Json::number(l.right),
                Json::number(l.flags.to_double()),
                Json::array(heads),
              ])
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
                  ])
                })
              out.push(
                Json::array([
                  Json::number(mi.to_double()),
                  Json::number(staff.to_double()),
                  Json::number(event.offset.to_double()),
                  layout,
                  Json::array(prims),
                ]),
              )
              break
            }
          }
        }
      }
    }
    Json::array(out).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("score_beams")
pub fn score_beams(
  data : Bytes,
  texts : FixedArray[String],
  widths : FixedArray[Double],
  width : Double,
  indent : Double,
) -> String {
  try {
    let score = @midi.notate_file(@midi.read_file(data))
    let prepared = @music.prepare_score(score)
    let map : Map[String, Double] = Map([])
    for i in 0..<texts.length() {
      map[texts[i]] = widths[i]
    }
    let columns = @music.build_columns(score, prepared, text => {
      map.get(text).unwrap_or(0.0)
    })
    let systems = @music.break_systems(score, prepared, columns, width, indent)
    let out : Array[Json] = []
    for sys in systems {
      for staff in 0..<prepared.staves.length() {
        for mi in sys.first..<=sys.last {
          let col = sys.columns[mi - sys.first]
          let sm = prepared.measures[mi][staff]
          let voices : Array[Int32] = []
          for event in sm.events {
            if !event.rest && !voices.contains(event.voice) {
              voices.push(event.voice)
            }
          }
          for voice in voices {
            let events : Array[@music.ScoreEvent] = []
            let original : Array[Int32] = []
            for i, event in sm.events {
              if !event.rest && event.voice == voice {
                events.push(event)
                original.push(i)
              }
            }
            let groups = @music.beam_groups(prepared.times[mi], sm, events)
            for group in groups {
              let d = @music.MusicDrawing::new()
              let selected : Array[@music.ScoreEvent] = []
              let layouts : Array[@music.NoteLayout] = []
              let local_indices : Array[Int32] = []
              for idx in group.indices {
                let event = events[idx]
                let mut x = 0.0
                for slot in col.slots {
                  if slot.slot.offset == event.offset {
                    x = col.x + slot.x
                    break
                  }
                }
                layouts.push(
                  @music.arrange_staff_note(
                    d,
                    sm,
                    event,
                    sm.accidentals[original[idx]],
                    x,
                    1.0,
                    beam_direction=Some(group.up),
                    beamed=true,
                  ),
                )
                local_indices.push(selected.length())
                selected.push(event)
              }
              @music.draw_beam(
                d,
                selected,
                layouts,
                local_indices,
                group.up,
                1.0,
              )
              let prims = d
                .primitives()
                .map(p => {
                  let outline = match p.outline {
                    Some(o) =>
                      Json::array(o.coordinates.map(v => Json::number(v)))
                    None => Json::null()
                  }
                  Json::array([
                    Json::number(p.kind.to_double()),
                    Json::string(p.glyph),
                    Json::number(p.x),
                    Json::number(p.y),
                    Json::number(p.w),
                    Json::number(p.h),
                    Json::number(p.scale),
                    outline,
                  ])
                })
              out.push(
                Json::array([
                  Json::number(mi.to_double()),
                  Json::number(staff.to_double()),
                  Json::number(voice.to_double()),
                  Json::array(
                    group.indices.map(i => Json::number(i.to_double())),
                  ),
                  Json::boolean(group.up),
                  Json::array(layouts.map(l => Json::number(l.stem_y1))),
                  Json::array(prims),
                ]),
              )
            }
          }
        }
      }
    }
    Json::array(out).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("score_basic_staff")
pub fn score_basic_staff(
  data : Bytes,
  texts : FixedArray[String],
  widths : FixedArray[Double],
  width : Double,
  indent : Double,
) -> String {
  try {
    let score = @midi.notate_file(@midi.read_file(data))
    let prepared = @music.prepare_score(score)
    let map : Map[String, Double] = Map([])
    for i in 0..<texts.length() {
      map[texts[i]] = widths[i]
    }
    let columns = @music.build_columns(score, prepared, text => {
      map.get(text).unwrap_or(0.0)
    })
    let systems = @music.break_systems(score, prepared, columns, width, indent)
    let out : Array[Json] = []
    for sys in systems {
      let staves : Array[Json] = []
      for staff in 0..<prepared.staves.length() {
        let layout = @music.layout_basic_staff(score, prepared, sys, staff)
        let d = layout.drawing
        let prims = d
          .primitives()
          .map(p => {
            let outline = match p.outline {
              Some(o) => Json::array(o.coordinates.map(v => Json::number(v)))
              None => Json::null()
            }
            Json::array([
              Json::number(p.kind.to_double()),
              Json::string(p.glyph),
              Json::number(p.x),
              Json::number(p.y),
              Json::number(p.w),
              Json::number(p.h),
              Json::number(p.scale),
              outline,
            ])
          })
        staves.push(
          Json::object({
            "primitives": Json::array(prims),
            "above": Json::number(d.skyline(-1.0e9, 1.0e9, 0.0, true)),
            "below": Json::number(d.skyline(-1.0e9, 1.0e9, 4.0, false)),
          }),
        )
      }
      out.push(Json::array(staves))
    }
    Json::array(out).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("score_staff_marks")
pub fn score_staff_marks(
  data : Bytes,
  texts : FixedArray[String],
  widths : FixedArray[Double],
  width : Double,
  indent : Double,
) -> String {
  try {
    let score = @midi.notate_file(@midi.read_file(data))
    let prepared = @music.prepare_score(score)
    let map : Map[String, Double] = Map([])
    for i in 0..<texts.length() {
      map[texts[i]] = widths[i]
    }
    let columns = @music.build_columns(score, prepared, text => {
      map.get(text).unwrap_or(0.0)
    })
    let systems = @music.break_systems(score, prepared, columns, width, indent)
    let out : Array[Json] = []
    for sys in systems {
      let staves : Array[Json] = []
      for staff in 0..<prepared.staves.length() {
        let layout = @music.layout_basic_staff(score, prepared, sys, staff)
        @music.draw_staff_ties(layout, prepared, sys, staff)
        @music.draw_staff_tuplets(layout, prepared, staff)
        let d = layout.drawing
        let prims = d
          .primitives()
          .map(p => {
            let outline = match p.outline {
              Some(o) => Json::array(o.coordinates.map(v => Json::number(v)))
              None => Json::null()
            }
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
              outline,
            ])
          })
        staves.push(
          Json::object({
            "primitives": Json::array(prims),
            "above": Json::number(d.skyline(-1.0e9, 1.0e9, 0.0, true)),
            "below": Json::number(d.skyline(-1.0e9, 1.0e9, 4.0, false)),
          }),
        )
      }
      out.push(Json::array(staves))
    }
    Json::array(out).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("score_staff_lyrics")
pub fn score_staff_lyrics(
  data : Bytes,
  texts : FixedArray[String],
  widths : FixedArray[Double],
  metrics : FixedArray[Double],
  width : Double,
  indent : Double,
) -> String {
  try {
    let score = @midi.notate_file(@midi.read_file(data))
    let prepared = @music.prepare_score(score)
    let map : Map[String, Double] = Map([])
    let metric_map : Map[String, @music.MusicTextMetrics] = Map([])
    for i in 0..<texts.length() {
      map[texts[i]] = widths[i]
      metric_map[texts[i]] = {
        width: metrics[i * 3],
        ascent: metrics[i * 3 + 1],
        descent: metrics[i * 3 + 2],
      }
    }
    let columns = @music.build_columns(score, prepared, text => {
      map.get(text).unwrap_or(0.0)
    })
    let systems = @music.break_systems(score, prepared, columns, width, indent)
    let out : Array[Json] = []
    for sys in systems {
      let staves : Array[Json] = []
      for staff in 0..<prepared.staves.length() {
        let layout = @music.layout_basic_staff(score, prepared, sys, staff)
        @music.draw_staff_ties(layout, prepared, sys, staff)
        @music.draw_staff_tuplets(layout, prepared, staff)
        @music.draw_staff_lyrics(layout, text => {
          metric_map
          .get(text)
          .unwrap_or({ width: 0.0, ascent: 0.0, descent: 0.0, })
        })
        let d = layout.drawing
        let prims = d
          .primitives()
          .map(p => {
            let outline = match p.outline {
              Some(o) => Json::array(o.coordinates.map(v => Json::number(v)))
              None => Json::null()
            }
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
              outline,
              Json::string(if p.kind == 4 { p.text } else { "" }),
              Json::number(p.align.to_double()),
              Json::number(p.mark.to_double()),
              Json::string(if p.kind == 5 { p.text } else { "" }),
            ])
          })
        staves.push(
          Json::object({
            "primitives": Json::array(prims),
            "above": Json::number(d.skyline(-1.0e9, 1.0e9, 0.0, true)),
            "below": Json::number(d.skyline(-1.0e9, 1.0e9, 4.0, false)),
          }),
        )
      }
      out.push(Json::array(staves))
    }
    Json::array(out).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("score_system_marks")
pub fn score_system_marks(
  data : Bytes,
  texts : FixedArray[String],
  widths : FixedArray[Double],
  metrics : FixedArray[Double],
  system_texts : FixedArray[String],
  system_metrics : FixedArray[Double],
  width : Double,
  indent : Double,
) -> String {
  try {
    let score = @midi.notate_file(@midi.read_file(data))
    let prepared = @music.prepare_score(score)
    let map : Map[String, Double] = Map([])
    let metric_map : Map[String, @music.MusicTextMetrics] = Map([])
    for i in 0..<texts.length() {
      map[texts[i]] = widths[i]
      metric_map[texts[i]] = {
        width: metrics[i * 3],
        ascent: metrics[i * 3 + 1],
        descent: metrics[i * 3 + 2],
      }
    }
    let system_map : Map[String, @music.MusicTextMetrics] = Map([])
    for i in 0..<system_texts.length() {
      system_map[system_texts[i]] = {
        width: system_metrics[i * 3],
        ascent: system_metrics[i * 3 + 1],
        descent: system_metrics[i * 3 + 2],
      }
    }
    let columns = @music.build_columns(score, prepared, text => {
      map.get(text).unwrap_or(0.0)
    })
    let systems = @music.break_systems(score, prepared, columns, width, indent)
    let out : Array[Json] = []
    for sys in systems {
      let staves : Array[Json] = []
      for staff in 0..<prepared.staves.length() {
        let layout = @music.layout_basic_staff(score, prepared, sys, staff)
        @music.draw_staff_ties(layout, prepared, sys, staff)
        @music.draw_staff_tuplets(layout, prepared, staff)
        @music.draw_staff_lyrics(layout, text => {
          metric_map
          .get(text)
          .unwrap_or({ width: 0.0, ascent: 0.0, descent: 0.0, })
        })
        if staff == 0 {
          @music.draw_system_marks(layout, score, prepared, sys, (
            text,
            _,
            italic,
          ) => {
            system_map
            .get((if italic { "i|" } else { "n|" }) + text)
            .unwrap_or({ width: 0.0, ascent: 0.0, descent: 0.0, })
          })
        }
        let d = layout.drawing
        let prims = d
          .primitives()
          .map(p => {
            let outline = match p.outline {
              Some(o) => Json::array(o.coordinates.map(v => Json::number(v)))
              None => Json::null()
            }
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
              outline,
              Json::string(if p.kind == 4 { p.text } else { "" }),
              Json::number(p.align.to_double()),
              Json::number(p.mark.to_double()),
              Json::string(if p.kind == 5 { p.text } else { "" }),
            ])
          })
        staves.push(
          Json::object({
            "primitives": Json::array(prims),
            "above": Json::number(d.skyline(-1.0e9, 1.0e9, 0.0, true)),
            "below": Json::number(d.skyline(-1.0e9, 1.0e9, 4.0, false)),
          }),
        )
      }
      out.push(Json::array(staves))
    }
    Json::array(out).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("score_layout")
pub fn score_layout(
  data : Bytes,
  width : Double,
  height : Double,
  staff_space : Double,
  title : String,
  metric_names : FixedArray[String],
  raw_metrics : FixedArray[Double],
) -> String {
  try {
    let original = @midi.notate_file(@midi.read_file(data))
    // The Go fixture reconstructs the score's notes, but not its metadata.
    let score : @music.NotatedScore = {
      title: "",
      subtitle: "",
      composer: "",
      lyricist: "",
      arranger: "",
      copyright: "",
      timeline: original.timeline,
      parts: original.parts,
      error: original.error,
    }
    let metrics : Map[String, @music.MusicTextMetrics] = Map([])
    for i in 0..<metric_names.length() {
      metrics[metric_names[i]] = {
        width: raw_metrics[i * 3],
        ascent: raw_metrics[i * 3 + 1],
        descent: raw_metrics[i * 3 + 2],
      }
    }
    match
      @music.layout_midi_score(score, { width, height, staff_space, title, }, (
        text,
        size,
        italic,
      ) => {
        let key = (if italic { "i|" } else { "n|" }) +
          size.to_string() +
          "|" +
          text
        metrics.get(key).unwrap_or({ width: 0.0, ascent: 0.0, descent: 0.0, })
      }) {
      None => Json::null().stringify()
      Some(layout) => {
        let systems = layout.systems.map(sys => {
          let extents = sys.staves.map(staff => {
            Json::array([
              Json::number(staff.drawing.skyline(-1.0e9, 1.0e9, 0.0, true)),
              Json::number(staff.drawing.skyline(-1.0e9, 1.0e9, 4.0, false)),
            ])
          })
          let p = sys.placement
          Json::array([
            Json::number(sys.system.first.to_double()),
            Json::number(sys.system.last.to_double()),
            Json::number(sys.system.header),
            Json::number(sys.system.width),
            Json::number(sys.left),
            Json::array(p.staff_y.map(v => Json::number(v))),
            Json::number(p.above),
            Json::number(p.below),
            Json::number(p.top),
            Json::number(p.page.to_double()),
            Json::array(extents),
          ])
        })
        Json::array([
          Json::number(layout.width),
          Json::number(layout.height),
          Json::number(layout.staff_space),
          Json::string(layout.title),
          Json::number(layout.title_height),
          Json::array(systems),
        ]).stringify()
      }
    }
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}

///|
#export_name("render_pages")
pub fn render_pages(
  data : Bytes,
  width : Double,
  height : Double,
  sp : Double,
  title : String,
) -> String {
  try {
    let original = @midi.notate_file(@midi.read_file(data))
    let score : @music.NotatedScore = {
      title: "",
      subtitle: "",
      composer: "",
      lyricist: "",
      arranger: "",
      copyright: "",
      timeline: original.timeline,
      parts: original.parts,
      error: original.error,
    }
    let doc = @core.DocumentWriter::new()
    let out = @music.render_midi_pages(score, @db.Database::new(), doc, {
      page: { width, height, staff_space: sp, title, },
      system_fonts: true,
      no_subset: false,
      ignore_restrictions: false,
      no_woff2: true,
      document_language: "",
    })
    Json::array([
      Json::string(out.glyph_paths.unwrap_or("")),
      Json::array(out.objects.map(v => Json::string(v))),
    ]).stringify()
  } catch {
    err => Json::object({ "error": Json::string(err.to_string()) }).stringify()
  }
}

///|
#export_name("render_pages_fonts")
pub fn render_pages_fonts(
  data : Bytes,
  font_name : String,
  font_data : Bytes,
  width : Double,
  height : Double,
  sp : Double,
  title : String,
) -> String {
  try {
    let original = @midi.notate_file(@midi.read_file(data))
    let score : @music.NotatedScore = {
      title: "",
      subtitle: "",
      composer: "",
      lyricist: "",
      arranger: "",
      copyright: "",
      timeline: original.timeline,
      parts: original.parts,
      error: original.error,
    }
    let doc = @core.DocumentWriter::new()
    let db = @db.Database::new()
    ignore(db.add_file(font_name, font_data))
    let out = @music.render_midi_pages(score, db, doc, {
      page: { width, height, staff_space: sp, title, },
      system_fonts: false,
      no_subset: false,
      ignore_restrictions: false,
      no_woff2: true,
      document_language: "",
    })
    Json::array([
      Json::string(out.glyph_paths.unwrap_or("")),
      Json::array(out.objects.map(v => Json::string(v))),
      Json::number(out.embedded_fonts.to_double()),
      Json::array(out.warnings.map(v => Json::string(v))),
    ]).stringify()
  } catch {
    err => Json::object({ "error": Json::string(err.to_string()) }).stringify()
  }
}

///|
#export_name("score_cues")
pub fn score_cues(
  data : Bytes,
  width : Double,
  height : Double,
  sp : Double,
  title : String,
  division : Int32,
) -> String {
  try {
    let original = @midi.notate_file(@midi.read_file(data))
    let score : @music.NotatedScore = {
      title: "",
      subtitle: "",
      composer: "",
      lyricist: "",
      arranger: "",
      copyright: "",
      timeline: original.timeline,
      parts: original.parts,
      error: original.error,
    }
    let doc = @core.DocumentWriter::new()
    let out = @music.render_midi_pages(score, @db.Database::new(), doc, {
      page: { width, height, staff_space: sp, title, },
      system_fonts: true,
      no_subset: false,
      ignore_restrictions: false,
      no_woff2: true,
      document_language: "",
    })
    let (cues, _) = @music.midi_score_cues(score, out.layout, division)
    let bytes = @core.encode_cues(cues)
    let result : Array[Json] = []
    for byte in bytes {
      result.push(Json::number(byte.to_int().to_double()))
    }
    Json::array(result).stringify()
  } catch {
    err => Json::object({ "error": Json::string(err.to_string()) }).stringify()
  }
}

///|
#export_name("generated_smf")
pub fn generated_smf(data : Bytes) -> String {
  try {
    let performance = @midi.performance(@midi.read_file(data))
    let smf = @midi.performance_smf(performance)
    let output : Array[Json] = []
    for byte in smf {
      output.push(Json::number(byte.to_int().to_double()))
    }
    Json::array(output).stringify()
  } catch {
    @midi.InvalidMidiInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
  }
}
