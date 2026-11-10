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

///|
/// The first point of the last stroked path, in device units.
fn t_last_stroke_start(encoded : Bytes) -> (Double, Double) {
  let resources = @core.decode_object_resources(encoded) catch {
    e => abort("decode failed: " + e.to_string())
  }
  let mut start = (0.0, 0.0)
  for c in t_commands(encoded) {
    match c {
      @render.StrokePath(index) =>
        match resources.paths[index] {
          @core.Inline(path) =>
            if path.coordinates.length() >= 2 {
              start = (path.coordinates[0], path.coordinates[1])
            }
          _ => ()
        }
      _ => ()
    }
  }
  start
}

///|
test "polybezier leaves the current position alone" {
  // PolyBezier neither uses nor updates the current position, so the LINETO
  // after it must start where MOVETOEX left the pen, not at the last Bezier
  // point. The same records without the Bezier give the expected start.
  let move = t_record(27, t_i32s([10, 10])) // MOVETOEX
  let bezier = t_record(
    2,
    t_i32s([0, 0, 100, 100, 4, 100, 100, 200, 100, 200, 200, 100, 200]),
  ) // POLYBEZIER
  let line = t_record(54, t_i32s([300, 300])) // LINETO
  let eof = t_record(14, t_i32s([0, 0, 0]))
  let plain = t_emf([0, 0, 2540, 2540], [96, 96], [25, 25], [move, line, eof])
  let curved = t_emf(
    [0, 0, 2540, 2540], [96, 96], [25, 25], [move, bezier, line, eof],
  )
  let (plain_encoded, _) = t_draw(plain, 72.0, 72.0, false)
  let (curved_encoded, _) = t_draw(curved, 72.0, 72.0, false)
  let (plain_x, plain_y) = t_last_stroke_start(plain_encoded)
  let (curved_x, curved_y) = t_last_stroke_start(curved_encoded)
  guard t_close(plain_x, curved_x) && t_close(plain_y, curved_y) else {
    abort(
      "the line after POLYBEZIER starts at (\{curved_x}, \{curved_y}) instead of (\{plain_x}, \{plain_y})",
    )
  }
}

///|
test "selectclippath reports the region modes it cannot apply" {
  let frame = [0, 0, 2540, 2540]
  let device = [96, 96]
  let mm = [25, 25]
  let eof = t_record(14, t_i32s([0, 0, 0]))
  let clip = fn(mode : Int32) -> Array[Bytes] {
    [
      t_record(59, b""), // BEGINPATH
      t_record(27, t_i32s([0, 0])), // MOVETOEX
      t_record(54, t_i32s([100, 0])), // LINETO
      t_record(54, t_i32s([100, 100])),
      t_record(60, b""), // ENDPATH
      t_record(67, t_i32s([mode])), // SELECTCLIPPATH
      eof,
    ]
  }
  // RGN_AND is what a cumulative clip already does.
  let (_, and_warnings) = t_draw(
    t_emf(frame, device, mm, clip(1)), 72.0, 72.0, false,
  )
  guard and_warnings.is_empty() else {
    abort("RGN_AND warned: \{and_warnings.join(",")}")
  }
  // RGN_COPY with no path clip yet is the same as intersecting with nothing.
  let (_, copy_warnings) = t_draw(
    t_emf(frame, device, mm, clip(5)), 72.0, 72.0, false,
  )
  guard copy_warnings.is_empty() else {
    abort("a first RGN_COPY warned: \{copy_warnings.join(",")}")
  }
  // RGN_DIFF cannot be expressed by a cumulative clip.
  let (_, diff_warnings) = t_draw(
    t_emf(frame, device, mm, clip(4)), 72.0, 72.0, false,
  )
  guard diff_warnings.length() == 1 && diff_warnings[0].contains("RGN_DIFF") else {
    abort("RGN_DIFF was not reported: \{diff_warnings.join(",")}")
  }
}

///|
/// Count the save/restore/clip commands a replay emitted.
fn t_clip_ops(encoded : Bytes) -> (Int, Int, Int) {
  let mut saves = 0
  let mut restores = 0
  let mut clips = 0
  for command in t_commands(encoded) {
    match command {
      @render.Save => saves += 1
      @render.Restore => restores += 1
      @render.ClipPath(_, _) | @render.ClipRect(_, _, _, _) => clips += 1
      _ => ()
    }
  }
  (saves, restores, clips)
}

