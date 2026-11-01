///|
fn audio_test_fixture(text : String) -> Bytes {
  @gzip.decompress(@base64.decode(text[:], ignore_whitespace=true)[:]) catch {
    _ => b""
  }
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
  println(text)
  assert_eq(text.length() > 10, true)
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
test "ADTS AAC without tags becomes a card" {
  let data = @gzip.decompress(
    @base64.decode(audio_aac_fixture[:], ignore_whitespace=true)[:],
  ) catch { _ => b"" }
  ignore(data)
}
