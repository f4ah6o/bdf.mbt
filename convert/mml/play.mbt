///|
/// A note played by an MML track.
pub(all) struct MmlNote {
  tick : Int32
  mut duration : Int32
  key : Int32
  velocity : Int32
  spelling : Int32
}

///|
/// A program or MIDI controller change.
pub(all) struct MmlControl {
  mut tick : Int32
  kind : Int32
  number : Int32
  mut value : Int32
}

///|
/// A tempo change in 960-tick quarter-note units.
pub(all) struct MmlTempo {
  mut tick : Int32
  mut bpm : Double
}

///|
/// A played MML track.
pub(all) struct MmlPlayedTrack {
  mut name : String
  mut channel : Int32
  mut program : Int32
  mut volume : Int32
  mut pan : Int32
  notes : Array[MmlNote]
  controls : Array[MmlControl]
}

///|
/// Music produced by MML interpretation.
pub(all) struct MmlPerformance {
  title : String
  composer : String
  arranger : String
  lyricist : String
  copyright : String
  tracks : Array[MmlPlayedTrack]
  tempos : Array[MmlTempo]
  mut end : Int32
}

///|
priv struct MmlPlayer {
  dialect : String
  up : Int32
  program : Int32
  source : MmlSource
  perf : MmlPerformance
  tempos : Array[MmlTempo]
  warnings : Array[String]
  seen : Map[String, Bool]
  mut notes : Int32
  mut steps : Int32
  mut stopped : Bool
  mut cost : Int32
}

///|
priv struct MmlVoice {
  player : MmlPlayer
  track : MmlPlayedTrack
  kind : Int32
  fold : Bool
  mut tick : Int32
  mut oct : Int32
  mut len : Int32
  mut vol : Int32
  mut vel : Int32
  mut shift : Int32
  mut prog : Int32
  ccs : Map[Int32, Int32]
  mut last : Int32
  mut tied : Bool
  mut done : Bool
  pct : Int32
  mut moved : Bool
  mut before : Int32
}

///|
fn MmlPlayer::warn(self : MmlPlayer, key : String, text : String) -> Unit {
  if !self.seen.contains(key) {
    self.seen[key] = true
    self.warnings.push(text)
  }
}

///|
fn MmlVoice::set_vol(self : MmlVoice, n : Int32) -> Unit {
  self.vol = Int32::min(Int32::max(n, 0), 16)
  self.vel = Int32::min((self.vol * 127 + 7) / 15, 127)
}

///|
fn MmlVoice::cc(self : MmlVoice, number : Int32, value : Int32) -> Unit {
  if self.ccs.get(number) == Some(value) {
    return
  }
  self.ccs[number] = value
  let controls = self.track.controls
  let mut i = controls.length() - 1
  while i >= 0 && controls[i].tick == self.tick {
    if controls[i].kind == 1 && controls[i].number == number {
      controls[i].value = value
      return
    }
    i -= 1
  }
  controls.push({ tick: self.tick, kind: 1, number, value, })
}

///|
fn MmlVoice::set_program(self : MmlVoice, program : Int32) -> Unit {
  if self.tick == 0 && self.track.notes.is_empty() {
    self.track.program = program
    self.prog = program
    return
  }
  if self.prog == program {
    return
  }
  self.prog = program
  let controls = self.track.controls
  let n = controls.length()
  if n > 0 && controls[n - 1].tick == self.tick && controls[n - 1].kind == 0 {
    controls[n - 1].value = program
    return
  }
  controls.push({ tick: self.tick, kind: 0, number: 0, value: program, })
}

///|
fn MmlVoice::pan(self : MmlVoice, value : Int32) -> Unit {
  if self.tick == 0 && self.track.notes.is_empty() {
    self.track.pan = value
    self.ccs[10] = value
  } else {
    self.cc(10, value)
  }
}

