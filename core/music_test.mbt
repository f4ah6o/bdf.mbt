///|
test "SMF running status, note pairs, and timing" {
  let bytes = b"MThd\x00\x00\x00\x06\x00\x00\x00\x01\x01\xe0MTrk\x00\x00\x00\x15\x00\x90\x3c\x64\x83\x60\x3c\x00\x00\x90\x40\x50\x83\x60\x80\x40\x00\x00\xff\x2f\x00"
  let seq = @core.parse_smf(bytes)
  assert_eq(seq.format, 0)
  assert_eq(seq.division, 480.0)
  assert_eq(seq.tracks, 1)
  assert_eq(seq.events.length(), 2)
  assert_eq(seq.ticks, 960.0)
  assert_eq(seq.duration, 1.0)
  assert_eq(
    seq.events[0].message,
    @core.Note(channel=0, key=60, velocity=100, duration=0.5, end_tick=480.0),
  )
  assert_eq(
    seq.events[1].message,
    @core.Note(channel=0, key=64, velocity=80, duration=0.5, end_tick=960.0),
  )
  assert_eq(@core.tick_to_seconds(seq, 240.0), 0.25)
  assert_eq(@core.seconds_to_tick(seq, 0.75), 720.0)
  let smpte = { ..seq, smpte: true, division: 1000.0, tempos: [], }
  assert_eq(@core.tick_to_seconds(smpte, 250.0), 0.25)
  assert_eq(@core.seconds_to_tick(smpte, 2.0), 2000.0)
}

///|
test "cue indexes wrap unsigned tick deltas and reject invalid systems" {
  let bytes = b"BCUE\x01\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x80\x3f\x00\x00\x80\x3f\x02\xff\xff\xff\xff\x0f\x00\x00\x00\x00\x00\x02\x00\x00\x00\x80\x3f"
  let result = @core.decode_cues(bytes)
  assert_eq(result.systems.length(), 1)
  assert_eq(result.cues.map(c => c.tick), [4294967295U, 1U])
  assert_eq(result.cues.map(c => c.x), [0.0, 1.0])
  let invalid = b"BCUE\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00"
  let failed = try {
    ignore(@core.decode_cues(invalid))
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}

///|
test "split documents expose music, audio, and sanitized MIME types" {
  let manifest = b"{\"bdf\":1,\"parts\":[{\"h\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"t\":\"seq\",\"len\":4,\"size\":4},{\"h\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\",\"t\":\"idx\",\"len\":8,\"size\":8}],\"views\":[{\"id\":\"score\",\"kind\":\"fixed\",\"play\":{\"seq\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"cues\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}},{\"id\":\"audio\",\"kind\":\"fixed\",\"play\":{\"audio\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"type\":\"audio/mpeg\"}},{\"id\":\"unsafe\",\"kind\":\"fixed\",\"play\":{\"audio\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"type\":\"text/html\"}}]}"
  let doc = @core.open_split(manifest, (hash, _) => {
    if hash == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" {
      b"MIDI"
    } else {
      b"BCUE\x01\x00\x00\x00"
    }
  })
  let music = doc.play(doc.manifest.views[0]).unwrap()
  assert_eq(music.seq, b"MIDI")
  assert_eq(music.cues.unwrap().cues.length(), 0)
  assert_true(doc.audio(doc.manifest.views[0]) is None)
  assert_eq(doc.audio(doc.manifest.views[1]).unwrap().media_type, "audio/mpeg")
  assert_eq(doc.audio(doc.manifest.views[2]).unwrap().media_type, "")
}