///|
/// An EMR_COMMENT carrying a DW record: "DW", the two op bytes, then payload.
fn t_dw(a : Int32, b : Int32, payload : Bytes) -> Bytes {
  let body = @buffer.Buffer()
  body.write_bytes(b"DW")
  body.write_byte(a.to_byte())
  body.write_byte(b.to_byte())
  body.write_bytes(payload)
  let data = body.to_bytes()
  let head = @buffer.Buffer()
  t_u32(head, data.length())
  head.write_bytes(data)
  t_record(70, head.to_bytes())
}

///|
/// A point-encoded DW shape record: count, then i16 x/y pairs.
fn t_dw_points(a : Int32, enc : Int32, points : Array[Int32]) -> Bytes {
  let p = @buffer.Buffer()
  t_u32(p, points.length() / 2)
  for v in points {
    t_u16(p, v)
  }
  t_dw(a, enc, p.to_bytes())
}

///|
test "selectclippath RGN_COPY replaces a rectangle clip" {
  // INTERSECTCLIPRECT narrows the clip, so a following RGN_COPY has to
  // replace that region. The clip base expresses the replacement.
  let records = [
    t_record(30, t_i32s([0, 0, 100, 100])), // INTERSECTCLIPRECT
    t_record(59, b""), // BEGINPATH
    t_record(27, t_i32s([0, 0])), // MOVETOEX
    t_record(54, t_i32s([100, 0])), // LINETO
    t_record(54, t_i32s([100, 100])),
    t_record(60, b""), // ENDPATH
    t_record(67, t_i32s([5])), // SELECTCLIPPATH RGN_COPY
    t_record(14, t_i32s([0, 0, 0])),
  ]
  let (encoded, warnings) = t_draw(
    t_emf([0, 0, 2540, 2540], [96, 96], [25, 25], records), 72.0, 72.0, false,
  )
  guard warnings.is_empty() else {
    abort("RGN_COPY over a rectangle clip warned: \{warnings.join(",")}")
  }
  let (saves, restores, clips) = t_clip_ops(encoded)
  // The page bounds clip, the clip base, and the replacement's fresh base.
  guard saves == 3 && restores == 3 && clips == 3 else {
    abort(
      "RGN_COPY did not replace the clip: saves=\{saves} restores=\{restores} clips=\{clips}",
    )
  }
}

///|
test "selectclippath RGN_COPY replaces a DW rectangle clip" {
  // DW06 narrows the clip through a comment record, so a following RGN_COPY
  // has to replace that region just like an EMF rectangle clip.
  let records = [
    t_dw(48, 54, t_i32s([0, 0, 100, 100])), // DW06 clip rect
    t_record(59, b""), // BEGINPATH
    t_record(27, t_i32s([0, 0])), // MOVETOEX
    t_record(54, t_i32s([100, 0])), // LINETO
    t_record(54, t_i32s([100, 100])),
    t_record(60, b""), // ENDPATH
    t_record(67, t_i32s([5])), // SELECTCLIPPATH RGN_COPY
    t_record(14, t_i32s([0, 0, 0])),
  ]
  let (encoded, warnings) = t_draw(
    t_emf([0, 0, 2540, 2540], [96, 96], [25, 25], records), 72.0, 72.0, false,
  )
  guard warnings.is_empty() else {
    abort("RGN_COPY over a DW rectangle clip warned: \{warnings.join(",")}")
  }
  let (saves, restores, clips) = t_clip_ops(encoded)
  guard saves == 4 && restores == 4 && clips == 3 else {
    abort(
      "RGN_COPY did not replace the DW clip: saves=\{saves} restores=\{restores} clips=\{clips}",
    )
  }
}

