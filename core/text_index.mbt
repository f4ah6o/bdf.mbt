///|
/// A run in a BTXT text index. `a` and `b` identify a page and layer,
/// or a sheet tile; `ordinal` identifies the run in its object.
pub(all) struct IndexRun {
  a : Int32
  b : Int32
  ordinal : Int32
  separator : Int32
  text : String
} derive(Eq, Debug)

///|
/// Decode a BTXT part. A run needs at least five bytes; check the count
/// before allocating so malformed input cannot force an unbounded allocation.
pub fn decode_text_index(data : Bytes) -> Array[IndexRun] raise {
  let r = Reader::new(data)
  if r.take(4) != b"BTXT" {
    raise BadFormat("not a text index part")
  }
  if r.u16() > 1 {
    raise BadFormat("unsupported text index version")
  }
  let count = r.varuint()
  if count > r.remaining() / 5 {
    raise BadFormat("bad text index run count")
  }
  let runs : Array[IndexRun] = []
  for _ in 0..<count {
    runs.push({
      a: r.varuint(),
      b: r.varuint(),
      ordinal: r.varuint(),
      separator: r.u8(),
      text: r.string(),
    })
  }
  runs
}

///|
/// Encode the text index runs of a BDF view.
pub fn encode_text_index(runs : Array[IndexRun]) -> Bytes raise {
  let out = @buffer.Buffer()
  out.write_bytes(b"BTXT\x01\x00")
  out.write_leb128(runs.length().reinterpret_as_uint())
  for run in runs {
    if run.a < 0 ||
      run.b < 0 ||
      run.ordinal < 0 ||
      run.separator < 0 ||
      run.separator > 255 {
      raise BadFormat("invalid text index run")
    }
    out.write_leb128(run.a.reinterpret_as_uint())
    out.write_leb128(run.b.reinterpret_as_uint())
    out.write_leb128(run.ordinal.reinterpret_as_uint())
    out.write_byte(run.separator.to_byte())
    object_write_string(out, run.text)
  }
  out.to_bytes()
}

///|
/// Join index runs in reading order, preserving their spaces and breaks.
pub fn index_plain_text(runs : Array[IndexRun]) -> String {
  let text = StringBuilder()
  for i, run in runs {
    if i > 0 {
      if run.separator == 1 {
        text.write_string(" ")
      } else if run.separator == 2 {
        text.write_string("\n")
      }
    }
    text.write_string(run.text)
  }
  text.to_string()
}
