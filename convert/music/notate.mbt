///|
/// A performance track to be turned into written notation.
pub(all) struct PerformanceTrack {
  name : String
  channel : Int32
  program : Int32
  notes : Array[NotationNote]
  lyrics : Array[NotationLyric]
}

///|
/// Performance timing and tracks accepted by the notation engine.
pub(all) struct Performance {
  title : String
  subtitle : String
  composer : String
  lyricist : String
  arranger : String
  copyright : String
  tracks : Array[PerformanceTrack]
  times : Array[TimeChange]
  keys : Array[KeyChange]
  tempos : Array[TempoChange]
  end : Int64
}

///|
pub(all) struct NotatedPartMeasure {
  key : KeySig?
  events : Array[ScoreEvent]
}

///|
pub(all) struct NotatedPart {
  name : String
  clefs : Array[NotationClef]
  percussion : Bool
  measures : Array[NotatedPartMeasure]
}

///|
/// A score before engraving and page layout.
pub(all) struct NotatedScore {
  title : String
  subtitle : String
  composer : String
  lyricist : String
  arranger : String
  copyright : String
  timeline : ScoreTimeline
  parts : Array[NotatedPart]
  error : String
}

///|
/// Turn a performance into measures, staves, notes, rests and lyrics.
pub fn notate(
  performance : Performance,
  time_override~ : TimeSig? = None,
  key_override~ : KeySig? = None,
) -> NotatedScore {
  let mut end = 0L
  let histogram : Array[Double] = [
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  ]
  let mut flats = 0
  let mut track_count = 0
  for track in performance.tracks {
    if !track.notes.is_empty() {
      track_count += 1
    }
    for note in track.notes {
      end = Int64::max(end, note.tick + Int64::max(note.duration, 1L))
      if track.channel != 9 {
        let pc = (note.key % 12 + 12) % 12
        histogram[pc] += Int64::max(note.duration, 1L).to_double()
        flats -= note.spelling
      }
    }
  }
  if end == 0L {
    end = performance.end
  }
  let timeline = build_timeline(
    end,
    performance.times,
    performance.keys,
    performance.tempos,
    histogram,
    flats,
    time_override~,
    key_override~,
  )
  let parts : Array[NotatedPart] = []
  let mut error = ""
  if track_count > 4096 {
    error = "music: the score has more than 4096 staves"
  } else if track_count.to_int64() * timeline.measures.length().to_int64() >
    1000000L {
    error = "music: the score has more than 1000000 measures on its staves (\{track_count} tracks of \{timeline.measures.length()} measures)"
  }
  if error != "" {
    // Upstream returns immediately after measure construction on budget errors.
    for measure in timeline.measures {
      measure.key = None
      measure.effective_key = { fifths: 0, minor: false, }
      measure.tempo.clear()
    }
  } else {
    for track in performance.tracks {
      if track.notes.is_empty() {
        continue
      }
      let onsets : Array[Int64] = []
      for note in track.notes {
        onsets.push(note.tick)
      }
      let beats = beat_grids(timeline.measures, onsets)
      let mut quantized = quantize_notes(timeline.measures, track.notes)
      if quantized.is_empty() || beats.is_empty() {
        continue
      }
      let plan = plan_staff(quantized, track.channel, track.program).unwrap()
      if plan.percussion {
        quantized = percussion_durations(quantized, beats)
      }
      let part_measures : Array[NotatedPartMeasure] = []
      for measure in timeline.measures {
        part_measures.push({
          key: if plan.percussion {
            None
          } else {
            measure.key
          },
          events: [],
        })
      }
      let lyrics = snapped_lyrics(beats, track.lyrics)
      for staff in 0..<plan.clefs.length() {
        let selected : Array[VoiceNote] = []
        for note in quantized {
          if plan.staff_for(note.key) == staff {
            selected.push({
              note,
              voice_hint: if plan.percussion {
                drum_of(note.key).voice
              } else {
                0
              },
            })
          }
        }
        let staff_events = write_staff_events_shared(
          selected,
          timeline.measures,
          beats,
          lyrics,
          staff,
          plan.percussion,
        )
        for i, events in staff_events {
          for event in events {
            part_measures[i].events.push(event)
          }
        }
      }
      parts.push({
        name: track.name,
        clefs: plan.clefs,
        percussion: plan.percussion,
        measures: part_measures,
      })
    }
  }
  {
    title: performance.title,
    subtitle: performance.subtitle,
    composer: performance.composer,
    lyricist: performance.lyricist,
    arranger: performance.arranger,
    copyright: performance.copyright,
    timeline,
    parts,
    error,
  }
}
