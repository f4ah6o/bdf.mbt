///|
fn audio_test_fixture(text : String) -> Bytes {
  @gzip.decompress(@base64.decode(text[:], ignore_whitespace=true)[:]) catch {
    _ => b""
  }
}

///|
fn audio_test_text(result : AudioResult) -> String {
  let doc = @core.open_single(result.bdf) catch { _ => return "" }
  let view = doc.manifest.views[0]
  match view.text_index {
    Some(hash) => {
      let part = doc.part(hash) catch { _ => return "" }
      let index = @core.decode_text_index(part) catch { _ => return "" }
      let text = StringBuilder()
      for run in index {
        text.write_string(run.text)
      }
      text.to_string()
    }
    None => ""
  }
}

///|
fn audio_test_dc_field(dc : Json, key : String) -> Json? {
  match dc {
    Json::Object(fields) => fields.get(key)
    _ => None
  }
}

///|
fn audio_test_dc(result : AudioResult) -> Json {
  let manifest = @core.manifest_json(result.bdf) catch {
    _ => return Json::empty_object()
  }
  let meta = match manifest {
    Json::Object(fields) => fields.get("meta")
    _ => None
  }
  let dc = match meta {
    Some(Json::Object(fields)) => fields.get("dc")
    _ => None
  }
  match dc {
    Some(value) => value
    None => Json::empty_object()
  }
}

///|
fn audio_test_dc_string(dc : Json, key : String) -> String {
  match audio_test_dc_field(dc, key) {
    Some(Json::String(text)) => text
    Some(Json::Array(items)) => {
      for item in items {
        match item {
          Json::String(text) => return text
          _ => ()
        }
      }
      ""
    }
    _ => ""
  }
}

///|
fn audio_test_dc_values(dc : Json, key : String) -> Array[String] {
  let out : Array[String] = []
  match audio_test_dc_field(dc, key) {
    Some(Json::String(text)) => out.push(text)
    Some(Json::Array(items)) => {
      for item in items {
        match item {
          Json::String(text) => out.push(text)
          _ => ()
        }
      }
    }
    _ => ()
  }
  out
}

///|
test "MP3 card has tags, cover and play data" {
  let data = audio_test_fixture(audio_mp3_fixture)
  assert_eq(detect(data), true)
  let result = convert(data)
  assert_eq(result.pages, 1)
  let doc = @core.open_single(result.bdf)
  let view = doc.manifest.views[0]
  assert_eq(view.kind, "fixed")
  assert_eq(view.play is Some(_), true)
  let index = @core.decode_text_index(doc.part(view.text_index.unwrap()))
  let mut text = ""
  for run in index {
    text += run.text
  }
  assert_eq(text.length() > 10, true)
  assert_true(text.contains("Sunny Field"))
  assert_true(text.contains("Taro Yamada"))
  assert_true(text.contains("Four Seasons"))
  assert_true(text.contains("Track 3 of 12"))
  assert_true(text.contains("Lyrics"))
  assert_true(text.contains("Chapters"))
}

///|
test "WAV, FLAC and Shift_JIS MP3 are detected" {
  for fixture in [audio_wav_fixture, audio_flac_fixture, audio_japanese_fixture] {
    let data = audio_test_fixture(fixture)
    assert_eq(detect(data), true)
    let result = convert(data)
    assert_eq(result.pages, 1)
  }
}

///|
test "audio fixtures match the upstream metadata" {
  let rows : Array[(String, String, String, String, Int32, Int32, String)] = [
    ("tagged.mp3", audio_mp3_fixture, "mp3", "MP3", 22050, 1, "jpeg"),
    ("japanese.mp3", audio_japanese_fixture, "mp3", "MP3", 22050, 1, ""),
    ("tagged.m4a", audio_m4a_fixture, "m4a", "AAC", 22050, 1, "png"),
    ("tagged.flac", audio_flac_fixture, "flac", "FLAC", 22050, 1, "png"),
    ("tagged.ogg", audio_ogg_fixture, "ogg", "Vorbis", 22050, 1, "png"),
    ("tagged.opus", audio_opus_fixture, "ogg", "Opus", 48000, 1, "png"),
    ("tagged.wav", audio_wav_fixture, "wav", "PCM", 8000, 1, ""),
    ("tagged.aiff", audio_aiff_fixture, "aiff", "PCM", 8000, 1, "jpeg"),
    ("plain.aac", audio_aac_fixture, "aac", "AAC LC", 22050, 1, ""),
  ]
  for (name, fixture, format, codec, rate, channels, cover) in rows {
    let data = audio_test_fixture(fixture)
    assert_eq(detect(data), true)
    let tags = audio_read(data)
    assert_eq(tags.format, format)
    assert_eq(tags.codec, codec)
    assert_eq(tags.sample_rate, rate)
    assert_eq(tags.channels, channels)
    assert_eq(tags.cover_format, cover)
    assert_eq(tags.cover.length() > 0, cover != "")
    let result = convert(data)
    assert_eq(result.pages, 1)
    assert_true(result.summary.contains(audio_format_name(format)))
    assert_true(result.summary.contains(audio_khz(rate)))
    assert_true(result.summary.contains("mono"))
    if cover != "" {
      assert_true(result.summary.contains(cover.to_upper()))
    } else {
      assert_true(result.summary.contains("no cover"))
    }
    ignore(name)
  }
}