///|
test "selectclippath RGN_COPY replaces a DW path clip" {
  // DW03 clips to the accumulated DW path, which is a clip of its own.
  let records = [
    t_dw_points(1, 32, [0, 0, 100, 100]), // DW shape: move then line
    t_dw(48, 51, b""), // DW03 clip to the path
    t_record(59, b""), // BEGINPATH
    t_record(27, t_i32s([0, 0])), // MOVETOEX
    t_record(54, t_i32s([100, 0])), // LINETO
    t_record(54, t_i32s([100, 100])),
    t_record(60, b""), // ENDPATH
    t_record(67, t_i32s([5])), // SELECTCLIPPATH RGN_COPY
    t_record(14, t_i32s([0, 0, 0])),
  ]
  let (encoded, warnings) = t_draw(
    t_emf([0, 0, 2540, 2540], [96, 96], [25, 25], records), 72.0, 72.0, false,
  )
  guard warnings.is_empty() else {
    abort("RGN_COPY over a DW path clip warned: \{warnings.join(",")}")
  }
  let (saves, restores, clips) = t_clip_ops(encoded)
  guard saves == 4 && restores == 4 && clips == 3 else {
    abort(
      "RGN_COPY did not replace the DW path clip: saves=\{saves} restores=\{restores} clips=\{clips}",
    )
  }
}

///|
test "a DW clip alone stays silent" {
  // Tracking a DW clip must not add warnings to metafiles that only use
  // RGN_AND, which a cumulative clip already applies.
  let records = [
    t_dw(48, 54, t_i32s([0, 0, 100, 100])), // DW06 clip rect
    t_record(59, b""), // BEGINPATH
    t_record(27, t_i32s([0, 0])), // MOVETOEX
    t_record(54, t_i32s([100, 0])), // LINETO
    t_record(54, t_i32s([100, 100])),
    t_record(60, b""), // ENDPATH
    t_record(67, t_i32s([1])), // SELECTCLIPPATH RGN_AND
    t_record(14, t_i32s([0, 0, 0])),
  ]
  let (_, warnings) = t_draw(
    t_emf([0, 0, 2540, 2540], [96, 96], [25, 25], records), 72.0, 72.0, false,
  )
  guard warnings.is_empty() else {
    abort("a DW clip warned: \{warnings.join(",")}")
  }
}

///|
test "sequential disjoint DW06 clips replace instead of intersecting" {
  // Two DW06 rectangles that do not overlap. A cumulative clip would leave
  // an empty region and hide the second fill; replacement keeps both.
  let records = [
    t_dw(48, 54, t_i32s([0, 0, 100, 100])), // DW06 first clip
    t_record(43, t_i32s([0, 0, 100, 100])), // RECTANGLE inside it
    t_dw(48, 54, t_i32s([200, 200, 300, 300])), // DW06 disjoint replacement
    t_record(43, t_i32s([200, 200, 300, 300])), // RECTANGLE inside it
    t_record(14, t_i32s([0, 0, 0])),
  ]
  let (encoded, warnings) = t_draw(
    t_emf([0, 0, 2540, 2540], [96, 96], [25, 25], records), 72.0, 72.0, false,
  )
  guard warnings.is_empty() else {
    abort("disjoint DW06 clips warned: \{warnings.join(",")}")
  }
  let (saves, restores, clips) = t_clip_ops(encoded)
  // Page bounds, clip base, one replacement base: three saves. The two
  // restores are the replacement and the closing base.
  guard saves == 4 && restores == 4 && clips == 3 else {
    abort(
      "DW06 did not replace: saves=\{saves} restores=\{restores} clips=\{clips}",
    )
  }
  // The second clip must follow a restore, not nest under the first.
  let commands = t_commands(encoded)
  let mut seen_restore = false
  let mut replaced = false
  for command in commands {
    match command {
      @render.Restore => seen_restore = true
      @render.ClipPath(_, _) => if seen_restore { replaced = true }
      _ => ()
    }
  }
  guard replaced else { abort("the second DW06 clip was not a replacement") }
}

///|
test "sequential disjoint DW03 clips replace instead of intersecting" {
  let records = [
    t_dw_points(1, 32, [0, 0, 100, 100]), // DW shape
    t_dw(48, 51, b""), // DW03 first clip
    t_record(43, t_i32s([0, 0, 100, 100])),
    t_dw_points(1, 32, [200, 200, 300, 300]), // disjoint DW shape
    t_dw(48, 51, b""), // DW03 replacement
    t_record(43, t_i32s([200, 200, 300, 300])),
    t_record(14, t_i32s([0, 0, 0])),
  ]
  let (encoded, warnings) = t_draw(
    t_emf([0, 0, 2540, 2540], [96, 96], [25, 25], records), 72.0, 72.0, false,
  )
  guard warnings.is_empty() else {
    abort("disjoint DW03 clips warned: \{warnings.join(",")}")
  }
  let (saves, restores, clips) = t_clip_ops(encoded)
  guard saves == 4 && restores == 4 && clips == 3 else {
    abort(
      "DW03 did not replace: saves=\{saves} restores=\{restores} clips=\{clips}",
    )
  }
}

