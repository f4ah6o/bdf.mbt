///|
/// Little-endian u16 into a buffer.
fn t_u16(b : @buffer.Buffer, v : Int32) -> Unit {
  b.write_byte((v & 0xff).to_byte())
  b.write_byte(((v >> 8) & 0xff).to_byte())
}

///|
/// Little-endian u32 into a buffer.
fn t_u32(b : @buffer.Buffer, v : Int32) -> Unit {
  b.write_byte((v & 0xff).to_byte())
  b.write_byte(((v >> 8) & 0xff).to_byte())
  b.write_byte(((v >> 16) & 0xff).to_byte())
  b.write_byte(((v >> 24) & 0xff).to_byte())
}

///|
fn t_i32s(values : Array[Int32]) -> Bytes {
  let b = @buffer.Buffer()
  for v in values {
    t_u32(b, v)
  }
  b.to_bytes()
}

///|
fn t_record(kind : Int32, payload : Bytes) -> Bytes {
  let b = @buffer.Buffer()
  t_u32(b, kind)
  t_u32(b, 8 + payload.length())
  b.write_bytes(payload)
  b.to_bytes()
}

///|
/// An EMF header (88 bytes) and the given records.
fn t_emf(
  frame : Array[Int32],
  device : Array[Int32],
  mm : Array[Int32],
  records : Array[Bytes],
) -> Bytes {
  let b = @buffer.Buffer()
  t_u32(b, 1)
  t_u32(b, 88)
  for v in [0, 0, 100, 100] {
    t_u32(b, v)
  }
  for v in frame {
    t_u32(b, v)
  }
  b.write_bytes(b" EMF")
  t_u32(b, 0x10000)
  t_u32(b, 88)
  t_u32(b, 1)
  t_u16(b, 1)
  t_u16(b, 0)
  t_u32(b, 0)
  t_u32(b, 0)
  t_u32(b, 0)
  for v in device {
    t_u32(b, v)
  }
  for v in mm {
    t_u32(b, v)
  }
  for r in records {
    b.write_bytes(r)
  }
  b.to_bytes()
}

///|
fn t_draw(
  emf : Bytes,
  w : Double,
  h : Double,
  annotation : Bool,
) -> (Bytes, Array[String]) {
  let object = @core.ObjectBuilder::new()
  let writer = @core.DocumentWriter::new()
  let warnings = draw_into(object, writer, emf, 0.0, 0.0, w, h, annotation~) catch {
    MetafileInvalid(message) => abort("draw failed: " + message)
  }
  let encoded = object.encode() catch {
    e => abort("encode failed: " + e.to_string())
  }
  (encoded, warnings)
}

///|
fn t_commands(encoded : Bytes) -> Array[@render.Command] {
  @render.decode_commands(encoded) catch {
    e => abort("decode failed: " + e.to_string())
  }
}

///|
fn t_close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 0.01
}

///|
test "emf path records fill and stroke the collected path" {
  let records = [
    t_record(59, b""), // BEGINPATH
    t_record(27, t_i32s([0, 0])), // MOVETOEX
    t_record(54, t_i32s([100, 0])), // LINETO
    t_record(54, t_i32s([100, 100])),
    t_record(61, b""), // CLOSEFIGURE
    t_record(60, b""), // ENDPATH
    t_record(63, b""), // STROKEANDFILLPATH
    t_record(14, t_i32s([0, 0, 0])), // EOF
  ]
  let emf = t_emf([0, 0, 2540, 2540], [96, 96], [25, 25], records)
  let (encoded, warnings) = t_draw(emf, 72.0, 72.0, false)
  let commands = t_commands(encoded)
  let mut fills = 0
  let mut strokes = 0
  for c in commands {
    match c {
      @render.FillPath(_, _) => fills += 1
      @render.StrokePath(_) => strokes += 1
      _ => ()
    }
  }
  guard fills == 1 && strokes == 1 else {
    abort(
      "path records did not fill and stroke: fills=\{fills} strokes=\{strokes}",
    )
  }
  guard warnings.is_empty() else {
    abort("unexpected warnings: \{warnings.join(",")}")
  }
}

