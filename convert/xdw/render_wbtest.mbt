///|
/// Little-endian u16 into a buffer.
fn x_u16(b : @buffer.Buffer, v : Int32) -> Unit {
  b.write_byte((v & 0xff).to_byte())
  b.write_byte(((v >> 8) & 0xff).to_byte())
}

///|
/// Little-endian u32 into a buffer.
fn x_u32(b : @buffer.Buffer, v : Int32) -> Unit {
  b.write_byte((v & 0xff).to_byte())
  b.write_byte(((v >> 8) & 0xff).to_byte())
  b.write_byte(((v >> 16) & 0xff).to_byte())
  b.write_byte(((v >> 24) & 0xff).to_byte())
}

///|
fn x_i32s(values : Array[Int32]) -> Bytes {
  let b = @buffer.Buffer()
  for v in values {
    x_u32(b, v)
  }
  b.to_bytes()
}

///|
fn x_record(kind : Int32, payload : Bytes) -> Bytes {
  let b = @buffer.Buffer()
  x_u32(b, kind)
  x_u32(b, 8 + payload.length())
  b.write_bytes(payload)
  b.to_bytes()
}

///|
/// An EMF header (88 bytes) and the given records.
fn x_emf(frame : Array[Int32], records : Array[Bytes]) -> Bytes {
  let b = @buffer.Buffer()
  x_u32(b, 1)
  x_u32(b, 88)
  for v in [0, 0, 100, 100] {
    x_u32(b, v)
  }
  for v in frame {
    x_u32(b, v)
  }
  b.write_bytes(b" EMF")
  x_u32(b, 0x10000)
  x_u32(b, 88)
  x_u32(b, 1)
  x_u16(b, 1)
  x_u16(b, 0)
  x_u32(b, 0)
  x_u32(b, 0)
  x_u32(b, 0)
  for v in [96, 96] {
    x_u32(b, v)
  }
  for v in [25, 25] {
    x_u32(b, v)
  }
  for r in records {
    b.write_bytes(r)
  }
  b.to_bytes()
}

///|
/// A TLV element with a one- or two-byte length.
fn x_tlv(tag : Int32, value : Bytes) -> Bytes {
  let b = @buffer.Buffer()
  b.write_byte(tag.to_byte())
  if value.length() < 0x80 {
    b.write_byte(value.length().to_byte())
  } else if value.length() < 0x100 {
    b.write_byte(0x81)
    b.write_byte(value.length().to_byte())
  } else {
    b.write_byte(0x82)
    b.write_byte((value.length() >> 8).to_byte())
    b.write_byte((value.length() & 0xff).to_byte())
  }
  b.write_bytes(value)
  b.to_bytes()
}

///|
/// An inline drawing attribute value: kind, optional annotation flag, data.
fn x_drawing_value(kind : Int32, data : Bytes, annotation : Bool) -> Bytes {
  let b = @buffer.Buffer()
  b.write_bytes(
    x_tlv(0x80, Bytes::from_array(FixedArray::from_array([kind.to_byte()]))),
  )
  if annotation {
    b.write_bytes(x_tlv(0x8d, Bytes::from_array(FixedArray::from_array([1]))))
  }
  b.write_bytes(x_tlv(0x86, data))
  b.to_bytes()
}

///|
/// A record kind as the minimal big-endian two's-complement bytes: a kind
/// with the high bit set needs a leading zero to stay positive.
fn x_kind_bytes(kind : Int64) -> Bytes {
  let hi = (kind >> 8).to_int()
  let lo = (kind & 0xff).to_int()
  if (hi & 0x80) != 0 {
    Bytes::from_array(FixedArray::from_array([0, hi.to_byte(), lo.to_byte()]))
  } else {
    Bytes::from_array(FixedArray::from_array([hi.to_byte(), lo.to_byte()]))
  }
}

///|
fn x_record_with_drawing(
  kind : Int64,
  drawing_kind : Int32,
  data : Bytes,
  annotation : Bool,
) -> PropRecord {
  {
    depth: 4,
    kind: x_kind_bytes(kind),
    attrs: [
      {
        class: 0x80,
        tag: 7,
        value: x_drawing_value(drawing_kind, data, annotation),
      },
    ],
  }
}

///|
fn x_doc(records : Array[PropRecord], entries : Array[Entry]) -> XdwDocument {
  {
    size: 0,
    b: b"",
    container: {
      size: 0,
      generation: Some(10L),
      header: (0, 0),
      trailer: {
        at: 0,
        tag: 0x68,
        count: 0L,
        offsets: [],
        checks: [],
        unknown82: b"",
        props_expanded: 0L,
        props_stored: 0L,
        check: 0L,
        fields: [],
      },
    },
    records,
    entries,
    pages: [],
    ext_defs: Map([]),
    limits: Limits::default(),
    include_hidden: false,
  }
}

///|
fn x_object(rotation : Int64) -> XdwObject {
  {
    place: 0,
    record: 0,
    kind: K_TEXT,
    x: 100L,
    y: 200L,
    w: 300L,
    h: 400L,
    rotation,
    text: None,
  }
}

///|
fn x_draw(doc : XdwDocument, obj : XdwObject) -> (Bytes, Array[String]) {
  let object = @core.ObjectBuilder::new()
  let writer = @core.DocumentWriter::new()
  let warnings : Array[String] = []
  doc.xdw_draw_object(obj, object, writer, warnings) catch {
    e => abort("draw failed: " + e.to_string())
  }
  let encoded = object.encode() catch {
    e => abort("encode failed: " + e.to_string())
  }
  (encoded, warnings)
}

///|
fn x_close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 0.01
}