///|
fn MmlVoice::advance(self : MmlVoice, duration : Int32) -> Unit {
  self.tick += duration
  if self.tick > 38400000 {
    self.player.warn(
      "ticks", "a track plays longer than 10000 whole notes; the rest is left out",
    )
    self.done = true
  }
}

///|
fn MmlVoice::note(
  self : MmlVoice,
  key : Int32,
  duration : Int32,
  spelling : Int32,
) -> Unit {
  let p = self.player
  if self.moved && self.before >= 0 {
    p.cost += Int32::abs(key - self.before)
  }
  self.moved = false
  self.before = key
  let tied = self.tied
  self.tied = false
  if tied && self.last >= 0 {
    let note = self.track.notes[self.last]
    if note.key == key && note.tick + note.duration == self.tick {
      note.duration += duration
      self.advance(duration)
      return
    }
  }
  self.last = -1
  if key < 0 || key > 127 {
    p.warn("range", "notes outside the MIDI range are left out")
  } else if self.vel > 0 {
    p.notes += 1
    if p.notes > 1000000 {
      p.warn(
        "notes", "the MML plays more than 1000000 notes; the rest is left out",
      )
      p.stopped = true
      return
    }
    self.track.notes.push({
      tick: self.tick,
      duration,
      key,
      velocity: self.vel,
      spelling,
    })
    self.last = self.track.notes.length() - 1
  }
  self.advance(duration)
}

///|
fn MmlVoice::rest(self : MmlVoice, duration : Int32) -> Unit {
  self.last = -1
  self.tied = false
  self.advance(duration)
}

///|
fn MmlVoice::extend_note(self : MmlVoice, duration : Int32) -> Unit {
  if self.last >= 0 {
    let n = self.track.notes[self.last]
    if n.tick + n.duration == self.tick {
      n.duration += duration
    }
  }
  self.advance(duration)
}

///|
fn MmlPlayer::voice(self : MmlPlayer, source : MmlTrackSource) -> MmlVoice {
  let mut prog = 80
  let mut vol = 12
  let mut pct = 384
  if self.dialect == "mabinogi" {
    prog = 0
    vol = 8
  } else if self.dialect == "ppmck" {
    vol = 15
    pct = 192
    if source.kind == 2 {
      prog = 82
    } else if source.kind == 3 {
      prog = 122
    }
  }
  if self.program >= 0 {
    prog = self.program
  }
  let track : MmlPlayedTrack = {
    name: source.name,
    channel: 0,
    program: prog,
    volume: -1,
    pan: -1,
    notes: [],
    controls: [],
  }
  let voice : MmlVoice = {
    player: self,
    track,
    kind: source.kind,
    fold: self.dialect != "ppmck",
    tick: 0,
    oct: 4,
    len: 960,
    vol: 0,
    vel: 0,
    shift: 0,
    prog,
    ccs: Map([]),
    last: -1,
    tied: false,
    done: false,
    pct,
    moved: false,
    before: -1,
  }
  voice.set_vol(vol)
  if source.kind == 1 && prog == 80 {
    voice.cc(70, 32)
  }
  voice
}

///|
fn MmlVoice::length(self : MmlVoice, s : Bytes, pos : Int32) -> (Int32, Int32) {
  let (d, ok, end) = mml_length_arg(s, pos, self.pct)
  if ok {
    (d, end)
  } else {
    mml_dots(s, end, self.len)
  }
}

///|
fn mml_tone_program(n : Int32) -> Int32 {
  match n {
    0 => 79
    1 => 81
    2 | 6 => 82
    4 | 7 | 10 | 11 => 122
    _ => 80
  }
}

///|
fn mml_pulse_width(n : Int32) -> Int32 {
  if n <= 3 {
    [32, 64, 0, 96][n]
  } else if n <= 18 {
    32
  } else if n <= 37 {
    64
  } else if n <= 62 {
    0
  } else if n <= 87 {
    96
  } else {
    32
  }
}