///|
test "repeated DW06 replacement keeps one clip base" {
  let records = [
    t_dw(48, 54, t_i32s([0, 0, 100, 100])),
    t_dw(48, 54, t_i32s([200, 200, 300, 300])),
    t_dw(48, 54, t_i32s([400, 400, 500, 500])),
    t_record(14, t_i32s([0, 0, 0])),
  ]
  let (encoded, warnings) = t_draw(
    t_emf([0, 0, 2540, 2540], [96, 96], [25, 25], records), 72.0, 72.0, false,
  )
  guard warnings.is_empty() else {
    abort("repeated DW06 clips warned: \{warnings.join(",")}")
  }
  let (saves, restores, clips) = t_clip_ops(encoded)
  // Each replacement restores and saves, so the depth stays at one base.
  guard saves == 5 && restores == 5 && clips == 4 else {
    abort(
      "repeated DW06 replacement leaked a base: saves=\{saves} restores=\{restores} clips=\{clips}",
    )
  }
}

///|
test "INTERSECTCLIPRECT stays cumulative" {
  // Normal GDI clipping must keep intersecting: no clip base is restored.
  let records = [
    t_record(30, t_i32s([0, 0, 100, 100])), // INTERSECTCLIPRECT
    t_record(30, t_i32s([50, 50, 150, 150])), // INTERSECTCLIPRECT
    t_record(14, t_i32s([0, 0, 0])),
  ]
  let (encoded, warnings) = t_draw(
    t_emf([0, 0, 2540, 2540], [96, 96], [25, 25], records), 72.0, 72.0, false,
  )
  guard warnings.is_empty() else {
    abort("INTERSECTCLIPRECT warned: \{warnings.join(",")}")
  }
  let (saves, restores, clips) = t_clip_ops(encoded)
  guard saves == 2 && restores == 2 && clips == 3 else {
    abort(
      "INTERSECTCLIPRECT stopped intersecting: saves=\{saves} restores=\{restores} clips=\{clips}",
    )
  }
}

///|
test "nested save and restore around a replacing clip stays balanced" {
  // SAVEDC/RESTOREDC do not emit object save/restore yet (a separate gap),
  // so a DW06 replacement must still leave the clip base balanced.
  let records = [
    t_record(33, b""), // SAVEDC
    t_dw(48, 54, t_i32s([0, 0, 100, 100])), // DW06
    t_record(34, t_i32s([-1])), // RESTOREDC
    t_dw(48, 54, t_i32s([200, 200, 300, 300])), // DW06 replacement
    t_record(14, t_i32s([0, 0, 0])),
  ]
  let (encoded, warnings) = t_draw(
    t_emf([0, 0, 2540, 2540], [96, 96], [25, 25], records), 72.0, 72.0, false,
  )
  guard warnings.is_empty() else {
    abort("nested DW06 clips warned: \{warnings.join(",")}")
  }
  let (saves, restores, clips) = t_clip_ops(encoded)
  guard saves == 4 && restores == 4 && clips == 3 else {
    abort(
      "nested DW06 replacement unbalanced: saves=\{saves} restores=\{restores} clips=\{clips}",
    )
  }
}

///|
fn t_ansi_font(charset : Int32, handle? : Int32 = 1) -> Bytes {
  let b = @buffer.Buffer()
  for v in [handle, 12, 0, 0, 0, 400] {
    t_u32(b, v)
  }
  b.write_bytes(b"\x00\x00\x00")
  b.write_byte(charset.to_byte())
  for _ in 0..<68 {
    b.write_byte(0)
  }
  t_record(82, b.to_bytes())
}

///|
fn t_ansi_record(text : Bytes, dx : Array[Int32]) -> Bytes {
  let b = @buffer.Buffer()
  // nChars is a byte count for EXTTEXTOUTA, not a decoded character count.
  for v in [0, 0, 100, 100, 1, 0, 0, 0, 0, text.length(), 76, 0, 0, 0, 100, 100] {
    t_u32(b, v)
  }
  let padded = (text.length() + 3) / 4 * 4
  t_u32(b, if dx.is_empty() { 0 } else { 76 + padded })
  b.write_bytes(text)
  for _ in text.length()..<padded {
    b.write_byte(0)
  }
  for v in dx {
    t_u32(b, v)
  }
  t_record(83, b.to_bytes())
}

