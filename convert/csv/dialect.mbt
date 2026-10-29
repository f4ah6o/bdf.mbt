///|
/// The selected dialect and its sample's consistency measurements.
pub(all) struct DialectGuess {
  dialect : Dialect
  records : Int32
  fields : Int32
  score : Double
  numbers : Int32
} derive(Debug, Eq)

///|
/// Guess a CSV dialect from at most the first 64 KiB of decoded text. Pass a
/// nonzero delimiter or quote to constrain the candidates; quote `-1` forces
/// unquoted fields. A cut sample omits its final, potentially partial record.
pub fn detect_dialect(
  text : String,
  cut~ : Bool = false,
  delimiter~ : Byte = 0,
  quote~ : Int32 = 0,
) -> DialectGuess raise {
  if delimiter >= 0x80 || delimiter == b'\n' || delimiter == b'\r' {
    raise InvalidDialect(
      "delimiter must be an ASCII character other than CR or LF",
    )
  }
  if quote < -1 || quote >= 0x80 || quote == 10 || quote == 13 {
    raise InvalidDialect(
      "quote must be an ASCII character other than CR or LF, or -1 for no quote",
    )
  }
  let input = @utf8.encode(text)
  let sample_cut = cut || input.length() > 65536
  let sample = if input.length() > 65536 {
    input[:65536].to_owned()
  } else {
    input
  }
  let delimiters = if delimiter == 0 {
    [b',', b'\t', b';', b'|']
  } else {
    [delimiter]
  }
  let quotes : Array[(Byte, Byte)] = if quote == 0 {
    [(b'"', 0), (b'"', b'\\'), (0, 0), (b'\'', 0), (b'\'', b'\\')]
  } else if quote == -1 {
    [(0, 0)]
  } else {
    [(quote.to_byte(), 0), (quote.to_byte(), b'\\')]
  }
  let mut best : DialectGuess = {
    dialect: { delimiter: 0, quote: 0, escape: 0, },
    records: 0,
    fields: 0,
    score: 0.0,
    numbers: 0,
  }
  let mut found = false
  for d in delimiters {
    let mut quote_best = best
    let mut tried = false
    for (q, e) in quotes {
      if q == d {
        continue
      }
      let trial = csv_trial(
        sample,
        { delimiter: d, quote: q, escape: e, },
        sample_cut,
      )
      if !tried || trial.score > quote_best.score + 0.000000001 {
        quote_best = trial
        tried = true
      }
    }
    if tried && (!found || csv_better(quote_best, best)) {
      best = quote_best
      found = true
    }
  }
  best
}

///|
fn csv_trial(sample : Bytes, dialect : Dialect, cut : Bool) -> DialectGuess {
  let reader : Reader = {
    text: sample,
    dialect,
    pos: 0,
    bad: 0,
    quoted: 0,
    unfinished: false,
  }
  let counts : Map[Int32, Int32] = Map([])
  let mut records = 0
  let mut numbers = 0
  while records < 2000 && reader.pos < sample.length() {
    let fields = reader.record()
    if cut && reader.pos >= sample.length() {
      break
    }
    if fields.length() > 0 {
      counts[fields.length()] = counts.get(fields.length()).unwrap_or(0) + 1
      records += 1
    }
    if records <= 100 {
      for value in fields {
        if looks_numeric(value) || looks_date_time(value) {
          numbers += 1
        }
      }
    }
  }
  let mut bad = reader.bad
  if reader.unfinished && !cut {
    bad += records
  }
  let mut fields = 0
  let mut best = 0
  for count, n in counts {
    if n > best || (n == best && count > fields) {
      fields = count
      best = n
    }
  }
  let score = if records == 0 {
    0.0
  } else {
    best.to_double() / records.to_double() -
    0.5 * bad.to_double() / records.to_double()
  }
  { dialect, records, fields, score, numbers, }
}

///|
fn csv_better(a : DialectGuess, b : DialectGuess) -> Bool {
  if (a.fields >= 2) != (b.fields >= 2) {
    return a.fields >= 2
  }
  let delta = a.score - b.score
  if delta > 0.02 || delta < -0.02 {
    return delta > 0.0
  }
  if a.fields != b.fields {
    return a.fields > b.fields
  }
  a.numbers > b.numbers
}