///|
test "emf polybezier becomes cubic path verbs" {
  // bounds, count 4, then the start point and one cubic triple
  let payload = t_i32s([0, 0, 100, 100, 4, 0, 0, 100, 0, 0, 100, 100, 100])
  let records = [
    t_record(2, payload), // POLYBEZIER
    t_record(14, t_i32s([0, 0, 0])),
  ]
  let emf = t_emf([0, 0, 2540, 2540], [96, 96], [25, 25], records)
  let (encoded, _) = t_draw(emf, 72.0, 72.0, false)
  let resources = @core.decode_object_resources(encoded) catch {
    e => abort("decode failed: " + e.to_string())
  }
  let commands = t_commands(encoded)
  let mut found = false
  for c in commands {
    match c {
      @render.StrokePath(index) =>
        match resources.paths[index] {
          @core.Inline(path) => {
            let mut cubic = false
            for verb in path.verbs {
              if verb.to_int() == 3 {
                cubic = true
              }
            }
            guard cubic else { abort("the polybezier path has no cubic verb") }
            found = true
          }
          _ => abort("the path is not inline")
        }
      _ => ()
    }
  }
  guard found else { abort("the polybezier was not stroked") }
}

///|
test "text alignment puts the baseline where GDI does" {
  let font = @buffer.Buffer()
  t_u32(font, 1) // ihFont
  t_u32(font, 12) // lfHeight
  t_u32(font, 0) // lfWidth
  t_u32(font, 0) // lfEscapement
  t_u32(font, 0) // lfOrientation
  t_u32(font, 400) // lfWeight
  for _ in 0..<8 {
    font.write_byte(b'\x00')
  }
  for _ in 0..<32 {
    t_u16(font, 0)
  }
  let font_record = t_record(82, font.to_bytes())
  let text = @buffer.Buffer()
  for v in [0, 0, 10, 10] {
    t_u32(text, v) // bounds
  }
  t_u32(text, 1) // iGraphicsMode
  t_u32(text, 0) // exScale
  t_u32(text, 0) // eyScale
  t_u32(text, 0) // ptlReference.x
  t_u32(text, 0) // ptlReference.y
  t_u32(text, 1) // nChars
  t_u32(text, 76) // offString
  t_u32(text, 0) // fOptions
  for v in [0, 0, 10, 10] {
    t_u32(text, v) // rcl
  }
  t_u32(text, 0) // offDx
  t_u16(text, 65) // "A"
  let text_record = t_record(84, text.to_bytes())
  let eof = t_record(14, t_i32s([0, 0, 0]))
  // TA_BASELINE (24): the reference point is the baseline itself
  let baseline = t_emf([0, 0, 2500, 2500], [96, 96], [25, 25], [
    t_record(22, t_i32s([24])),
    font_record,
    t_record(37, t_i32s([1])),
    text_record,
    eof,
  ])
  let (encoded, _) = t_draw(baseline, 72.0, 72.0, false)
  let mut baseline_y = -1.0
  for c in t_commands(encoded) {
    match c {
      @render.FillText(_, _, y, _) => baseline_y = y
      _ => ()
    }
  }
  guard t_close(baseline_y, 0.0) else {
    abort("TA_BASELINE put the text at \{baseline_y}, not 0")
  }
  // TA_TOP (0): the reference point is the top, so the baseline is below it
  let top = t_emf([0, 0, 2500, 2500], [96, 96], [25, 25], [
    t_record(22, t_i32s([0])),
    font_record,
    t_record(37, t_i32s([1])),
    text_record,
    eof,
  ])
  let (encoded2, _) = t_draw(top, 72.0, 72.0, false)
  let mut top_y = -1.0
  for c in t_commands(encoded2) {
    match c {
      @render.FillText(_, _, y, _) => top_y = y
      _ => ()
    }
  }
  guard t_close(top_y, 7.2) else {
    abort("TA_TOP put the baseline at \{top_y}, not 7.2")
  }
}

///|
test "bitfield masks shift down to bit 0" {
  guard mask_channel(0xf800, 0xf800) == 255 else {
    abort("a full red channel did not reach 255")
  }
  guard mask_channel(0x07e0, 0x07e0) == 255 else {
    abort("a full green channel did not reach 255")
  }
  guard mask_channel(0x001f, 0x001f) == 255 else {
    abort("a full blue channel did not reach 255")
  }
  guard mask_channel(0x0000, 0xf800) == 0 else {
    abort("a zero channel did not stay 0")
  }
  guard mask_channel(0x8000, 0xf800) == 131 else {
    abort("half red did not read as 131")
  }
}