///|
test "EMF ANSI charset keeps byte advances and ASCII unchanged" {
  for
    (charset, bytes, expected, dx, width) in [
      (128, b"\x93\xfaA", "日A", [3, 5, 7], 15.0),
      (128, b"\x93\xfaA", "日A", [], 18.0),
      (0, b"ABC", "ABC", [3, 5, 7], 15.0),
    ] {
    let emf = t_emf([0, 0, 2500, 2500], [96, 96], [25, 25], [
      t_ansi_font(charset),
      t_record(37, t_i32s([1])),
      t_ansi_record(bytes, dx),
      t_record(14, t_i32s([0, 0, 0])),
    ])
    let (encoded, warnings) = t_draw(emf, 96.0, 96.0, false)
    assert_true(warnings.is_empty())
    let mut count = 0
    for command in t_commands(encoded) {
      if command is @render.FillText(text, _, _, advance) {
        assert_eq(text, expected)
        assert_true(t_close(advance, width))
        count += 1
      }
    }
    assert_eq(count, 1)
  }
}

///|
fn t_wmf_record(b : @buffer.Buffer, kind : Int32, args : Bytes) -> Unit {
  t_u32(b, 3 + args.length() / 2)
  t_u16(b, kind)
  b.write_bytes(args)
}

///|
test "WMF Shift_JIS text still uses selected font charset" {
  let b = @buffer.Buffer()
  t_u16(b, 1)
  t_u16(b, 9)
  t_u16(b, 0x300)
  for _ in 0..<12 {
    b.write_byte(0)
  }
  let font = @buffer.Buffer()
  for v in [12, 0, 0, 0, 400] {
    t_u16(font, v)
  }
  font.write_bytes(b"\x00\x00\x00\x80\x00\x00\x00\x00Arial\x00")
  t_wmf_record(b, 0x02fb, font.to_bytes())
  t_wmf_record(b, 0x012d, b"\x00\x00")
  t_wmf_record(b, 0x0521, b"\x02\x00\x93\xfa\x00\x00\x00\x00")
  t_wmf_record(b, 0, b"")
  let (encoded, warnings) = t_draw(b.to_bytes(), 100.0, 100.0, false)
  assert_true(warnings.is_empty())
  let texts : Array[String] = []
  for command in t_commands(encoded) {
    if command is @render.FillText(text, _, _, _) {
      texts.push(text)
    }
  }
  assert_eq(texts, ["日"])
}

///|
test "EMF restores font charset through nested DC snapshots" {
  for
    (first, bytes, expected, second, other, other_text) in [
      (128, b"\x93\xfa", "日", 0, b"\xc3\xa9", "é"),
      (0, b"\xc3\xa9", "é", 128, b"\x93\xfa", "日"),
    ] {
    let emf = t_emf([0, 0, 2500, 2500], [96, 96], [25, 25], [
      t_ansi_font(first),
      t_ansi_font(second, handle=2),
      t_record(37, t_i32s([1])),
      t_ansi_record(bytes, []),
      t_record(33, b""), // Save first charset.
      t_record(37, t_i32s([2])),
      t_record(33, b""), // Save second charset independently.
      t_record(37, t_i32s([1])),
      t_record(34, t_i32s([-1])),
      t_ansi_record(other, []),
      t_record(37, t_i32s([2])),
      t_record(34, t_i32s([1])), // Restore absolute first level.
      t_ansi_record(bytes, []),
      t_record(14, t_i32s([0, 0, 0])),
    ])
    let (encoded, warnings) = t_draw(emf, 96.0, 96.0, false)
    assert_true(warnings.is_empty())
    let texts : Array[String] = []
    for command in t_commands(encoded) {
      if command is @render.FillText(text, _, _, _) {
        texts.push(text)
      }
    }
    assert_eq(texts, [expected, other_text, expected])
  }
}