///|
fn mml_quote_command(name : String) -> String {
  let out = StringBuilder()
  out.write_char('"')
  let hex = "0123456789abcdef"
  for c in name {
    let n = c.to_int()
    match n {
      7 => out.write_string("\\a")
      8 => out.write_string("\\b")
      9 => out.write_string("\\t")
      10 => out.write_string("\\n")
      11 => out.write_string("\\v")
      12 => out.write_string("\\f")
      13 => out.write_string("\\r")
      34 => out.write_string("\\\"")
      92 => out.write_string("\\\\")
      _ =>
        if n < 32 || n == 127 {
          out.write_string("\\x")
          out.write_char(hex[n / 16].to_int().unsafe_to_char())
          out.write_char(hex[n % 16].to_int().unsafe_to_char())
        } else {
          out.write_char(c)
        }
    }
  }
  out.write_char('"')
  out.to_string()
}

///|
fn MmlVoice::unknown(
  self : MmlVoice,
  name : String,
  s : Bytes,
  pos : Int32,
) -> Int32 {
  self.player.warn(
    "cmd:" + name,
    "unknown command " + mml_quote_command(name) + " is skipped",
  )
  mml_skip_args(s, pos)
}

///|
fn MmlVoice::at(self : MmlVoice, s : Bytes, pos : Int32) -> Int32 {
  let p = self.player
  let mut i = pos
  if p.dialect == "mabinogi" {
    return self.unknown("@", s, i)
  }
  if i < s.length() && mml_scan_digit(s[i]) {
    let (n, _, end) = mml_number(s, i)
    i = end
    if p.dialect == "ppmck" {
      if self.kind == 1 && self.prog == 80 && n <= 3 {
        self.cc(70, mml_pulse_width(n))
      }
      return i
    }
    if i + 1 < s.length() && s[i] == b'-' && mml_scan_digit(s[i + 1]) {
      let (_, _, end) = mml_number(s, i + 1)
      i = end
    }
    self.set_program(mml_tone_program(n))
    return i
  }
  let start = i
  while i < s.length() &&
        (
          (s[i] >= b'a' && s[i] <= b'z') ||
          (s[i] >= b'A' && s[i] <= b'Z') ||
          s[i] == b'@'
        ) {
    i += 1
  }
  let name = @utf8.decode_lossy(s[start:i]).to_lower()
  if p.dialect == "ppmck" {
    return mml_skip_args(s, i)
  }
  match name {
    "v" => {
      let (n, ok, end) = mml_number(s, i)
      if ok {
        self.vel = Int32::min(n, 127)
      }
      end
    }
    "w" => {
      let (n, ok, end) = mml_number(s, i)
      if ok {
        self.cc(70, mml_pulse_width(n))
      }
      end
    }
    "p" => {
      let (n, ok, end) = mml_number(s, i)
      if ok {
        self.pan(Int32::min(n, 127))
      }
      end
    }
    "e"
    | "l"
    | "f"
    | "q"
    | "n"
    | "d"
    | "o"
    | "r"
    | "s"
    | "x"
    | "i"
    | "u"
    | "m"
    | "mh" => mml_skip_args(s, i)
    _ => self.unknown("@" + name, s, i)
  }
}

///|
fn MmlVoice::upper(self : MmlVoice, s : Bytes, pos : Int32) -> Int32 {
  let mut i = pos
  while i < s.length() && s[i] >= b'A' && s[i] <= b'Z' {
    i += 1
  }
  let name = @utf8.decode_lossy(s[pos:i])
  match name {
    "K" => {
      let (n, ok, end) = mml_signed(s, i)
      if ok {
        self.shift = Int32::min(Int32::max(n, -127), 127)
      }
      end
    }
    "L" => i
    "D"
    | "EN"
    | "ENOF"
    | "EP"
    | "EPOF"
    | "MP"
    | "MPOF"
    | "MH"
    | "MHOF"
    | "NB"
    | "SA"
    | "SD"
    | "OP" => mml_skip_args(s, i)
    _ => self.unknown(name, s, i)
  }
}

