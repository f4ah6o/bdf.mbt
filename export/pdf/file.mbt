///|
/// A small PDF object writer: reserve object numbers, fill them, and write the
/// xref table. Streams are uncompressed unless the caller wraps them.
struct PdfWriter {
  objects : Array[Bytes?]
}

///|
fn PdfWriter::new() -> PdfWriter {
  { objects: [], }
}

///|
fn PdfWriter::reserve(self : PdfWriter) -> Int32 {
  self.objects.push(None)
  self.objects.length()
}

///|
fn PdfWriter::set(self : PdfWriter, id : Int32, body : Bytes) -> Unit {
  if id >= 1 && id <= self.objects.length() {
    self.objects[id - 1] = Some(body)
  }
}

///|
fn PdfWriter::set_string(self : PdfWriter, id : Int32, body : String) -> Unit {
  self.set(id, @utf8.encode(body))
}

///|
fn PdfWriter::add(self : PdfWriter, body : Bytes) -> Int32 {
  let id = self.reserve()
  self.set(id, body)
  id
}

///|
fn PdfWriter::add_string(self : PdfWriter, body : String) -> Int32 {
  self.add(@utf8.encode(body))
}

///|
fn PdfWriter::add_stream(
  self : PdfWriter,
  extra : String,
  data : Bytes,
) -> Int32 {
  let out = @buffer.Buffer()
  out.write_bytes(@utf8.encode("<< /Length " + data.length().to_string()))
  if extra != "" {
    out.write_bytes(@utf8.encode(" " + extra))
  }
  out.write_bytes(@utf8.encode(" >>\nstream\n"))
  out.write_bytesview(data[:])
  out.write_bytes(@utf8.encode("\nendstream"))
  self.add(out.to_bytes())
}

///|
fn pad10(value : Int32) -> String {
  let text = value.to_string()
  let out = StringBuilder()
  for _ in 0..<(10 - text.length()) {
    out.write_string("0")
  }
  out.write_string(text)
  out.to_string()
}

///|
fn PdfWriter::write(self : PdfWriter, root : Int32, info : Int32?) -> Bytes {
  let out = @buffer.Buffer()
  out.write_bytes(@utf8.encode("%PDF-1.7\n%\u{e2}\u{e3}\u{cf}\u{d3}\n"))
  let offsets : Array[Int32] = []
  for index, body in self.objects {
    offsets.push(out.length())
    out.write_bytes(@utf8.encode((index + 1).to_string() + " 0 obj\n"))
    match body {
      Some(bytes) => out.write_bytesview(bytes[:])
      None => out.write_bytes(@utf8.encode("null"))
    }
    out.write_bytes(@utf8.encode("\nendobj\n"))
  }
  let xref = out.length()
  out.write_bytes(
    @utf8.encode("xref\n0 " + (self.objects.length() + 1).to_string() + "\n"),
  )
  out.write_bytes(@utf8.encode("0000000000 65535 f \n"))
  for offset in offsets {
    out.write_bytes(@utf8.encode(pad10(offset) + " 00000 n \n"))
  }
  let mut trailer = "<< /Size " +
    (self.objects.length() + 1).to_string() +
    " /Root " +
    root.to_string() +
    " 0 R"
  match info {
    Some(id) => trailer = trailer + " /Info " + id.to_string() + " 0 R"
    None => ()
  }
  trailer = trailer + " >>"
  out.write_bytes(
    @utf8.encode(
      "trailer\n" + trailer + "\nstartxref\n" + xref.to_string() + "\n%%EOF\n",
    ),
  )
  out.to_bytes()
}