///|
test "Dublin Core comes from the MP3 tags" {
  let result = convert(audio_test_fixture(audio_mp3_fixture))
  let dc = audio_test_dc(result)
  assert_eq(audio_test_dc_string(dc, "title"), "Sunny Field")
  assert_eq(audio_test_dc_string(dc, "creator"), "Taro Yamada")
  assert_eq(audio_test_dc_string(dc, "subject"), "Folk")
  assert_eq(
    audio_test_dc_string(dc, "description"),
    "A song about a field in the sun",
  )
  assert_eq(audio_test_dc_string(dc, "publisher"), "Example Records")
  let contributors = audio_test_dc_values(dc, "contributor")
  assert_eq(contributors.contains("Various Artists"), true)
  assert_eq(contributors.contains("Hanako Sato"), true)
  assert_eq(audio_test_dc_string(dc, "date"), "2026-09-01")
  assert_eq(audio_test_dc_string(dc, "type"), "Sound")
  assert_eq(audio_test_dc_string(dc, "format"), "audio/mpeg")
  assert_eq(audio_test_dc_string(dc, "identifier"), "JPA012600001")
  assert_eq(audio_test_dc_string(dc, "language"), "en")
  assert_eq(audio_test_dc_string(dc, "relation"), "Four Seasons")
  assert_eq(audio_test_dc_string(dc, "rights"), "© 2026 Example Records")
}

///|
test "Dublin Core comes from the M4A metadata" {
  let result = convert(audio_test_fixture(audio_m4a_fixture))
  let dc = audio_test_dc(result)
  assert_eq(audio_test_dc_string(dc, "title"), "Sunny Field")
  assert_eq(audio_test_dc_string(dc, "creator"), "Taro Yamada")
  assert_eq(audio_test_dc_string(dc, "subject"), "Folk")
  assert_eq(
    audio_test_dc_string(dc, "description"),
    "A song about a field in the sun",
  )
  assert_eq(audio_test_dc_string(dc, "date"), "2026-09-01")
  assert_eq(audio_test_dc_string(dc, "relation"), "Four Seasons")
  assert_eq(audio_test_dc_string(dc, "rights"), "© 2026 Example Records")
  assert_eq(audio_test_dc_string(dc, "format"), "audio/mp4")
  let contributors = audio_test_dc_values(dc, "contributor")
  assert_eq(contributors.contains("Various Artists"), true)
  assert_eq(contributors.contains("Hanako Sato"), true)
  let text = audio_test_text(result)
  assert_true(text.contains("Grouping: Summer"))
  assert_true(text.contains("Not a cloud in the summer sky"))
  assert_true(text.contains("Track 3 of 12"))
}

///|
test "Dublin Core comes from the other fixture tags" {
  let flac = audio_test_dc(convert(audio_test_fixture(audio_flac_fixture)))
  assert_eq(audio_test_dc_string(flac, "title"), "Sunny Field")
  assert_eq(audio_test_dc_string(flac, "creator"), "Taro Yamada")
  assert_eq(audio_test_dc_string(flac, "subject"), "Folk")
  assert_eq(
    audio_test_dc_string(flac, "description"),
    "A song about a field in the sun",
  )
  assert_eq(audio_test_dc_string(flac, "contributor"), "Hanako Sato")
  assert_eq(audio_test_dc_string(flac, "date"), "2026-09-01")
  assert_eq(audio_test_dc_string(flac, "identifier"), "JPA012600001")
  assert_eq(audio_test_dc_string(flac, "relation"), "Four Seasons")
  assert_eq(audio_test_dc_string(flac, "rights"), "© 2026 Example Records")
  assert_eq(audio_test_dc_string(flac, "format"), "audio/flac")

  let wav = audio_test_dc(convert(audio_test_fixture(audio_wav_fixture)))
  assert_eq(audio_test_dc_string(wav, "title"), "Sunny Field")
  assert_eq(audio_test_dc_string(wav, "creator"), "Taro Yamada")
  assert_eq(audio_test_dc_string(wav, "subject"), "Folk")
  assert_eq(audio_test_dc_string(wav, "date"), "2026-09-01")
  assert_eq(audio_test_dc_string(wav, "format"), "audio/wav")
  assert_eq(audio_test_dc_string(wav, "relation"), "Four Seasons")
  assert_eq(audio_test_dc_string(wav, "rights"), "© 2026 Example Records")

  let aiff = audio_test_dc(convert(audio_test_fixture(audio_aiff_fixture)))
  assert_eq(audio_test_dc_string(aiff, "title"), "Sunny Field")
  assert_eq(audio_test_dc_string(aiff, "creator"), "Taro Yamada")
  assert_eq(audio_test_dc_string(aiff, "date"), "2026")
  assert_eq(audio_test_dc_string(aiff, "format"), "audio/aiff")
  assert_eq(audio_test_dc_string(aiff, "relation"), "Four Seasons")

  let ogg = audio_test_dc(convert(audio_test_fixture(audio_ogg_fixture)))
  assert_eq(audio_test_dc_string(ogg, "title"), "Sunny Field")
  assert_eq(audio_test_dc_string(ogg, "creator"), "Taro Yamada")
  assert_eq(audio_test_dc_string(ogg, "date"), "2026")
  assert_eq(audio_test_dc_string(ogg, "format"), "audio/ogg")
  assert_eq(audio_test_dc_string(ogg, "relation"), "Four Seasons")

  let opus = audio_test_dc(convert(audio_test_fixture(audio_opus_fixture)))
  assert_eq(audio_test_dc_string(opus, "title"), "Sunny Field")
  assert_eq(audio_test_dc_string(opus, "creator"), "Taro Yamada")
  assert_eq(audio_test_dc_string(opus, "format"), "audio/ogg")

  let aac = audio_test_dc(convert(audio_test_fixture(audio_aac_fixture)))
  assert_eq(audio_test_dc_string(aac, "type"), "Sound")
  assert_eq(audio_test_dc_string(aac, "format"), "audio/aac")
}