///|
test "attribute 61 turns the drawing clockwise inside its box" {
  let emf = x_emf([0, 0, 2540, 2540], [
    x_record(43, x_i32s([0, 0, 2540, 2540])), // RECTANGLE over the frame
    x_record(14, x_i32s([0, 0, 0])),
  ])
  let doc = x_doc([x_record_with_drawing(K_TEXT, 4, emf, false)], [])
  let (encoded, warnings) = x_draw(doc, x_object(90L))
  guard warnings.is_empty() else {
    abort("unexpected warnings: \{warnings.join(",")}")
  }
  let commands = @render.decode_commands(encoded) catch {
    e => abort("decode failed: " + e.to_string())
  }
  let mut transform : (Double, Double, Double, Double, Double, Double)? = None
  for c in commands {
    match c {
      @render.Transform(a, b, c2, d, e, f) =>
        transform = Some((a, b, c2, d, e, f))
      _ => ()
    }
  }
  let (a, b, c, d, e, f) = match transform {
    Some(value) => value
    None => abort("a rotated object emitted no transform")
  }
  // 100,200 at 1/100 mm is 2.8346,5.6693 pt; the box is 8.5039 x 11.3386 pt
  guard x_close(a, 0.0) &&
    x_close(b, 1.0) &&
    x_close(c, -1.0) &&
    x_close(d, 0.0) &&
    x_close(e, 11.3386) &&
    x_close(f, 5.6693) else {
    abort("the quarter turn transform is wrong: \{a},\{b},\{c},\{d},\{e},\{f}")
  }
}

///|
test "a kind 7 body decodes its DIB and compressed bits" {
  // a 2x2 24-bit BITMAPINFOHEADER, then the 16-byte trailer and the bits
  let dib = @buffer.Buffer()
  x_u32(dib, 40) // biSize
  x_u32(dib, 2) // biWidth
  x_u32(dib, 2) // biHeight
  x_u16(dib, 1) // biPlanes
  x_u16(dib, 24) // biBitCount
  x_u32(dib, 0) // biCompression
  x_u32(dib, 16) // biSizeImage
  x_u32(dib, 0)
  x_u32(dib, 0)
  x_u32(dib, 0)
  x_u32(dib, 0)
  x_u32(dib, 1) // trailer: 1
  x_u32(dib, 16) // stored size
  x_u32(dib, 16) // expanded size
  x_u32(dib, 2) // rows
  for _ in 0..<16 {
    dib.write_byte(b'\x00')
  }
  let doc = x_doc(
    [x_record_with_drawing(K_PICTURE, 7, dib.to_bytes(), false)],
    [],
  )
  let (encoded, warnings) = x_draw(doc, x_object(0L))
  guard warnings.is_empty() else {
    abort("unexpected warnings: \{warnings.join(",")}")
  }
  let commands = @render.decode_commands(encoded) catch {
    e => abort("decode failed: " + e.to_string())
  }
  let mut images = 0
  for c in commands {
    match c {
      @render.Image(_, _, _, _, _) => images += 1
      _ => ()
    }
  }
  guard images == 1 else {
    abort("the kind 7 body drew \{images} images, not 1")
  }
}

///|
test "attribute 300 counts pictures little-endian" {
  guard xdw_le_num(b"\x01") == 1L else {
    abort("one picture did not read as 1")
  }
  guard xdw_le_num(b"\x00\x01") == 256L else {
    abort("0x0100 did not read as 256")
  }
  guard xdw_le_num(b"\x02\x00") == 2L else { abort("0x0002 did not read as 2") }
}

///|
test "an entry with 0x8d = 1 is an annotation drawing" {
  let emf = x_emf([0, 0, 2540, 2540], [
    x_record(43, x_i32s([0, 0, 2540, 2540])),
    x_record(14, x_i32s([0, 0, 0])),
  ])
  let entry : Entry = {
    at: 0,
    len: 0,
    check: None,
    body_range: (0, emf.length()),
    body: FieldsBody(
      Some(4L),
      [(0x8d, Some(1L), (0, 0))],
      Some((0, emf.length())),
    ),
  }
  let reference = x_tlv(0x81, b"\x00") + x_tlv(0x82, b"\x00")
  let record : PropRecord = {
    depth: 4,
    kind: b"\x80\x11",
    attrs: [{ class: 0xc0, tag: 7, value: reference, }],
  }
  let doc = x_doc([record], [entry])
  let drawing = doc.drawing_of(0) catch {
    e => abort("drawing_of failed: " + e.to_string())
  }
  let annotation = match drawing {
    Some(pic) => pic.annotation
    None => abort("the drawing was not found")
  }
  guard annotation else { abort("the annotation flag was not read") }
}

///|
test "the fixture shape is drawn through its path records" {
  let b = @base64.decode(xdw_fixtures[0].1)
  let result = xdw_convert(b) catch {
    e => abort("convert failed: " + e.to_string())
  }
  let opened = @core.open_single(result.bdf) catch {
    e => abort("open failed: " + e.to_string())
  }
  let mut fills = 0
  let mut strokes = 0
  for view in opened.manifest.views {
    for page in view.pages {
      for layer in page.layers {
        let object = opened.part(layer.object) catch { _ => continue }
        let commands = @render.decode_commands(object) catch { _ => continue }
        for c in commands {
          match c {
            @render.FillPath(_, _) => fills += 1
            @render.StrokePath(_) => strokes += 1
            _ => ()
          }
        }
      }
    }
  }
  guard fills == 1 && strokes == 1 else {
    abort("the fixture shape is missing: fills=\{fills} strokes=\{strokes}")
  }
}
