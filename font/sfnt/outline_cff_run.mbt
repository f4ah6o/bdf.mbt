///|
struct CffRun {
  font : CffOutlines
  local : Array[BytesView]
  out : Array[OutlineCommand]
  mut stack : Array[Double]
  mut x : Double
  mut y : Double
  mut sx : Double
  mut sy : Double
  mut open : Bool
  mut stems : Int32
  mut width_seen : Bool
  mut done : Bool
  mut operations : Int32
}

///|
fn CffRun::close(self : CffRun) -> Unit {
  if self.open {
    self.out.push(Close)
    self.open = false
  }
}

///|
fn CffRun::move(self : CffRun, dx : Double, dy : Double) -> Unit {
  self.close()
  self.x += dx
  self.y += dy
  self.sx = self.x
  self.sy = self.y
}

///|
fn CffRun::start(self : CffRun) -> Unit {
  if !self.open {
    self.out.push(Move(self.sx, self.sy))
    self.open = true
  }
}

///|
fn CffRun::line(self : CffRun, dx : Double, dy : Double) -> Unit {
  self.start()
  self.x += dx
  self.y += dy
  self.out.push(Line(self.x, self.y))
}

///|
fn CffRun::curve(
  self : CffRun,
  dx1 : Double,
  dy1 : Double,
  dx2 : Double,
  dy2 : Double,
  dx3 : Double,
  dy3 : Double,
) -> Unit {
  self.start()
  let x1 = self.x + dx1
  let y1 = self.y + dy1
  let x2 = x1 + dx2
  let y2 = y1 + dy2
  let x3 = x2 + dx3
  let y3 = y2 + dy3
  self.out.push(Cubic(x1, y1, x2, y2, x3, y3))
  self.x = x3
  self.y = y3
}

///|
fn CffRun::take_width(self : CffRun, want : Int32, even : Bool) -> Unit {
  if self.width_seen {
    return
  }
  self.width_seen = true
  let n = self.stack.length()
  if (even && n % 2 == 1) || (!even && n > want) {
    self.stack = self.stack[1:].to_array()
  }
}

///|
fn cff_bias(n : Int32) -> Int32 {
  if n < 1240 {
    107
  } else if n < 33900 {
    1131
  } else {
    32768
  }
}

///|
fn CffRun::escape(self : CffRun, op : Int32) -> Unit {
  let s = self.stack
  match op {
    35 =>
      if s.length() >= 12 {
        self.curve(s[0], s[1], s[2], s[3], s[4], s[5])
        self.curve(s[6], s[7], s[8], s[9], s[10], s[11])
      }
    34 =>
      if s.length() >= 7 {
        self.curve(s[0], 0.0, s[1], s[2], s[3], 0.0)
        self.curve(s[4], 0.0, s[5], -s[2], s[6], 0.0)
      }
    36 =>
      if s.length() >= 9 {
        self.curve(s[0], s[1], s[2], s[3], s[4], 0.0)
        self.curve(s[5], 0.0, s[6], s[7], s[8], -(s[1] + s[3] + s[7]))
      }
    37 =>
      if s.length() >= 11 {
        let dx = s[0] + s[2] + s[4] + s[6] + s[8]
        let dy = s[1] + s[3] + s[5] + s[7] + s[9]
        let x6 = if dx.abs() > dy.abs() { s[10] } else { -dx }
        let y6 = if dx.abs() > dy.abs() { -dy } else { s[10] }
        self.curve(s[0], s[1], s[2], s[3], s[4], s[5])
        self.curve(s[6], s[7], s[8], s[9], x6, y6)
      }
    _ => ()
  }
}