///|
fn mml_slice(s : Bytes, start : Int32, end : Int32) -> Bytes {
  Bytes::from_array([ for i in start..<end => s[i] ])
}

///|
fn MmlVoice::repeat(
  self : MmlVoice,
  body : Bytes,
  count : Int32,
  at : Int32,
  depth : Int32,
) -> Unit {
  let count = Int32::min(Int32::max(count, 1), 10000)
  for pass in 0..<count {
    if self.player.stopped || self.done {
      break
    }
    self.run(
      if pass == count - 1 && at >= 0 {
        mml_slice(body, 0, at)
      } else {
        body
      },
      depth + 1,
    )
  }
}

///|
fn MmlVoice::tuplet(
  self : MmlVoice,
  body : Bytes,
  s : Bytes,
  pos : Int32,
  depth : Int32,
) -> Int32 {
  let start = self.tick
  let n0 = self.track.notes.length()
  let c0 = self.track.controls.length()
  let t0 = self.player.tempos.length()
  self.run(body, depth + 1)
  let (total, end) = self.length(s, pos)
  let inner = self.tick - start
  if self.player.stopped || self.done {
    return end
  }
  if inner <= 0 {
    self.advance(total)
    return end
  }
  let scale = fn(t : Int32) -> Int32 {
    start +
    ((t - start).to_int64() * total.to_int64() / inner.to_int64()).to_int()
  }
  let notes = self.track.notes
  if n0 > 0 {
    let n = notes[n0 - 1]
    if n.tick + n.duration > start {
      n.duration = scale(n.tick + n.duration) - n.tick
    }
  }
  let kept : Array[MmlNote] = []
  for k in n0..<notes.length() {
    let n = notes[k]
    let finish = scale(n.tick + n.duration)
    let tick = scale(n.tick)
    let dur = finish - tick
    if dur > 0 {
      kept.push({
        tick,
        duration: dur,
        key: n.key,
        velocity: n.velocity,
        spelling: n.spelling,
      })
    } else if k == self.last {
      self.last = -1
    }
  }
  while notes.length() > n0 {
    ignore(notes.pop())
  }
  for n in kept {
    notes.push(n)
  }
  if self.last >= n0 {
    self.last = notes.length() - 1
  }
  for k in c0..<self.track.controls.length() {
    let c = self.track.controls[k]
    c.tick = scale(c.tick)
  }
  for k in t0..<self.player.tempos.length() {
    let t = self.player.tempos[k]
    t.tick = scale(t.tick)
  }
  self.tick = start
  self.advance(total)
  end
}

///|
fn mml_quote_rune(rune : String) -> String {
  let out = StringBuilder()
  out.write_char('\'')
  for c in rune {
    let n = c.to_int()
    if c.is_printable() {
      out.write_char(c)
    } else {
      let hex = "0123456789abcdef"
      let digits = if n < 256 {
        out.write_string("\\x")
        2
      } else if n < 65536 {
        out.write_string("\\u")
        4
      } else {
        out.write_string("\\U")
        8
      }
      let mut shift = (digits - 1) * 4
      while shift >= 0 {
        out.write_char(hex[(n >> shift) & 15].to_int().unsafe_to_char())
        shift -= 4
      }
    }
  }
  out.write_char('\'')
  out.to_string()
}