///|
test "EMF stock fonts reset Shift_JIS to the existing ANSI fallback" {
  for stock in [10, 11, 12, 13, 14, 16, 17] {
    let emf = t_emf([0, 0, 2500, 2500], [96, 96], [25, 25], [
      t_ansi_font(128),
      t_record(37, t_i32s([1])),
      t_ansi_record(b"\x93\xfa", []),
      t_record(37, t_i32s([0x80000000 | stock])),
      t_ansi_record(b"\xc3\xa9", []),
      t_record(14, t_i32s([0, 0, 0])),
    ])
    let (encoded, warnings) = t_draw(emf, 96.0, 96.0, false)
    assert_true(warnings.is_empty())
    let texts : Array[String] = []
    for command in t_commands(encoded) {
      if command is @render.FillText(text, _, _, advance) {
        texts.push(text)
        if text == "é" {
          assert_true(t_close(advance, 6.0))
        }
      }
    }
    assert_eq(texts, ["日", "é"])
  }
}

///|
test "GDI snapshots isolate every saved DC field" {
  let state = gdi_state()
  let saved = state.snapshot()
  let expected = gdi_state()
  state.pen_width = 73.0
  state.pen_color = 0x12345678U
  state.pen_style = 73
  state.pen_null = !state.pen_null
  state.pen_cosmetic = !state.pen_cosmetic
  state.brush_color = 0x12345678U
  state.brush_null = !state.brush_null
  state.brush_hatch = 73
  state.font_height = 73.0
  state.font_weight = 73
  state.font_italic = !state.font_italic
  state.font_underline = !state.font_underline
  state.font_strike = !state.font_strike
  state.font_face = "changed"
  state.font_escapement = 73.0
  state.font_charset = 73
  state.text_color = 0x12345678U
  state.bk_color = 0x12345678U
  state.bk_opaque = !state.bk_opaque
  state.text_align = 73
  state.map_mode = 73
  state.rop2 = 73
  state.poly_fill = 73
  state.win_org = (73.0, 97.0)
  state.win_ext = (73.0, 97.0)
  state.vp_org = (73.0, 97.0)
  state.vp_ext = (73.0, 97.0)
  state.world = mat_translate(73.0, 97.0)
  state.cur = (73.0, 97.0)
  assert_eq(saved.pen_width, expected.pen_width)
  assert_eq(saved.pen_color, expected.pen_color)
  assert_eq(saved.pen_style, expected.pen_style)
  assert_eq(saved.pen_null, expected.pen_null)
  assert_eq(saved.pen_cosmetic, expected.pen_cosmetic)
  assert_eq(saved.brush_color, expected.brush_color)
  assert_eq(saved.brush_null, expected.brush_null)
  assert_eq(saved.brush_hatch, expected.brush_hatch)
  assert_eq(saved.font_height, expected.font_height)
  assert_eq(saved.font_weight, expected.font_weight)
  assert_eq(saved.font_italic, expected.font_italic)
  assert_eq(saved.font_underline, expected.font_underline)
  assert_eq(saved.font_strike, expected.font_strike)
  assert_eq(saved.font_face, expected.font_face)
  assert_eq(saved.font_escapement, expected.font_escapement)
  assert_eq(saved.font_charset, expected.font_charset)
  assert_eq(saved.text_color, expected.text_color)
  assert_eq(saved.bk_color, expected.bk_color)
  assert_eq(saved.bk_opaque, expected.bk_opaque)
  assert_eq(saved.text_align, expected.text_align)
  assert_eq(saved.map_mode, expected.map_mode)
  assert_eq(saved.rop2, expected.rop2)
  assert_eq(saved.poly_fill, expected.poly_fill)
  assert_eq(saved.win_org, expected.win_org)
  assert_eq(saved.win_ext, expected.win_ext)
  assert_eq(saved.vp_org, expected.vp_org)
  assert_eq(saved.vp_ext, expected.vp_ext)
  assert_eq(saved.world.a, expected.world.a)
  assert_eq(saved.world.b, expected.world.b)
  assert_eq(saved.world.c, expected.world.c)
  assert_eq(saved.world.d, expected.world.d)
  assert_eq(saved.world.e, expected.world.e)
  assert_eq(saved.world.f, expected.world.f)
  assert_eq(saved.cur, expected.cur)
}

