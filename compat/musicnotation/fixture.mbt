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