///|
fn CffRun::run(self : CffRun, code : BytesView, depth : Int32) -> Unit {
  if depth > 10 {
    self.done = true
    return
  }
  let mut i = 0
  while i < code.length() && !self.done {
    self.operations += 1
    if self.operations > 100000 {
      self.done = true
      return
    }
    let v = code[i].to_int()
    if v == 28 {
      if i + 2 < code.length() {
        self.stack.push(s16(code, i + 1).to_double())
      }
      i += 3
      continue
    } else if v >= 32 && v <= 246 {
      self.stack.push((v - 139).to_double())
      i += 1
      continue
    } else if v >= 247 && v <= 250 {
      if i + 1 < code.length() {
        self.stack.push(
          ((v - 247) * 256 + code[i + 1].to_int() + 108).to_double(),
        )
      }
      i += 2
      continue
    } else if v >= 251 && v <= 254 {
      if i + 1 < code.length() {
        self.stack.push(
          (-(v - 251) * 256 - code[i + 1].to_int() - 108).to_double(),
        )
      }
      i += 2
      continue
    } else if v == 255 {
      if i + 4 < code.length() {
        self.stack.push(
          u32(code, i + 1).reinterpret_as_int().to_double() / 65536.0,
        )
      }
      i += 5
      continue
    }
    i += 1
    match v {
      1 | 3 | 18 | 23 => {
        self.take_width(0, true)
        self.stems += self.stack.length() / 2
      }
      19 | 20 => {
        self.take_width(0, true)
        self.stems += self.stack.length() / 2
        i += (self.stems + 7) / 8
      }
      21 => {
        self.take_width(2, false)
        let s = self.stack
        if s.length() >= 2 {
          self.move(s[s.length() - 2], s[s.length() - 1])
        }
      }
      22 => {
        self.take_width(1, false)
        let s = self.stack
        if s.length() >= 1 {
          self.move(s[s.length() - 1], 0.0)
        }
      }
      4 => {
        self.take_width(1, false)
        let s = self.stack
        if s.length() >= 1 {
          self.move(0.0, s[s.length() - 1])
        }
      }
      5 => {
        let s = self.stack
        for k = 0; k + 1 < s.length(); k = k + 2 {
          self.line(s[k], s[k + 1])
        }
      }
      6 | 7 => {
        let mut horiz = v == 6
        for d in self.stack {
          if horiz {
            self.line(d, 0.0)
          } else {
            self.line(0.0, d)
          }
          horiz = !horiz
        }
      }
      8 => {
        let s = self.stack
        for k = 0; k + 5 < s.length(); k = k + 6 {
          self.curve(s[k], s[k + 1], s[k + 2], s[k + 3], s[k + 4], s[k + 5])
        }
      }
      24 => {
        let s = self.stack
        let mut k = 0
        while k + 5 < s.length() - 2 {
          self.curve(s[k], s[k + 1], s[k + 2], s[k + 3], s[k + 4], s[k + 5])
          k += 6
        }
        if k + 1 < s.length() {
          self.line(s[k], s[k + 1])
        }
      }
      25 => {
        let s = self.stack
        let mut k = 0
        while k + 1 < s.length() - 6 {
          self.line(s[k], s[k + 1])
          k += 2
        }
        if k + 5 < s.length() {
          self.curve(s[k], s[k + 1], s[k + 2], s[k + 3], s[k + 4], s[k + 5])
        }
      }
      26 => {
        let s = self.stack
        let mut k = 0
        let mut dx1 = 0.0
        if s.length() % 4 == 1 {
          dx1 = s[0]
          k = 1
        }
        while k + 3 < s.length() {
          self.curve(dx1, s[k], s[k + 1], s[k + 2], 0.0, s[k + 3])
          dx1 = 0.0
          k += 4
        }
      }
      27 => {
        let s = self.stack
        let mut k = 0
        let mut dy1 = 0.0
        if s.length() % 4 == 1 {
          dy1 = s[0]
          k = 1
        }
        while k + 3 < s.length() {
          self.curve(s[k], dy1, s[k + 1], s[k + 2], s[k + 3], 0.0)
          dy1 = 0.0
          k += 4
        }
      }
      30 | 31 => {
        let s = self.stack
        let mut horiz = v == 31
        for k = 0; k + 3 < s.length(); k = k + 4 {
          let last = if k + 5 == s.length() { s[k + 4] } else { 0.0 }
          if horiz {
            self.curve(s[k], 0.0, s[k + 1], s[k + 2], last, s[k + 3])
          } else {
            self.curve(0.0, s[k], s[k + 1], s[k + 2], s[k + 3], last)
          }
          horiz = !horiz
        }
      }
      10 | 29 => {
        let s = self.stack
        if s.length() == 0 {
          self.done = true
          return
        }
        let subrs = if v == 29 { self.font.global } else { self.local }
        let n = s[s.length() - 1].to_int() + cff_bias(subrs.length())
        ignore(s.pop())
        if n < 0 || n >= subrs.length() {
          self.done = true
          return
        }
        self.run(subrs[n], depth + 1)
        continue
      }
      11 => return
      14 => {
        self.take_width(0, false)
        self.done = true
        return
      }
      12 => {
        if i >= code.length() {
          self.done = true
          return
        }
        let op = code[i].to_int()
        i += 1
        self.escape(op)
      }
      _ => ()
    }
    self.stack.clear()
  }
}

///|
/// Draw a CFF glyph as outline operations in font units. Charstring execution
/// follows upstream's recursion and work limits.
pub fn CffOutlines::outline(
  self : CffOutlines,
  glyph : Int32,
) -> (Bool, Array[OutlineCommand]) {
  let out : Array[OutlineCommand] = []
  if glyph < 0 || glyph >= self.charstrings.length() {
    return (false, out)
  }
  let fd = match self.fd_select {
    Some(select) if select[glyph] < self.local.length() => select[glyph]
    _ => 0
  }
  let state : CffRun = {
    font: self,
    local: self.local[fd],
    out,
    stack: [],
    x: 0.0,
    y: 0.0,
    sx: 0.0,
    sy: 0.0,
    open: false,
    stems: 0,
    width_seen: false,
    done: false,
    operations: 0,
  }
  state.run(self.charstrings[glyph], 0)
  state.close()
  (true, out)
}