///|
/// The page width a pen emits. The fixture is 960 device units over 25mm, so
/// one device unit is 72 / (25.4 * 960 / 25) = 0.073819 page points.
test "emf pen widths are logical widths mapped to page points" {
  let stroke = fn(width : Int32, extra : Array[Bytes]) -> Double {
    let records : Array[Bytes] = []
    for record in extra {
      records.push(record)
    }
    records.push(t_record(38, t_i32s([1, 0, width, 0, 0]))) // CREATEPEN
    records.push(t_record(37, t_i32s([1]))) // SELECTOBJECT
    records.push(t_record(27, t_i32s([100, 480]))) // MOVETOEX
    records.push(t_record(54, t_i32s([860, 480]))) // LINETO
    records.push(t_record(14, t_i32s([0, 0, 0]))) // EOF
    let emf = t_emf([0, 0, 2540, 2540], [960, 960], [25, 25], records)
    let (encoded, _) = t_draw(emf, 72.0, 72.0, false)
    let mut found = -1.0
    for command in t_commands(encoded) {
      if command is @render.Line(value, _, _, _) {
        found = value
      }
    }
    found
  }
  // A geometric pen is a logical width: 40 units is 2.953 page points.
  assert_true(t_close(stroke(40, []), 2.9528))
  // A legitimately wide pen stays wide.
  assert_true(t_close(stroke(200, []), 14.7638))
  // A cosmetic pen is a fixed 96dpi-inspired hairline, not a logical width.
  assert_true(t_close(stroke(0, []), 0.75))
  // An anisotropic viewport halves y: the geometric mean of the axes.
  let anisotropic = [
    t_record(17, t_i32s([8])), // SETMAPMODE MM_ANISOTROPIC
    t_record(9, t_i32s([2540, 2540])), // SETWINDOWEXTEX
    t_record(11, t_i32s([2540, 1270])), // SETVIEWPORTEXTEX
  ]
  assert_true(t_close(stroke(40, anisotropic), 2.0879))
}

///|
fn t_line_width(encoded : Bytes) -> Double {
  let mut found = -1.0
  for command in t_commands(encoded) {
    if command is @render.Line(value, _, _, _) {
      found = value
    }
  }
  found
}

///|
fn t_dashes(encoded : Bytes) -> Array[Double] {
  let mut found : Array[Double] = []
  for command in t_commands(encoded) {
    if command is @render.Dash(segments, _) {
      found = segments.copy()
    }
  }
  found
}

///|
/// A DW 0x40 polyline: a stroked path on its own, through fill_or_stroke.
fn t_dw_polyline(points : Array[(Int32, Int32)]) -> Bytes {
  let data = @buffer.Buffer()
  data.write_bytes(b"DW")
  data.write_byte(b'\x40')
  data.write_byte(b'\x20')
  t_u32(data, points.length())
  for point in points {
    t_u16(data, point.0)
    t_u16(data, point.1)
  }
  let bytes = data.to_bytes()
  let record = @buffer.Buffer()
  t_u32(record, bytes.length())
  record.write_bytes(bytes)
  t_record(70, record.to_bytes())
}

///|
/// The dash pattern a pen style emits, in page points. The pattern is a
/// multiple of the page width, so a transformed width scales the dashes too.
test "emf pen dashes follow the page width" {
  let stroke = fn(
    width : Int32,
    style : Int32,
    device : Int32,
  ) -> (Double, Array[Double]) {
    let records = [
      t_record(38, t_i32s([1, style, width, 0, 0])), // CREATEPEN
      t_record(37, t_i32s([1])), // SELECTOBJECT
      t_record(27, t_i32s([100, 480])), // MOVETOEX
      t_record(54, t_i32s([860, 480])), // LINETO
      t_record(14, t_i32s([0, 0, 0])), // EOF
    ]
    let emf = t_emf([0, 0, 2540, 2540], [device, device], [25, 25], records)
    let (encoded, _) = t_draw(emf, 72.0, 72.0, false)
    (t_line_width(encoded), t_dashes(encoded))
  }
  let patterns : Array[Array[Double]] = [
    [3.0, 1.0],
    [1.0, 1.0],
    [3.0, 1.0, 1.0, 1.0],
    [3.0, 1.0, 1.0, 1.0, 1.0, 1.0],
  ]
  let styles : Array[Int32] = [1, 2, 3, 4]
  for i, pattern in patterns {
    let style = styles[i]
    let (width, dashes) = stroke(40, style, 960)
    assert_true(t_close(width, 2.9528))
    assert_eq(dashes.length(), pattern.length())
    for j, segment in pattern {
      assert_true(t_close(dashes[j], segment * width * 2.0))
    }
    // Half the device dpi doubles the page width, and the dashes with it.
    let (wide, wide_dashes) = stroke(40, style, 480)
    assert_true(t_close(wide, 5.9055))
    for j, segment in pattern {
      assert_true(t_close(wide_dashes[j], segment * wide * 2.0))
    }
  }
  // PS_SOLID emits an empty pattern.
  let (_, solid) = stroke(40, 0, 960)
  assert_eq(solid.length(), 0)
}

