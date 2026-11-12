///|
/// The synthetic EMF of evidence/sentinel/synthetic-emf.json and its LZH
/// form: 132 expanded bytes carried as 175 stored ones. The bytes are
/// fully made up, so the regression needs no corpus file on disk.
let xdw_implicit_emf : String = "AQAAAFgAAAAAAAAAAAAAAGQAAABkAAAAAAAAAAAAAADsCQAA7AkAACBFTUYAAAEAhAAAAAMAAAABAAAAAAAAAAAAAAAAAAAAYAAAAGAAAAAZAAAAGQAAACsAAAAYAAAACgAAAAoAAABaAAAAWgAAAA4AAAAUAAAAAAAAAAAAAAAAAAAA"

///|
let xdw_implicit_emf_lzh : String = "AIRYBAAAAf9//////////////////////////////////////////51AACAAAAsAAAAAAAAAAAAAAAyAAAAMgAAAAAAAAAAAAAAdgSAAHYEgAAQIqajAAAAgEIAAAABgAAAAIAAAAAAAAAAAAAAAAAAADAAAAAwAAAADIAAAAyAAAAVgAAADAAAAAUAAAAFAAAALQAAAC0AAAAHAAAACgAAAAAAAAAAAAAAAAAAAAA=="

///|
/// A text record whose attribute 7 keeps the drawing inline the way the
/// viewer writes a compressed sticky note: kind 4 as 0x80, the expanded
/// size as 0x81, the stored size as 0x89, the payload as 0x86, and no
/// 0x8a flag at all. The sizes belong to the synthetic fixture: 132
/// expanded from 175 stored.
fn x_implicit_kind4(data : Bytes) -> PropRecord {
  let b = @buffer.Buffer()
  b.write_bytes(
    x_tlv(0x80, Bytes::from_array(FixedArray::from_array([b'\x04']))),
  )
  b.write_bytes(x_tlv(0x81, b"\x00\x84"[:].to_owned()))
  b.write_bytes(x_tlv(0x89, b"\x00\xaf"[:].to_owned()))
  b.write_bytes(x_tlv(0x86, data))
  {
    depth: 4,
    kind: x_kind_bytes(K_TEXT),
    attrs: [{ class: 0x80, tag: 7, value: b.to_bytes() }],
  }
}

///|
test "a kind 4 drawing expands implicit LZH without a compress flag" {
  let raw = @base64.decode(xdw_implicit_emf)
  let stored = @base64.decode(xdw_implicit_emf_lzh)
  guard raw.length() == 132 else { abort("the fixture EMF is not 132 bytes") }
  guard stored.length() == 175 else {
    abort("the fixture LZH is not 175 bytes")
  }
  let doc = x_doc([x_implicit_kind4(stored)], [])
  let drawing = doc.drawing_of(0) catch {
    e => abort("drawing_of failed: " + e.to_string())
  }
  let pic = match drawing {
    Some(pic) => pic
    None => abort("record 0 has no drawing")
  }
  guard pic.kind == 4L else { abort("the drawing did not read as kind 4") }
  guard pic.data == raw else {
    abort("the drawing kept \\{pic.data.length()} stored bytes, not the raw EMF")
  }
  // and it renders like a drawing should: the EMF holds a rectangle
  let (encoded, warnings) = x_draw(doc, x_object(0L))
  guard warnings.is_empty() else {
    abort("unexpected warnings: \\{warnings.join(\",\")}")
  }
  let commands = @render.decode_commands(encoded) catch {
    e => abort("decode failed: " + e.to_string())
  }
  let mut shapes = 0
  for c in commands {
    match c {
      @render.FillPath(_, _) => shapes += 1
      @render.StrokePath(_) => shapes += 1
      _ => ()
    }
  }
  guard shapes > 0 else { abort("the drawing drew no shapes") }
}

///|
test "a corrupted kind 4 LZH fails instead of falling back to raw" {
  let stored = @base64.decode(xdw_implicit_emf_lzh)
  // zero the low byte of the 16-bit block size: an empty block, while the
  // record still says compressed without the 0x8a flag
  let corrupt = @buffer.Buffer()
  corrupt.write_bytes(stored[0 : 1])
  corrupt.write_bytes(b"\x00"[:])
  corrupt.write_bytes(stored[2 : stored.length()])
  let doc = x_doc([x_implicit_kind4(corrupt.to_bytes())], [])
  let mut failed = false
  try {
    match doc.drawing_of(0) {
      Some(_) => ()
      None => abort("record 0 has no drawing")
    }
  } catch {
    _ => failed = true
  }
  guard failed else {
    abort("the corrupted stream decoded or fell back to the raw bytes")
  }
}

///|
test "invalid compressed declarations cannot be rendered as raw EMF" {
  let raw = @base64.decode(xdw_implicit_emf)
  for size in [b"\x00", b"\xff", b"\x00\x80\x00\x00\x00"] {
    let b = @buffer.Buffer()
    b.write_bytes(x_tlv(0x80, b"\x04"))
    b.write_bytes(x_tlv(0x81, size))
    b.write_bytes(x_tlv(0x8a, b"\x01"))
    b.write_bytes(x_tlv(0x86, raw))
    let rec : PropRecord = {
      depth: 4,
      kind: x_kind_bytes(K_TEXT),
      attrs: [{ class: 0x80, tag: 7, value: b.to_bytes() }],
    }
    let doc = x_doc([rec], [])
    let rejected = try {
      ignore(doc.drawing_of(0))
      false
    } catch {
      XdwCorrupt(_) | XdwTooLarge(_) => true
      _ => false
    }
    assert_true(rejected)
  }
}
