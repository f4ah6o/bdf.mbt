///|
// A decoded PDF stream can still contain image-compressed bytes, which its
// caller must pass to the corresponding image decoder.
priv struct PdfStreamFilter {
  name : Bytes
  predictor : Int32
  colors : Int32
  bits : Int32
  columns : Int32
  early_change : Int32
}

///|
fn pdf_image_filter(name : Bytes) -> Bool {
  name == b"DCTDecode" ||
  name == b"JPXDecode" ||
  name == b"JBIG2Decode" ||
  name == b"CCITTFaxDecode"
}

///|
fn pdf_decode_filter(
  data : Bytes,
  filter : PdfStreamFilter,
  max : Int64,
) -> Bytes raise PdfStreamError {
  match filter.name {
    b"RunLengthDecode" => pdf_decode_run_length(data, max)
    b"ASCIIHexDecode" => pdf_decode_ascii_hex(data)
    b"ASCII85Decode" => pdf_decode_ascii85(data)
    b"FlateDecode" =>
      pdf_inflate_up_to(
        data,
        filter.predictor,
        filter.colors,
        filter.bits,
        filter.columns,
        max,
      )
    b"LZWDecode" =>
      pdf_decode_lzw(data, filter.early_change, filter.predictor, max)
    _ => raise InvalidStream("unsupported PDF stream filter")
  }
}

///|
fn pdf_decode_stream(
  source : Bytes,
  filters : Array[PdfStreamFilter],
  limit : Int64,
  cut : Bool,
  intermediate_limit : Int64,
) -> (Bytes, Bytes?) raise PdfStreamError {
  if limit < 0L || intermediate_limit < 0L {
    raise InvalidStream("negative stream limit")
  }
  let mut data = source
  for i in 0..<filters.length() {
    let filter = filters[i]
    if pdf_image_filter(filter.name) {
      return (data, Some(filter.name))
    }
    let mut last = true
    for j in (i + 1)..<filters.length() {
      if !pdf_image_filter(filters[j].name) {
        last = false
      }
    }
    let max = if last { limit } else { intermediate_limit }
    let cut_here = last && cut
    let output = pdf_decode_filter(data, filter, max)
    if output.length().to_int64() > max {
      if !cut_here {
        raise InvalidStream("PDF stream exceeds limit")
      }
      data = output[:max.to_int()].to_owned()
    } else {
      data = output
    }
  }
  (data, None)
}