///|
fn MmlVoice::run(self : MmlVoice, s : Bytes, depth : Int32) -> Unit {
  let p = self.player
  if depth > 64 {
    p.warn("depth", "loops and tuplets nested more than 64 deep are left out")
    return
  }
  let mut i = 0
  while true {
    if p.stopped || self.done {
      return
    }
    p.steps += 1
    if p.steps > 20000000 {
      p.warn("steps", "the MML plays too long; the rest is left out")
      p.stopped = true
      return
    }
    if i >= s.length() {
      return
    }
    let mut c = s[i]
    if c.to_int() >= 128 {
      let start = i
      i += 1
      while i < s.length() && (s[i].to_int() & 192) == 128 {
        i += 1
      }
      let rune = @utf8.decode_lossy(s[start:i])
      if mml_trim(rune) != "" {
        p.warn(
          "text",
          "text that is not MML (" + mml_quote_rune(rune) + ") is skipped",
        )
      }
      continue
    }
    i += 1
    if c >= b'A' && c <= b'Z' {
      if !self.fold {
        i = self.upper(s, i - 1)
        continue
      }
      c = (c.to_int() + 32).to_byte()
    }
    match c {
      b' '
      | b'\t'
      | b'\n'
      | b'\x0b'
      | b'\x0c'
      | b','
      | b'|'
      | b']'
      | b'}'
      | b'.'
      | b'+'
      | b'-'
      | b'#'
      | b'$' => ()
      b'c' | b'd' | b'e' | b'f' | b'g' | b'a' | b'b' => {
        let mut acc = 0
        while i < s.length() {
          if s[i] == b'+' || s[i] == b'#' {
            acc += 1
          } else if s[i] == b'-' {
            acc -= 1
          } else {
            break
          }
          i += 1
        }
        let key = (self.oct + 1) * 12 +
          [9, 11, 0, 2, 4, 5, 7][c.to_int() - 97] +
          acc +
          self.shift
        let (d, end) = self.length(s, i)
        i = end
        self.note(key, d, if acc > 0 { 1 } else if acc < 0 { -1 } else { 0 })
      }
      b'r' | b'w' =>
        if c == b'w' && p.dialect != "ppmck" {
          i = self.unknown("w", s, i)
        } else {
          let (d, end) = self.length(s, i)
          i = end
          self.rest(d)
        }
      b'n' =>
        if p.dialect == "generic" &&
          i < s.length() &&
          (s[i].to_int() | 32) == 115 {
          let (n, ok, end) = mml_signed(s, i + 1)
          i = end
          if ok {
            self.shift = Int32::min(Int32::max(self.shift + n, -127), 127)
          }
        } else {
          let (n, ok, end) = mml_number(s, i)
          i = end
          if !ok {
            i = self.unknown("n", s, i)
          } else {
            let mut d = self.len
            if i + 1 < s.length() &&
              s[i] == b',' &&
              (mml_scan_digit(s[i + 1]) || s[i + 1] == b'%') {
              let (duration, end) = self.length(s, i + 1)
              d = duration
              i = end
            } else {
              let (duration, end) = mml_dots(s, i, d)
              d = duration
              i = end
            }
            self.moved = false
            self.note(n + 12 + self.shift, d, 0)
          }
        }
      b'o' => {
        let (n, ok, end) = mml_signed(s, i)
        i = end
        if ok {
          self.oct = Int32::min(Int32::max(n, -2), 10)
          self.moved = false
        }
      }
      b'<' | b'>' => {
        let delta = if c == b'<' { -p.up } else { p.up }
        self.oct = Int32::min(Int32::max(self.oct + delta, -3), 12)
        self.moved = true
      }
      b'l' => {
        let (d, ok, end) = mml_length_arg(s, i, self.pct)
        i = end
        if ok {
          self.len = d
        }
      }
      b't' => {
        let (n, ok, end) = mml_decimal(s, i)
        i = end
        if ok && n >= 1.0 {
          p.tempos.push({ tick: self.tick, bpm: Double::min(n, 999.0), })
        }
      }
      b'v' =>
        if i < s.length() && (s[i] == b'+' || s[i] == b'-') {
          let sign = if s[i] == b'-' { -1 } else { 1 }
          let (n, ok, end) = mml_number(s, i + 1)
          i = end
          self.set_vol(self.vol + sign * (if ok { n } else { 1 }))
        } else {
          let (n, ok, end) = mml_number(s, i)
          i = end
          if ok {
            self.set_vol(n)
          }
        }
      b'(' | b')' =>
        if p.dialect != "generic" {
          i = self.unknown(if c == b'(' { "(" } else { ")" }, s, i)
        } else {
          let (n, ok, end) = mml_number(s, i)
          i = end
          let n = if ok { n } else { 1 }
          self.set_vol(self.vol + (if c == b')' { -n } else { n }))
        }
      b'q' => i = mml_skip_args(s, i)
      b'x' | b's' | b'y' =>
        if (c != b'x' && p.dialect != "ppmck") ||
          (c == b'x' && p.dialect == "mabinogi") {
          i = self.unknown(c.to_int().unsafe_to_char().to_string(), s, i)
        } else {
          i = mml_skip_args(s, i)
        }
      b'@' => i = self.at(s, i)
      b'&' => self.tied = true
      b'^' => {
        let (d, end) = self.length(s, i)
        i = end
        self.extend_note(d)
      }
      b'[' => {
        let end = mml_closing(s, i - 1, b'[', b']')
        p.steps += 2 *
          Int32::max((if end < 0 { s.length() } else { end }) - i, 0)
        if end < 0 {
          p.warn(
            "open-loop", "a loop that does not end ([ without ]) is played once",
          )
        } else {
          let body = mml_slice(s, i, end)
          i = end + 1
          let (n, ok, next) = mml_number(s, i)
          i = next
          self.repeat(
            body,
            if ok {
              n
            } else {
              2
            },
            mml_break_at(body, b'['),
            depth,
          )
        }
      }
      b'/' =>
        if i < s.length() && s[i] == b':' {
          let end = mml_closing_slash(s, i - 1)
          p.steps += 2 *
            Int32::max((if end < 0 { s.length() } else { end }) - i, 0)
          let (n, ok, next) = mml_number(s, i + 1)
          i = next
          if end < 0 || end < i {
            p.warn(
              "open-loop", "a loop that does not end ([ without ]) is played once",
            )
          } else {
            let body = mml_slice(s, i, end)
            i = end + 2
            self.repeat(
              body,
              if ok {
                n
              } else {
                2
              },
              mml_break_at(body, b'/'),
              depth,
            )
          }
        }
      b':' => if i < s.length() && s[i] == b'/' { i += 1 }
      b'{' => {
        let end = mml_closing(s, i - 1, b'{', b'}')
        p.steps += 2 *
          Int32::max((if end < 0 { s.length() } else { end }) - i, 0)
        if end < 0 {
          p.warn(
            "open-tuplet", "a tuplet that does not end ({ without }) is played as it is",
          )
        } else {
          let body = mml_slice(s, i, end)
          i = self.tuplet(body, s, end + 1, depth)
        }
      }
      b'0' | b'1' | b'2' | b'3' | b'4' | b'5' | b'6' | b'7' | b'8' | b'9' => {
        let (_, _, end) = mml_number(s, i)
        i = end
      }
      _ => i = self.unknown(c.to_int().unsafe_to_char().to_string(), s, i)
    }
  }
}

