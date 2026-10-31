///|
fn check_pdf_xrefs(
  name : String,
  chunks : Array[String],
  root : PdfObject?,
  entries : Array[(Int64, PdfXRefEntry)],
) -> Unit raise {
  let joined = StringBuilder()
  for chunk in chunks {
    joined.write_string(chunk)
  }
  let encoded = joined.to_string()
  let compressed = @base64.decode(encoded[:])
  let input = @gzip.decompress(compressed[:])
  let file = pdf_open_file(input)
  assert_eq(file.trailer_entry(b"Root"), root, msg=name)
  assert_eq(file.entries.length(), entries.length())
  for (number, entry) in entries {
    assert_eq(
      file.entries.get(number),
      Some(entry),
      msg="\{name} object \{number}",
    )
  }
}