///|
/// The same dash rule on the DocuWorks stroke path (fill_or_stroke).
test "dw pen dashes follow the page width" {
  let stroke = fn(width : Int32, style : Int32) -> (Double, Array[Double]) {
    let records = [
      t_record(38, t_i32s([1, style, width, 0, 0])), // CREATEPEN
      t_record(37, t_i32s([1])), // SELECTOBJECT
      t_dw_polyline([(100, 480), (860, 480)]),
      t_record(14, t_i32s([0, 0, 0])), // EOF
    ]
    let emf = t_emf([0, 0, 2540, 2540], [960, 960], [25, 25], records)
    let (encoded, _) = t_draw(emf, 72.0, 72.0, false)
    (t_line_width(encoded), t_dashes(encoded))
  }
  let patterns : Array[Array[Double]] = [
    [3.0, 1.0],
    [1.0, 1.0],
    [3.0, 1.0, 1.0, 1.0],
    [3.0, 1.0, 1.0, 1.0, 1.0, 1.0],
  ]
  let styles : Array[Int32] = [1, 2, 3, 4]
  for i, pattern in patterns {
    let (width, dashes) = stroke(40, styles[i])
    assert_true(t_close(width, 2.9528))
    assert_eq(dashes.length(), pattern.length())
    for j, segment in pattern {
      assert_true(t_close(dashes[j], segment * width * 2.0))
    }
  }
}

///|
/// EXTCREATEPEN carries PS_COSMETIC (0) or PS_GEOMETRIC (0x10000) in
/// elpPenStyle; the width is a Double there.
test "extcreatepen cosmetic and geometric flags" {
  let stroke = fn(style : Int32, width : Double) -> Double {
    let records = [
      t_record(
        95,
        t_i32s([1, 0, 0, 0, 0, style, width.to_int(), 0, 0, 0, 0]),
      ), // EXTCREATEPEN
      t_record(37, t_i32s([1])), // SELECTOBJECT
      t_record(27, t_i32s([100, 480])), // MOVETOEX
      t_record(54, t_i32s([860, 480])), // LINETO
      t_record(14, t_i32s([0, 0, 0])), // EOF
    ]
    let emf = t_emf([0, 0, 2540, 2540], [960, 960], [25, 25], records)
    let (encoded, _) = t_draw(emf, 72.0, 72.0, false)
    t_line_width(encoded)
  }
  // PS_COSMETIC: a 96dpi-inspired hairline, not the logical width.
  assert_true(t_close(stroke(0, 40.0), 0.75))
  // PS_GEOMETRIC: the logical width through the matrix.
  assert_true(t_close(stroke(0x10000, 40.0), 2.9528))
}

///|
/// A singular world transform has no page scale; the stroke falls back to the
/// hairline instead of emitting a zero or NaN width.
test "a singular pen matrix falls back to the hairline" {
  let records = [
    t_record(38, t_i32s([1, 0, 40, 0, 0])), // CREATEPEN
    t_record(37, t_i32s([1])), // SELECTOBJECT
    t_record(35, t_i32s([0, 0, 0, 0, 0, 0])), // SETWORLDTRANSFORM, det 0
    t_record(27, t_i32s([100, 480])), // MOVETOEX
    t_record(54, t_i32s([860, 480])), // LINETO
    t_record(14, t_i32s([0, 0, 0])), // EOF
  ]
  let emf = t_emf([0, 0, 2540, 2540], [960, 960], [25, 25], records)
  let (encoded, _) = t_draw(emf, 72.0, 72.0, false)
  assert_true(t_close(t_line_width(encoded), 0.75))
}
