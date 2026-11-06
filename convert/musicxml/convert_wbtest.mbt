///|
test "musicxml converts the minuet fixture" {
  let data = @base64.decode(musicxml_minuet_fixture, ignore_whitespace=true) catch {
    _ => fail("musicxml fixture is not valid base64")
  }
  let db = @db.Database::new()
  let result = convert(data, db, guitar_tab=false) catch {
    error => fail("musicxml conversion failed: " + error.to_string())
  }
  assert_true(result.pages >= 1)
  let doc = @core.open_single(result.bdf) catch {
    error => fail("musicxml output is not a BDF document: " + error.to_string())
  }
  assert_eq(doc.manifest.views.length(), 1)
  let view = doc.manifest.views[0]
  assert_eq(view.id, "score")
  assert_eq(view.title, "Minuet in G")
  assert_true(view.pages.length() >= 1)
  match doc.play(view) {
    Some(play) => {
      let sequence = @core.parse_smf(play.seq) catch {
        error => fail("musicxml playback is not an SMF: " + error.to_string())
      }
      assert_eq(sequence.ticks, 46080.0)
    }
    None => fail("musicxml score has no playback sequence")
  }
}

///|
test "musicxml reads score-timewise" {
  let xml = "<?xml version=\"1.0\"?><score-timewise version=\"4.0\"><part-list><score-part id=\"P1\"><part-name>One</part-name></score-part></part-list><measure number=\"1\"><part id=\"P1\"><attributes><divisions>4</divisions><time><beats>4</beats><beat-type>4</beat-type></time></attributes><note><pitch><step>C</step><octave>4</octave></pitch><duration>16</duration><type>whole</type></note></part></measure></score-timewise>"
  let result = convert(@utf8.encode(xml), @db.Database::new(), guitar_tab=false) catch {
    error => fail("timewise conversion failed: " + error.to_string())
  }
  assert_true(result.pages >= 1)
  let doc = @core.open_single(result.bdf) catch {
    error => fail("timewise output is not a BDF document: " + error.to_string())
  }
  assert_eq(doc.manifest.views.length(), 1)
  assert_true(doc.manifest.views[0].pages.length() >= 1)
}
