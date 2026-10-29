///|
struct PngTextBudget {
  mut remaining : Int32
}

///|
fn png_inflate(data : BytesView, budget : PngTextBudget) -> Bytes? {
  if budget.remaining <= 0 {
    return None
  }
  let decoder = @zlib.Decoder(until=EndOfMember)
  let out = @buffer.Buffer()
  let mut offset = 0
  while true {
    let size = if budget.remaining < 16384 { budget.remaining } else { 16384 }
    let chunk : FixedArray[Byte] = FixedArray::make(size, 0)
    let status = decoder.step_into(data[offset:], chunk, end=true) catch {
      _ => return None
    }
    let consumed = decoder.last_consumed()
    let produced = decoder.last_produced()
    let take = if produced < budget.remaining {
      produced
    } else {
      budget.remaining
    }
    out.write_bytes(Bytes::from_array(chunk[:take]))
    budget.remaining -= take
    offset += consumed
    if budget.remaining == 0 || status is Done {
      return Some(out.to_bytes())
    }
    if consumed == 0 && produced == 0 {
      return None
    }
  }
  None
}

///|
fn png_zero(data : BytesView, start : Int32) -> Int32? {
  for i in start..<data.length() {
    if data[i] == 0 {
      return Some(i)
    }
  }
  None
}

///|
fn png_text(
  kind : String,
  data : BytesView,
  budget : PngTextBudget,
) -> (String, String)? {
  guard png_zero(data, 0) is Some(zero) && zero > 0 else { return None }
  // Every keyword we recognize is shorter than this; avoid copying an
  // attacker-controlled, unbounded keyword into a string.
  if zero > 32 {
    return None
  }
  let key = metadata_latin1(data[:zero])
  match key {
    "XML:com.adobe.xmp"
    | "Raw profile type exif"
    | "Raw profile type APP1"
    | "Raw profile type xmp"
    | "Title"
    | "Author"
    | "Description"
    | "Comment"
    | "Copyright"
    | "Creation Time" => ()
    _ => return None
  }
  let mut start = zero + 1
  if kind == "tEXt" {
    return Some((key, metadata_latin1(data[start:])))
  }
  if kind == "zTXt" {
    if start >= data.length() || data[start] != 0 {
      return None
    }
    guard png_inflate(data[start + 1:], budget) is Some(value) else {
      return None
    }
    return Some((key, metadata_latin1(value)))
  }
  if data.length() - start < 2 {
    return None
  }
  let compressed = data[start] == 1
  start += 2
  for _ in 0..<2 {
    guard png_zero(data, start) is Some(end) else { return None }
    start = end + 1
  }
  let raw = if compressed {
    guard png_inflate(data[start:], budget) is Some(value) else { return None }
    value
  } else {
    data[start:].to_bytes()
  }
  Some((key, metadata_valid_utf8(raw)))
}