///|
test "SYLT and LRC give synchronized lyrics" {
  let synced = audio_read(audio_test_fixture(audio_synced_mp3_fixture))
  assert_eq(synced.synced_lyrics.length(), 4)
  let times = [1500, 4500, 7500, 10500]
  let texts = [
    "Over the field the sun is high",
    "Not a cloud in the summer sky",
    "Walking home along the lane",
    "Hoping it will never rain",
  ]
  for i in 0..<4 {
    assert_eq(
      (synced.synced_lyrics[i].0 * 1000.0).round().to_int(),
      times[i],
    )
    assert_eq(synced.synced_lyrics[i].1, texts[i])
  }
  let result = convert(audio_test_fixture(audio_synced_mp3_fixture))
  assert_true(result.summary.contains("4 lines of synchronized lyrics"))
  let text = audio_test_text(result)
  assert_true(text.contains("Lyrics"))
  assert_true(text.contains("Over the field the sun is high"))
  assert_true(text.contains("Walking home along the lane"))

  let lrc = audio_read(audio_test_fixture(audio_lrc_flac_fixture))
  assert_eq(lrc.synced_lyrics.length(), 3)
  let lrc_times = [500, 1500, 3000]
  for i in 0..<3 {
    assert_eq((lrc.synced_lyrics[i].0 * 1000.0).round().to_int(), lrc_times[i])
  }
  assert_eq(lrc.synced_lyrics[0].1, "野原の上に太陽")
  assert_eq(lrc.synced_lyrics[1].1, "雲ひとつない夏の空")
  assert_eq(lrc.synced_lyrics[2].1, "雲ひとつない夏の空")
  let lrc_result = convert(audio_test_fixture(audio_lrc_flac_fixture))
  assert_true(lrc_result.summary.contains("3 lines of synchronized lyrics"))
  let lrc_text = audio_test_text(lrc_result)
  assert_true(lrc_text.contains("野原の上に太陽"))
  assert_eq(lrc_text.contains("[00:"), false)
}

///|
test "CHAP frames become chapters" {
  let data = audio_test_fixture(audio_mp3_fixture)
  let tags = audio_read(data)
  assert_eq(tags.chapters.length(), 2)
  assert_eq(tags.chapters[0].1, "Verse")
  assert_eq(tags.chapters[1].1, "Chorus")
  assert_eq(tags.chapters[0].0, 0.0)
  assert_eq(tags.chapters[1].0, 0.5)
  let result = convert(data)
  assert_true(result.summary.contains("2 chapters"))
  assert_true(result.summary.contains("4 lines of lyrics"))
  let text = audio_test_text(result)
  assert_true(text.contains("Chapters"))
  assert_true(text.contains("0:00 Verse"))
  assert_true(text.contains("0:01 Chorus"))
  assert_true(text.contains("Hoping it will never rain"))
}

///|
test "ADTS AAC without tags becomes a card" {
  let data = audio_test_fixture(audio_aac_fixture)
  assert_eq(detect(data), true)
  let tags = audio_read(data)
  assert_eq(tags.codec, "AAC LC")
  assert_eq(tags.sample_rate, 22050)
  assert_eq(tags.channels, 1)
  let result = convert(data)
  assert_eq(result.pages, 1)
  assert_true(result.summary.contains("ADTS AAC LC"))
  assert_true(result.summary.contains("no cover"))
}
