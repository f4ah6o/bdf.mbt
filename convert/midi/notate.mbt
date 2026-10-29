///|
/// Turn a parsed MIDI file into the shared music score model.
pub fn notate_file(
  file : MidiRawFile,
  time_override~ : @music.TimeSig? = None,
  key_override~ : @music.KeySig? = None,
) -> @music.NotatedScore {
  let p = performance(file)
  let tracks : Array[@music.PerformanceTrack] = []
  for track in p.tracks {
    let notes : Array[@music.NotationNote] = []
    for note in track.notes {
      notes.push({
        tick: note.tick,
        duration: note.duration,
        key: note.key,
        velocity: note.velocity,
        spelling: 0,
      })
    }
    let lyrics : Array[@music.NotationLyric] = []
    for lyric in track.lyrics {
      lyrics.push({ tick: lyric.tick, text: lyric.text, })
    }
    tracks.push({
      name: track.name,
      channel: track.channel,
      program: track.program,
      notes,
      lyrics,
    })
  }
  let times : Array[@music.TimeChange] = []
  let keys : Array[@music.KeyChange] = []
  let tempos : Array[@music.TempoChange] = []
  for t in p.times {
    times.push({
      tick: t.tick,
      time: { beats: t.beats, beat_type: t.beat_type, symbol: "", },
    })
  }
  for k in p.keys {
    keys.push({ tick: k.tick, key: { fifths: k.fifths, minor: k.minor, }, })
  }
  for t in p.tempos {
    tempos.push({ tick: t.tick, bpm: t.bpm, })
  }
  @music.notate(
    {
      title: p.credits.title,
      subtitle: "",
      composer: p.credits.composer,
      lyricist: p.credits.lyricist,
      arranger: p.credits.arranger,
      copyright: p.credits.copyright,
      tracks,
      times,
      keys,
      tempos,
      end: p.end,
    },
    time_override~,
    key_override~,
  )
}
