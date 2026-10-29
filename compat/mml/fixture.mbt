///|
#export_name("mml_detection")
pub fn mml_detection(value : String) -> String {
  let (ok, tokens, notes) = @mml.mml_like(value)
  Json::array([
    Json::boolean(@mml.detect_mml(@utf8.encode(value))),
    Json::string(@mml.detect_mml_dialect(value)),
    Json::boolean(ok),
    Json::number(tokens.to_double()),
    Json::number(notes.to_double()),
  ]).stringify()
}

///|
#export_name("mml_decode")
pub fn mml_decode(data : Bytes) -> String {
  @mml.decode_mml(data)
}

///|
#export_name("mml_source")
pub fn mml_source(text : String, dialect : String) -> String {
  let source = @mml.split_mml_source(text, dialect)
  let tracks = source.tracks.map(fn(track) {
    Json::array([
      Json::string(track.name),
      Json::string(track.text),
      Json::number(track.kind.to_double()),
    ])
  })
  Json::array([
    Json::string(source.title),
    Json::string(source.composer),
    Json::string(source.arranger),
    Json::string(source.lyricist),
    Json::string(source.copyright),
    Json::boolean(source.reverse),
    Json::array(tracks),
    Json::array(source.warnings.map(fn(w) { Json::string(w) })),
    Json::string(@mml.strip_mml_comments(text, false)),
    Json::string(@mml.strip_mml_comments(text, true)),
  ]).stringify()
}

///|
#export_name("mml_scan")
pub fn mml_scan(text : String) -> String {
  let b = @utf8.encode(text)
  let (n, nok, ni) = @mml.mml_number(b, 0)
  let (sg, sok, si) = @mml.mml_signed(b, 0)
  let (dec, dok, di) = @mml.mml_decimal(b, 0)
  let (len, lok, li) = @mml.mml_length_arg(b, 0, 384)
  let (dot, dit) = @mml.mml_dots(b, 0, 960)
  Json::array([
    Json::number(n.to_double()),
    Json::boolean(nok),
    Json::number(ni.to_double()),
    Json::number(sg.to_double()),
    Json::boolean(sok),
    Json::number(si.to_double()),
    Json::number(dec),
    Json::boolean(dok),
    Json::number(di.to_double()),
    Json::number(len.to_double()),
    Json::boolean(lok),
    Json::number(li.to_double()),
    Json::number(dot.to_double()),
    Json::number(dit.to_double()),
    Json::number(@mml.mml_skip_args(b, 0).to_double()),
    Json::number(@mml.mml_closing(b, 0, b'[', b']').to_double()),
    Json::number(@mml.mml_closing(b, 0, b'{', b'}').to_double()),
    Json::number(@mml.mml_closing_slash(b, 0).to_double()),
    Json::number(@mml.mml_break_at(b, b'[').to_double()),
    Json::number(@mml.mml_break_at(b, b'/').to_double()),
  ]).stringify()
}

///|
#export_name("mml_play")
pub fn mml_play(
  text : String,
  dialect : String,
  octave : Int32,
  program : Int32,
) -> String {
  let result = @mml.parse_mml(@utf8.encode(text), dialect~, octave~, program~)
  let perf = match result.performance {
    None => Json::null()
    Some(perf) => {
      let tracks = perf.tracks.map(fn(tr) {
        let notes = tr.notes.map(fn(n) {
          Json::array([
            Json::number(n.tick.to_double()),
            Json::number(n.duration.to_double()),
            Json::number(n.key.to_double()),
            Json::number(n.velocity.to_double()),
            Json::number(n.spelling.to_double()),
          ])
        })
        let controls = tr.controls.map(fn(c) {
          Json::array([
            Json::number(c.tick.to_double()),
            Json::number(c.kind.to_double()),
            Json::number(c.number.to_double()),
            Json::number(c.value.to_double()),
          ])
        })
        Json::array([
          Json::string(tr.name),
          Json::number(tr.channel.to_double()),
          Json::number(tr.program.to_double()),
          Json::number(tr.volume.to_double()),
          Json::number(tr.pan.to_double()),
          Json::array(notes),
          Json::array(controls),
        ])
      })
      let tempos = perf.tempos.map(fn(t) {
        Json::array([Json::number(t.tick.to_double()), Json::number(t.bpm)])
      })
      Json::array([
        Json::string(perf.title),
        Json::string(perf.composer),
        Json::string(perf.arranger),
        Json::string(perf.lyricist),
        Json::string(perf.copyright),
        Json::array(tracks),
        Json::array(tempos),
        Json::number(perf.end.to_double()),
      ])
    }
  }
  Json::array([
    perf,
    Json::array(result.warnings.map(fn(w) { Json::string(w) })),
    Json::string(result.error),
  ]).stringify()
}