///|
test "annotation emfs fit their window to the box" {
  let records = [
    t_record(9, t_i32s([300, 300])), // SETWINDOWEXTEX
    t_record(17, t_i32s([1])), // SETMAPMODE MM_TEXT
    t_record(43, t_i32s([0, 0, 300, 300])), // RECTANGLE
    t_record(14, t_i32s([0, 0, 0])),
  ]
  // the frame says 50 mm, the window says 300 units: the window wins
  let emf = t_emf([0, 0, 5000, 5000], [600, 600], [25, 25], records)
  let (encoded, _) = t_draw(emf, 100.0, 100.0, true)
  let resources = @core.decode_object_resources(encoded) catch {
    e => abort("decode failed: " + e.to_string())
  }
  let mut checked = false
  for c in t_commands(encoded) {
    match c {
      @render.FillPath(index, _) =>
        match resources.paths[index] {
          @core.Inline(path) => {
            guard path.coordinates.length() == 4 else {
              abort(
                "the rectangle path has \{path.coordinates.length()} coordinates",
              )
            }
            guard t_close(path.coordinates[0], 0.0) &&
              t_close(path.coordinates[1], 0.0) &&
              t_close(path.coordinates[2], 100.0) &&
              t_close(path.coordinates[3], 100.0) else {
              abort(
                "the annotation window did not fill the box: \{path.coordinates}",
              )
            }
            checked = true
          }
          _ => abort("the path is not inline")
        }
      _ => ()
    }
  }
  guard checked else { abort("the rectangle was not filled") }
}

///|
test "polybezierto inside a path closes the figure it continues" {
  // BEGINPATH, MOVETOEX (0,0), one cubic from the current point,
  // CLOSEFIGURE, ENDPATH, FILLPATH
  let records = [
    t_record(59, b""), // BEGINPATH
    t_record(27, t_i32s([0, 0])), // MOVETOEX
    t_record(5, t_i32s([0, 0, 100, 100, 3, 100, 0, 100, 100, 0, 100])), // POLYBEZIERTO
    t_record(61, b""), // CLOSEFIGURE
    t_record(60, b""), // ENDPATH
    t_record(62, b""), // FILLPATH
    t_record(14, t_i32s([0, 0, 0])), // EOF
  ]
  let emf = t_emf([0, 0, 2540, 2540], [96, 96], [25, 25], records)
  let (encoded, warnings) = t_draw(emf, 72.0, 72.0, false)
  guard warnings.is_empty() else {
    abort("unexpected warnings: \{warnings.join(",")}")
  }
  let commands = t_commands(encoded)
  let mut index = -1
  for c in commands {
    match c {
      @render.FillPath(i, _) => index = i
      _ => ()
    }
  }
  guard index >= 0 else { abort("the path was not filled") }
  let resources = @core.decode_object_resources(encoded) catch {
    e => abort("decode failed: " + e.to_string())
  }
  let path = match resources.paths[index] {
    @core.Inline(value) => value
    _ => abort("the fill did not use an inline path")
  }
  let mut moves = 0
  let mut closes = 0
  for verb in path.verbs {
    if verb.to_int() == 0 {
      moves += 1
    } else if verb.to_int() == 4 {
      closes += 1
    }
  }
  guard moves == 1 else {
    abort("POLYBEZIERTO started \{moves} subpaths inside the path, not 1")
  }
  guard closes == 1 else { abort("the figure was not closed") }
}

///|
test "widenpath is reported as unsupported" {
  let records = [
    t_record(59, b""), // BEGINPATH
    t_record(27, t_i32s([0, 0])), // MOVETOEX
    t_record(54, t_i32s([100, 0])), // LINETO
    t_record(60, b""), // ENDPATH
    t_record(66, b""), // WIDENPATH
    t_record(64, b""), // STROKEPATH
    t_record(14, t_i32s([0, 0, 0])), // EOF
  ]
  let emf = t_emf([0, 0, 2540, 2540], [96, 96], [25, 25], records)
  let (_, warnings) = t_draw(emf, 72.0, 72.0, false)
  let mut widened = false
  for w in warnings {
    if w.contains("WIDENPATH") {
      widened = true
    }
  }
  guard widened else {
    abort("WIDENPATH was dropped without a warning: \{warnings.join(",")}")
  }
}