///|
fn mml_play_source(
  source : MmlSource,
  dialect : String,
  up : Int32,
  program : Int32,
) -> MmlPlayer {
  let perf : MmlPerformance = {
    title: source.title,
    composer: source.composer,
    arranger: source.arranger,
    lyricist: source.lyricist,
    copyright: source.copyright,
    tracks: [],
    tempos: [],
    end: 0,
  }
  let player : MmlPlayer = {
    dialect,
    up,
    program,
    source,
    perf,
    tempos: [],
    warnings: [],
    seen: Map([]),
    notes: 0,
    steps: 0,
    stopped: false,
    cost: 0,
  }
  let channels = [0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15]
  for track_source in source.tracks {
    if perf.tracks.length() == 1024 {
      player.warn(
        "tracks", "the MML has more than 1024 tracks; the rest are left out",
      )
      break
    }
    let voice = player.voice(track_source)
    voice.run(@utf8.encode(track_source.text), 0)
    if track_source.kind == 4 {
      if !voice.track.notes.is_empty() {
        player.warn(
          "dpcm",
          "the samples of track " + track_source.name + " (DPCM) are not played",
        )
      }
      continue
    }
    if !voice.track.notes.is_empty() {
      if voice.track.name == "" {
        voice.track.name = "Track " + (perf.tracks.length() + 1).to_string()
      }
      voice.track.channel = channels[perf.tracks.length() % channels.length()]
      perf.tracks.push(voice.track)
      let last = voice.track.notes[voice.track.notes.length() - 1]
      perf.end = Int32::max(
        perf.end,
        Int32::max(voice.tick, last.tick + last.duration),
      )
    }
    if player.stopped {
      break
    }
  }
  let ordered = [ for i, t in player.tempos => (t.tick, i, t.bpm) ]
  ordered.sort_by((a, b) => {
    if a.0 == b.0 {
      a.1.compare(b.1)
    } else {
      a.0.compare(b.0)
    }
  })
  let tempos = perf.tempos
  tempos.push({ tick: 0, bpm: 120.0, })
  for (tick, _, bpm) in ordered {
    let last = tempos[tempos.length() - 1]
    if last.tick == tick {
      last.bpm = bpm
    } else {
      tempos.push({ tick, bpm, })
    }
  }
  let compact : Array[MmlTempo] = []
  for tempo in tempos {
    if compact.is_empty() || compact[compact.length() - 1].bpm != tempo.bpm {
      compact.push(tempo)
    }
  }
  while !tempos.is_empty() {
    ignore(tempos.pop())
  }
  for tempo in compact {
    tempos.push(tempo)
  }
  player
}

