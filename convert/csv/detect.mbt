///|
fn csv_fabrication(head : Bytes) -> Bool {
  let text = @utf8.decode_lossy(head)
  for line in text.split("\n") {
    let value = csv_trim(line.to_owned())
    if value == "" || value.has_prefix(";") || value == "%" {
      continue
    }
    if value.has_prefix("%") {
      return value.has_suffix("*%") || value.has_suffix("*")
    }
    if value.has_prefix("G04") {
      return value.has_suffix("*")
    }
    return value.has_prefix("M48")
  }
  false
}

///|
fn csv_looks_utf16(data : Bytes) -> Bool {
  let pairs = data.length() / 2
  let mut even = 0
  let mut odd = 0
  for i in 0..<pairs {
    if data[i * 2] == 0 {
      even += 1
    }
    if data[i * 2 + 1] == 0 {
      odd += 1
    }
  }
  let threshold = Int32::max(2, pairs / 50)
  (even >= threshold && odd * 10 <= even) ||
  (odd >= threshold && even * 10 <= odd)
}

///|
/// Detect a CSV or TSV by content, excluding stronger file signatures and
/// plotter and fabrication data as the upstream converter does.
pub fn detect(data : Bytes) -> Bool raise {
  if data.length() == 0 {
    return false
  }
  let head = data[:Int32::min(data.length(), 1024)].to_owned()
  for
    signature in [
      b"%PDF", b"PK\x03\x04", b"{\\rtf", b"<?xml", b"<!DOCTYPE", b"<!doctype", b"<html",
      b"ISO-10303-21",
    ] {
    if head.has_prefix(signature) {
      return false
    }
  }
  if csv_fabrication(head) || @hpgl.detect(head) {
    return false
  }
  let cut = data.length() > 65536
  let sample = data[:Int32::min(data.length(), 65536)].to_owned()
  let bom = sample.has_prefix(b"\xef\xbb\xbf") ||
    sample.has_prefix(b"\xff\xfe") ||
    sample.has_prefix(b"\xfe\xff") ||
    sample.has_prefix(b"\x00\x00\xfe\xff")
  if !bom && !csv_looks_utf16(sample) {
    for byte in sample {
      if byte == 0 {
        return false
      }
    }
  }
  let original = decode_text(sample)
  let mut end = sample.length()
  if cut {
    let mut i = sample.length() - 1
    while i > 0 {
      if sample[i] == b'\n' || sample[i] == b'\r' {
        end = i
        break
      }
      i -= 1
    }
  }
  let trimmed = sample[:end].to_owned()
  let text = decode_text(trimmed, charset=original.charset).text
  let mut bad = 0
  let mut count = 0
  for c in text {
    count += 1
    if (
        c.to_int() < 0x20 && c != '\t' && c != '\n' && c != '\r' && c != '\u{c}'
      ) ||
      c == '\u{7f}' ||
      c == '\u{fffd}' {
      bad += 1
    }
  }
  if bad * 100 > count {
    return false
  }
  let guess = csv_sniff(@utf8.encode(text), cut, 0, 0)
  guess.fields >= 2 && guess.records >= 2 && guess.score >= 0.9
}