///|
/// Result of interpreting MML, including nonfatal warnings.
pub(all) struct MmlParseResult {
  performance : MmlPerformance?
  warnings : Array[String]
  error : String
}

///|
/// Decode and interpret MML. Octave 0 chooses automatically, 1 makes > rise,
/// and 2 makes < rise. Program -1 uses the dialect's default.
pub fn parse_mml(
  data : Bytes,
  dialect~ : String = "",
  octave~ : Int32 = 0,
  program~ : Int32 = -1,
) -> MmlParseResult {
  if program < -1 || program > 127 {
    return {
      performance: None,
      warnings: [],
      error: "mml: program " + program.to_string() + " is not 0–127",
    }
  }
  let text = decode_mml(data)
  let requested = dialect.to_lower()
  let chosen = if requested == "" || requested == "auto" {
    detect_mml_dialect(text)
  } else {
    requested
  }
  if chosen != "generic" && chosen != "mabinogi" && chosen != "ppmck" {
    return {
      performance: None,
      warnings: [],
      error: "mml: unknown dialect \"" + dialect + "\"",
    }
  }
  let source = split_mml_source(text, chosen)
  let up = if octave == 2 ||
    (octave != 1 && chosen == "ppmck" && source.reverse) {
    -1
  } else {
    1
  }
  let mut player = mml_play_source(source, chosen, up, program)
  if chosen == "generic" && octave == 0 && player.cost > 0 && !player.stopped {
    let alternative = mml_play_source(source, chosen, -1, program)
    if alternative.cost < player.cost {
      player = alternative
    }
  }
  let warnings = source.warnings.copy()
  for warning in player.warnings {
    warnings.push(warning)
  }
  if player.perf.tracks.is_empty() {
    { performance: None, warnings, error: "mml: no notes", }
  } else {
    { performance: Some(player.perf), warnings, error: "", }
  }
}
